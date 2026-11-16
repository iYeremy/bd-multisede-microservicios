package plataforma

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Registrar es lo que cada servicio aporta: sus rutas. recibe el mux donde
// colgarlas, el pool de conexiones a su base y su configuracion.
type Registrar func(mux *http.ServeMux, db *pgxpool.Pool, cfg Config)

// CorrerServicio es el main de todos los servicios: lee la configuracion,
// se conecta a SU instancia, agrega /salud y las rutas del servicio, y
// escucha en 127.0.0.1:<puerto>. si algo falla al arrancar, sale con error.
func CorrerServicio(nombre string, registrar Registrar) {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, nil)).With("servicio", nombre))

	if err := correr(nombre, registrar); err != nil {
		slog.Error("no se pudo arrancar", "error", err)
		os.Exit(1)
	}
}

func correr(nombre string, registrar Registrar) error {
	rutaEnv := flag.String("config", Var("CONFIG", "config/local.env"), "archivo .env con la configuracion")
	flag.Parse()
	if err := CargarEnv(*rutaEnv); err != nil {
		return err
	}

	cfg, err := ConfigDe(nombre)
	if err != nil {
		return err
	}

	db, err := ConectarDB(cfg.DBURL)
	if err != nil {
		return err
	}
	defer db.Close()

	mux := http.NewServeMux()
	// /salud: el servicio esta vivo y llega a su base. lo usa el gateway.
	mux.HandleFunc("GET /salud", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := db.Ping(ctx); err != nil {
			ResponderJSON(w, http.StatusServiceUnavailable, map[string]string{"estado": "sin base de datos"})
			return
		}
		ResponderJSON(w, http.StatusOK, map[string]string{"estado": "ok"})
	})
	registrar(mux, db, cfg)

	return Escuchar(cfg.Direccion, mux)
}

// ConectarDB abre un pool de conexiones (conexiones abiertas que se
// reutilizan) y comprueba que la base responda.
func ConectarDB(url string) (*pgxpool.Pool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	db, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("configuracion de la base invalida: %w", err)
	}
	if err := db.Ping(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("no se pudo conectar a la base: %w", err)
	}
	return db, nil
}
