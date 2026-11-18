package plataforma

import (
	"bytes"
	"context"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"
)

// HeaderToken lleva la clave compartida en las llamadas entre servicios.
// las rutas /interno/... solo responden si la clave coincide, y el
// gateway nunca reenvia /interno, asi que desde internet no se llega.
const HeaderToken = "X-Token-Interno"

// SoloInterno protege un handler: sin la clave correcta responde 401.
func SoloInterno(token string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// ConstantTimeCompare tarda lo mismo acierte o no, para no dar pistas
		if subtle.ConstantTimeCompare([]byte(r.Header.Get(HeaderToken)), []byte(token)) != 1 {
			ResponderError(w, http.StatusUnauthorized, "Solo para servicios internos")
			return
		}
		h(w, r)
	}
}

// ClienteInterno hace llamadas http a otros servicios: les pone la clave
// interna, pasa el X-Request-Id y no espera mas de 2 segundos.
type ClienteInterno struct {
	http  *http.Client
	token string
}

// NuevoClienteInterno crea un cliente con timeout de 2 segundos.
func NuevoClienteInterno(token string) *ClienteInterno {
	return &ClienteInterno{http: &http.Client{Timeout: 2 * time.Second}, token: token}
}

// ErrServicioCaido indica que el otro servicio no respondio a tiempo.
type ErrServicioCaido struct{ Servicio string }

func (e ErrServicioCaido) Error() string { return "servicio " + e.Servicio + " no disponible" }

// ErrRespuesta es una respuesta con codigo de error (4xx o 5xx) del otro servicio.
type ErrRespuesta struct {
	Servicio string
	Codigo   int
	Mensaje  string
}

func (e ErrRespuesta) Error() string {
	return fmt.Sprintf("%s respondio %d: %s", e.Servicio, e.Codigo, e.Mensaje)
}

// Opcion cambia algo de la peticion antes de mandarla.
type Opcion func(*http.Request)

// ConEncabezado agrega un encabezado a la llamada.
func ConEncabezado(nombre, valor string) Opcion {
	return func(r *http.Request) { r.Header.Set(nombre, valor) }
}

// Get llama GET a la ruta del servicio y decodifica el json en destino.
// las lecturas se reintentan UNA vez si el servicio no respondio: leer dos
// veces no hace dano. requestID sigue la operacion en los logs (puede ir vacio).
//
//	var p []Producto
//	err := cli.Get(ctx, "catalogo", "/interno/productos?ids=1,2", reqID, &p)
func (c *ClienteInterno) Get(ctx context.Context, servicio, ruta, requestID string, destino any, ops ...Opcion) error {
	err := c.hacer(ctx, http.MethodGet, servicio, ruta, requestID, nil, destino, ops)
	if _, caido := err.(ErrServicioCaido); caido && ctx.Err() == nil {
		slog.Warn("reintentando", "servicio", servicio, "ruta", ruta)
		err = c.hacer(ctx, http.MethodGet, servicio, ruta, requestID, nil, destino, ops)
	}
	return err
}

// Post manda cuerpo como json. las escrituras NO se reintentan: si la
// primera si llego pero la respuesta se perdio, se duplicaria el registro.
func (c *ClienteInterno) Post(ctx context.Context, servicio, ruta, requestID string, cuerpo, destino any, ops ...Opcion) error {
	return c.hacer(ctx, http.MethodPost, servicio, ruta, requestID, cuerpo, destino, ops)
}

func (c *ClienteInterno) hacer(ctx context.Context, metodo, servicio, ruta, requestID string, cuerpo, destino any, ops []Opcion) error {
	var body io.Reader
	if cuerpo != nil {
		b, err := json.Marshal(cuerpo)
		if err != nil {
			return err
		}
		body = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, metodo, URLServicio(servicio)+ruta, body)
	if err != nil {
		return err
	}
	req.Header.Set(HeaderToken, c.token)
	req.Header.Set("Content-Type", "application/json")
	if requestID != "" {
		req.Header.Set(HeaderRequestID, requestID)
	}
	for _, op := range ops {
		op(req)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return ErrServicioCaido{Servicio: servicio}
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		var e struct {
			Error string `json:"error"`
		}
		json.NewDecoder(resp.Body).Decode(&e)
		// un 503 del otro servicio (por ejemplo, sin base) tambien cuenta como caido
		if resp.StatusCode == http.StatusServiceUnavailable {
			return ErrServicioCaido{Servicio: servicio}
		}
		return ErrRespuesta{Servicio: servicio, Codigo: resp.StatusCode, Mensaje: e.Error}
	}
	if destino != nil {
		if err := json.NewDecoder(resp.Body).Decode(destino); err != nil {
			return fmt.Errorf("respuesta invalida de %s: %w", servicio, err)
		}
	}
	return nil
}

// Auditar registra un acceso en identidad (POST /interno/auditoria). corre
// en segundo plano: si identidad no responde, la operacion principal NO se
// revierte, solo queda el aviso en el log.
func (c *ClienteInterno) Auditar(r *http.Request, u Usuario, accion, objeto string) {
	reqID := r.Header.Get(HeaderRequestID)
	go func() {
		// contexto propio: la peticion original ya pudo haber terminado
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		cuerpo := map[string]any{"id_usuario": u.ID, "accion": accion, "objeto": objeto}
		if err := c.Post(ctx, "identidad", "/interno/auditoria", reqID, cuerpo, nil); err != nil {
			slog.Warn("no se pudo registrar la auditoria", "accion", accion, "objeto", objeto, "error", err)
		}
	}()
}
