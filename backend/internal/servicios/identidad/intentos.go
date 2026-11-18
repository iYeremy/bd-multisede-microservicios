package identidad

import (
	"errors"
	"strings"
	"sync"
	"time"
)

// limite de intentos fallidos de login, por nombre de usuario: despues de
// maxFallos claves malas seguidas, ese usuario queda bloqueado un rato
// (aunque luego mande la clave correcta). asi nadie puede probar miles de
// claves contra una cuenta.
const (
	maxFallos     = 5
	tiempoBloqueo = 15 * time.Minute
	ventanaFallos = 15 * time.Minute // los fallos mas viejos que esto se olvidan
)

// ErrBloqueado: demasiados intentos fallidos para ese usuario.
var ErrBloqueado = errors.New("demasiados intentos fallidos: espera unos minutos")

type registroFallos struct {
	fallos    int
	primero   time.Time // cuando empezo la racha de fallos
	bloqueado time.Time // hasta cuando (cero: no bloqueado)
}

// intentos lleva la cuenta en memoria (como las sesiones: si identidad se
// reinicia, se olvida, y eso esta bien).
type intentos struct {
	mu         sync.Mutex
	porUsuario map[string]*registroFallos
	ahora      func() time.Time // en las pruebas se cambia para no esperar 15 min
}

func nuevosIntentos() *intentos {
	return &intentos{porUsuario: map[string]*registroFallos{}, ahora: time.Now}
}

func clave(usuario string) string { return strings.ToLower(strings.TrimSpace(usuario)) }

// bloqueado dice si el usuario esta bloqueado y por cuanto tiempo mas.
func (in *intentos) bloqueado(usuario string) (time.Duration, bool) {
	in.mu.Lock()
	defer in.mu.Unlock()
	r, ok := in.porUsuario[clave(usuario)]
	if !ok {
		return 0, false
	}
	falta := r.bloqueado.Sub(in.ahora())
	return falta, falta > 0
}

// fallo suma un intento fallido; al llegar a maxFallos bloquea al usuario.
func (in *intentos) fallo(usuario string) {
	in.mu.Lock()
	defer in.mu.Unlock()
	ahora := in.ahora()
	r, ok := in.porUsuario[clave(usuario)]
	if !ok || ahora.Sub(r.primero) > ventanaFallos {
		r = &registroFallos{primero: ahora}
		in.porUsuario[clave(usuario)] = r
	}
	r.fallos++
	if r.fallos >= maxFallos {
		r.bloqueado = ahora.Add(tiempoBloqueo)
		r.fallos = 0
		r.primero = ahora
	}
}

// exito borra la cuenta de fallos (entro bien).
func (in *intentos) exito(usuario string) {
	in.mu.Lock()
	delete(in.porUsuario, clave(usuario))
	in.mu.Unlock()
}

// limpiar borra los registros viejos, para que el mapa no crezca sin fin
// (alguien podria mandar logins con millones de nombres inventados).
func (in *intentos) limpiar() {
	in.mu.Lock()
	defer in.mu.Unlock()
	ahora := in.ahora()
	for k, r := range in.porUsuario {
		if ahora.After(r.bloqueado) && ahora.Sub(r.primero) > ventanaFallos {
			delete(in.porUsuario, k)
		}
	}
}
