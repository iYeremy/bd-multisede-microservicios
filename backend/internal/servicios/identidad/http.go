package identidad

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5/pgxpool"
)

// CookieSesion es el nombre de la cookie donde el navegador guarda el token.
const CookieSesion = "sesion"

// HeaderSesion: el gateway manda aqui el token cuando pregunta por la sesion.
const HeaderSesion = "X-Sesion"

// Rutas cuelga las rutas de identidad.
//
//	publicas:
//	  POST /api/identidad/login       {"usuario": "...", "password": "..."}
//	  POST /api/identidad/logout
//	  GET  /api/identidad/yo          quien soy (lo usa el front)
//	  GET  /api/identidad/auditoria   ultimos accesos (AUDITOR, ADMINISTRADOR)
//	internas:
//	  GET  /interno/sesion            el gateway valida el token (X-Sesion)
//	  POST /interno/auditoria         los demas servicios registran accesos
func Rutas(mux *http.ServeMux, db *pgxpool.Pool, cfg plataforma.Config) {
	s := nuevo(db)
	go s.limpiar(context.Background())
	interno := func(h http.HandlerFunc) http.HandlerFunc { return plataforma.SoloInterno(cfg.TokenInterno, h) }
	todos := []string{plataforma.RolAdmin, plataforma.RolGerencia, plataforma.RolInventario,
		plataforma.RolCompras, plataforma.RolVendedor, plataforma.RolAuditor}

	mux.HandleFunc("POST /api/identidad/login", s.login)
	mux.HandleFunc("POST /api/identidad/logout", s.logout)
	mux.HandleFunc("GET /api/identidad/yo", plataforma.ConRol(s.yo, todos...))
	mux.HandleFunc("GET /api/identidad/auditoria", plataforma.ConRol(s.verAuditoria, plataforma.RolAuditor, plataforma.RolAdmin))

	mux.HandleFunc("GET /interno/sesion", interno(s.verSesion))
	mux.HandleFunc("POST /interno/auditoria", interno(s.auditar))
}

func (s *Servicio) login(w http.ResponseWriter, r *http.Request) {
	var datos struct {
		Usuario  string `json:"usuario"`
		Password string `json:"password"`
	}
	// MaxBytesReader: no aceptar cuerpos gigantes
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&datos); err != nil || datos.Usuario == "" {
		plataforma.ResponderError(w, http.StatusBadRequest, "manda {\"usuario\": \"...\", \"password\": \"...\"}")
		return
	}
	token, u, err := s.Login(r.Context(), datos.Usuario, datos.Password)
	if errors.Is(err, ErrBloqueado) {
		// 429 Too Many Requests; Retry-After: en cuantos segundos reintentar
		falta, _ := s.intentos.bloqueado(datos.Usuario)
		w.Header().Set("Retry-After", strconv.Itoa(int(falta.Seconds())+1))
		plataforma.ResponderError(w, http.StatusTooManyRequests, err.Error())
		return
	}
	if errors.Is(err, ErrCredenciales) {
		plataforma.ResponderError(w, http.StatusUnauthorized, err.Error())
		return
	}
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	// HttpOnly: el javascript de la pagina no puede leer la cookie (si alguien
	// mete codigo malicioso en la pagina, no se roba la sesion).
	// SameSite=Lax: otra pagina web no puede mandar peticiones con tu sesion.
	http.SetCookie(w, &http.Cookie{
		Name: CookieSesion, Value: token, Path: "/",
		MaxAge: int(duracionSesion.Seconds()), HttpOnly: true, SameSite: http.SameSiteLaxMode,
		Secure: plataforma.Var("COOKIE_SEGURA", "false") == "true", // true solo con https
	})
	plataforma.ResponderJSON(w, http.StatusOK, u)
}

func (s *Servicio) logout(w http.ResponseWriter, r *http.Request) {
	if c, err := r.Cookie(CookieSesion); err == nil {
		s.Logout(r.Context(), c.Value)
	}
	// MaxAge -1 le dice al navegador que borre la cookie
	http.SetCookie(w, &http.Cookie{Name: CookieSesion, Value: "", Path: "/", MaxAge: -1, HttpOnly: true})
	plataforma.ResponderJSON(w, http.StatusOK, map[string]string{"mensaje": "sesion cerrada"})
}

func (s *Servicio) yo(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	// el nombre no viene en los encabezados; se saca de la sesion completa
	if c, err := r.Cookie(CookieSesion); err == nil {
		if completo, ok := s.Sesion(c.Value); ok {
			u = completo
		}
	}
	plataforma.ResponderJSON(w, http.StatusOK, u)
}

func (s *Servicio) verAuditoria(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	limite := 50
	if l, err := strconv.Atoi(r.URL.Query().Get("limite")); err == nil && l > 0 && l <= 500 {
		limite = l
	}
	accesos, err := s.Auditoria(r.Context(), limite)
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	s.registrar(r.Context(), u.ID, "SELECT", "identidad.auditoria_accesos")
	plataforma.ResponderJSON(w, http.StatusOK, accesos)
}

func (s *Servicio) verSesion(w http.ResponseWriter, r *http.Request) {
	u, ok := s.Sesion(r.Header.Get(HeaderSesion))
	if !ok {
		plataforma.ResponderError(w, http.StatusUnauthorized, "sesion invalida o vencida")
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, u)
}

func (s *Servicio) auditar(w http.ResponseWriter, r *http.Request) {
	var datos struct {
		IDUsuario int    `json:"id_usuario"`
		Accion    string `json:"accion"`
		Objeto    string `json:"objeto"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&datos); err != nil ||
		!accionesValidas[datos.Accion] || datos.Objeto == "" || len(datos.Objeto) > 100 {
		plataforma.ResponderError(w, http.StatusBadRequest, "auditoria invalida")
		return
	}
	if err := s.Registrar(r.Context(), datos.IDUsuario, datos.Accion, datos.Objeto); err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
