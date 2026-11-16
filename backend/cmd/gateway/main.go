// el programa del gateway: la unica puerta de entrada al backend.
//
//	go run ./backend/cmd/gateway -config config/local.env
package main

import (
	"flag"
	"log/slog"
	"os"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/gateway"
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, nil)).With("servicio", "gateway"))

	rutaEnv := flag.String("config", plataforma.Var("CONFIG", "config/local.env"), "archivo .env con la configuracion")
	flag.Parse()
	if err := plataforma.CargarEnv(*rutaEnv); err != nil {
		slog.Error("no se pudo arrancar", "error", err)
		os.Exit(1)
	}
	token := os.Getenv("TOKEN_INTERNO")
	if token == "" {
		slog.Error("no se pudo arrancar", "error", "falta TOKEN_INTERNO en el .env")
		os.Exit(1)
	}

	g, err := gateway.Nuevo(token)
	if err != nil {
		slog.Error("no se pudo arrancar", "error", err)
		os.Exit(1)
	}
	// el gateway si escucha en todas las interfaces: es la puerta publica
	if err := plataforma.Escuchar(":"+plataforma.Var("PUERTO_GATEWAY", "8080"), g.Rutas()); err != nil {
		slog.Error("el servidor se detuvo", "error", err)
		os.Exit(1)
	}
}
