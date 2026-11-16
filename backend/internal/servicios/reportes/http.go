package reportes

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Rutas cuelga las rutas de reportes y arranca el refresco automatico.
//
//	GET  /api/reportes                 las vistas que tu rol puede ver
//	GET  /api/reportes/{vista}[?sede=N][&limite=N]
//	POST /api/reportes/refrescar       refrescar ahora (solo ADMINISTRADOR)
func Rutas(mux *http.ServeMux, db *pgxpool.Pool, cfg plataforma.Config) {
	s := &Servicio{db: db}
	cli := plataforma.NuevoClienteInterno(cfg.TokenInterno)
	todos := []string{plataforma.RolAdmin, plataforma.RolGerencia, plataforma.RolAuditor,
		plataforma.RolInventario, plataforma.RolCompras}

	mux.HandleFunc("GET /api/reportes", plataforma.ConRol(s.listar, todos...))
	mux.HandleFunc("GET /api/reportes/{vista}", plataforma.ConRol(func(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
		s.ver(w, r, u, cli)
	}, todos...))
	mux.HandleFunc("POST /api/reportes/refrescar", plataforma.ConRol(s.refrescarAhora, plataforma.RolAdmin))

	// REFRESCO_MINUTOS=0 apaga el refresco automatico
	minutos, err := strconv.Atoi(plataforma.Var("REFRESCO_MINUTOS", "5"))
	if err == nil && minutos > 0 {
		slog.Info("refresco automatico activado", "cada_minutos", minutos)
		go s.RefrescarCada(context.Background(), time.Duration(minutos)*time.Minute)
	}
}

func (s *Servicio) listar(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	permitidas := []Vista{}
	for _, v := range vistas {
		if v.puedeVer(u.Rol) {
			permitidas = append(permitidas, v)
		}
	}
	resp := map[string]any{"vistas": permitidas}
	if t, err := s.UltimaActualizacion(r.Context()); err == nil {
		resp["datos_al"] = t
	}
	plataforma.ResponderJSON(w, http.StatusOK, resp)
}

func (s *Servicio) ver(w http.ResponseWriter, r *http.Request, u plataforma.Usuario, cli *plataforma.ClienteInterno) {
	v, ok := buscarVista(r.PathValue("vista"))
	if !ok {
		plataforma.ResponderError(w, http.StatusNotFound, "No existe el reporte "+r.PathValue("vista"))
		return
	}
	if !v.puedeVer(u.Rol) {
		plataforma.ResponderError(w, http.StatusForbidden, "Tu rol ("+u.Rol+") no puede ver "+v.Nombre)
		return
	}

	// INVENTARIO solo ve su sede; los corporativos pueden filtrar con ?sede=N
	sede := 0
	if u.Rol == plataforma.RolInventario {
		sede = u.Sede
	} else if n, err := strconv.Atoi(r.URL.Query().Get("sede")); err == nil {
		sede = n
	}
	limite := 1000
	if n, err := strconv.Atoi(r.URL.Query().Get("limite")); err == nil && n > 0 && n <= 5000 {
		limite = n
	}

	filas, err := s.Leer(r.Context(), v, sede, limite)
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	resp := map[string]any{"vista": v.Nombre, "filas": len(filas), "datos": filas}
	if sede > 0 && v.porSede {
		resp["sede"] = sede
	}
	if t, err := s.UltimaActualizacion(r.Context()); err == nil {
		resp["datos_al"] = t // la consistencia eventual, a la vista
	}
	cli.Auditar(r, u, "SELECT", "reportes."+v.Nombre)
	plataforma.ResponderJSON(w, http.StatusOK, resp)
}

func (s *Servicio) refrescarAhora(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Minute)
	defer cancel()
	dur, err := s.Refrescar(ctx)
	if errors.Is(err, ErrOcupado) {
		plataforma.ResponderError(w, http.StatusConflict, err.Error())
		return
	}
	if err != nil {
		// casi siempre: una de las otras instancias no responde (dblink)
		slog.Error("fallo el refresco", "error", err)
		plataforma.ResponderError(w, http.StatusServiceUnavailable,
			"No se pudo refrescar (alguna base no responde); quedan los datos anteriores")
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, map[string]any{
		"mensaje": "reportes refrescados", "duracion_ms": dur.Milliseconds(),
	})
}
