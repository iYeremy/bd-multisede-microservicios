// el programa del microservicio de inventarios.
package main

import (
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/servicios/inventarios"
)

func main() {
	plataforma.CorrerServicio("inventarios", inventarios.Rutas)
}
