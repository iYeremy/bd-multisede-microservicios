// el programa del microservicio de reportes.
package main

import (
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/servicios/reportes"
)

func main() {
	plataforma.CorrerServicio("reportes", reportes.Rutas)
}
