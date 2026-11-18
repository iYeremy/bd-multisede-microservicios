package plataforma

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
)

// HeaderRequestID viaja en todas las peticiones para poder seguir una
// misma operacion en los logs de varios servicios.
const HeaderRequestID = "X-Request-Id"

// ResponderJSON escribe v como json con el codigo http dado.
func ResponderJSON(w http.ResponseWriter, codigo int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(codigo)
	json.NewEncoder(w).Encode(v)
}

// ResponderError escribe {"error": mensaje}.
func ResponderError(w http.ResponseWriter, codigo int, mensaje string) {
	ResponderJSON(w, codigo, map[string]string{"error": mensaje})
}

// ErrorDB traduce un error de la base a una respuesta http clara. el
// detalle tecnico solo va al log, nunca al usuario.
func ErrorDB(w http.ResponseWriter, r *http.Request, err error) {
	// la clase del error son los 2 primeros caracteres del SQLSTATE
	var pgErr *pgconn.PgError
	clase := ""
	if errors.As(err, &pgErr) && len(pgErr.Code) == 5 {
		clase = pgErr.Code[:2]
	}
	switch {
	case clase == "42" && pgErr.Code == "42501": // permiso denegado
		ResponderError(w, http.StatusForbidden, "No tienes permiso para esta operacion")
	case clase == "23": // CHECK, UNIQUE, FK
		ResponderError(w, http.StatusBadRequest, "Datos invalidos")
	case clase == "08" || clase == "57" || // la conexion se cayo o el servidor se apago
		errors.Is(err, context.DeadlineExceeded) || errors.As(err, new(*pgconn.ConnectError)):
		ResponderError(w, http.StatusServiceUnavailable, "La base de datos no responde")
	default:
		ResponderError(w, http.StatusInternalServerError, "Error interno")
	}
	slog.Error("error de base de datos", "ruta", r.URL.Path, "request_id", r.Header.Get(HeaderRequestID), "error", err)
}

// nuevoID genera un id corto al azar para HeaderRequestID.
func nuevoID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// grabador guarda el codigo http que se respondio, para el log.
type grabador struct {
	http.ResponseWriter
	codigo int
}

func (g *grabador) WriteHeader(codigo int) {
	g.codigo = codigo
	g.ResponseWriter.WriteHeader(codigo)
}

// ConRegistro envuelve un handler: le pone un X-Request-Id si no trae
// uno y escribe una linea de log por peticion (metodo, ruta, codigo, tiempo).
func ConRegistro(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get(HeaderRequestID) == "" {
			r.Header.Set(HeaderRequestID, nuevoID())
		}
		w.Header().Set(HeaderRequestID, r.Header.Get(HeaderRequestID))
		g := &grabador{ResponseWriter: w, codigo: http.StatusOK}
		inicio := time.Now()
		h.ServeHTTP(g, r)
		slog.Info("peticion", "metodo", r.Method, "ruta", r.URL.Path, "codigo", g.codigo,
			"ms", time.Since(inicio).Milliseconds(), "request_id", r.Header.Get(HeaderRequestID))
	})
}

// Escuchar arranca el servidor http y lo apaga ordenadamente con Ctrl+C
// (o cuando systemd lo detiene): deja terminar las peticiones en curso.
func Escuchar(direccion string, h http.Handler) error {
	srv := &http.Server{
		Addr:              direccion,
		Handler:           ConRegistro(h),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()
	slog.Info("escuchando", "direccion", direccion)

	parar := make(chan os.Signal, 1)
	signal.Notify(parar, os.Interrupt, syscall.SIGTERM)
	select {
	case err := <-errCh:
		return err
	case <-parar:
		slog.Info("apagando")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return srv.Shutdown(ctx)
	}
}
