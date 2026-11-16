// el programa del microservicio de ventas.
package main

import (
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/servicios/ventas"
)

func main() {
	plataforma.CorrerServicio("ventas", ventas.Rutas)
}
