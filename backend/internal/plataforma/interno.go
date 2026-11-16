package plataforma

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"fmt"
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

// Get llama GET a url y decodifica el json de la respuesta en destino.
// requestID se pasa para seguir la operacion en los logs (puede ir vacio).
func (c *ClienteInterno) Get(ctx context.Context, servicio, url, requestID string, destino any) (int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set(HeaderToken, c.token)
	if requestID != "" {
		req.Header.Set(HeaderRequestID, requestID)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return 0, ErrServicioCaido{Servicio: servicio}
	}
	defer resp.Body.Close()
	if destino != nil && resp.StatusCode < 300 {
		if err := json.NewDecoder(resp.Body).Decode(destino); err != nil {
			return resp.StatusCode, fmt.Errorf("respuesta invalida de %s: %w", servicio, err)
		}
	}
	return resp.StatusCode, nil
}
