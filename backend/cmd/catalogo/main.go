// el programa del microservicio de catalogo.
//
//	go run ./backend/cmd/catalogo -config config/local.env
package main

import (
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/servicios/catalogo"
)

func main() {
	plataforma.CorrerServicio("catalogo", catalogo.Rutas)
}
