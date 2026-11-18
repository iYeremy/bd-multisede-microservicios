// el programa del microservicio de compras.
package main

import (
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/servicios/compras"
)

func main() {
	plataforma.CorrerServicio("compras", compras.Rutas)
}
