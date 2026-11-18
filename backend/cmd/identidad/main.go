// el programa del microservicio de identidad (login, sesiones, auditoria).
package main

import (
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/servicios/identidad"
)

func main() {
	plataforma.CorrerServicio("identidad", identidad.Rutas)
}
