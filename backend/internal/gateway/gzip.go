package gateway

import (
	"compress/gzip"
	"net/http"
	"strings"
	"sync"
)

// conGzip comprime con gzip las respuestas de texto (html, js, css, json)
// cuando el navegador lo acepta. el json y el js se comprimen 4 a 8 veces:
// con la vm lejos, menos bytes = la pagina carga bastante mas rapido.
// envuelve TODO el gateway, asi que comprime tanto el front como lo que
// responden los servicios a traves del proxy.
func conGzip(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
			h.ServeHTTP(w, r)
			return
		}
		// con gzip no se pueden pedir "pedazos" del archivo (Range)
		r.Header.Del("Range")
		e := &escritorGzip{ResponseWriter: w}
		defer e.cerrar()
		h.ServeHTTP(e, r)
	})
}

// los compresores se reutilizan: crear uno nuevo en cada peticion es caro
var compresores = sync.Pool{New: func() any {
	gz, _ := gzip.NewWriterLevel(nil, gzip.DefaultCompression)
	return gz
}}

// escritorGzip decide si comprimir justo antes de mandar los encabezados,
// cuando ya se sabe el tipo de contenido y el codigo de la respuesta.
type escritorGzip struct {
	http.ResponseWriter
	gz       *gzip.Writer
	decidido bool
}

func (e *escritorGzip) WriteHeader(codigo int) {
	if !e.decidido {
		e.decidir(codigo)
	}
	e.ResponseWriter.WriteHeader(codigo)
}

func (e *escritorGzip) Write(b []byte) (int, error) {
	if !e.decidido {
		if e.Header().Get("Content-Type") == "" {
			e.Header().Set("Content-Type", http.DetectContentType(b))
		}
		e.WriteHeader(http.StatusOK)
	}
	if e.gz != nil {
		return e.gz.Write(b)
	}
	return e.ResponseWriter.Write(b)
}

func (e *escritorGzip) decidir(codigo int) {
	e.decidido = true
	h := e.Header()
	h.Add("Vary", "Accept-Encoding")
	sinCuerpo := codigo == http.StatusNoContent || codigo == http.StatusNotModified || codigo < 200
	if sinCuerpo || h.Get("Content-Encoding") != "" || !comprimible(h.Get("Content-Type")) {
		return
	}
	h.Del("Content-Length") // el largo cambia al comprimir
	h.Set("Content-Encoding", "gzip")
	e.gz = compresores.Get().(*gzip.Writer)
	e.gz.Reset(e.ResponseWriter)
}

func (e *escritorGzip) cerrar() {
	if e.gz != nil {
		e.gz.Close()
		compresores.Put(e.gz)
	}
}

func comprimible(tipo string) bool {
	for _, t := range []string{"text/", "application/json", "application/javascript", "image/svg+xml"} {
		if strings.HasPrefix(tipo, t) {
			return true
		}
	}
	return false
}
