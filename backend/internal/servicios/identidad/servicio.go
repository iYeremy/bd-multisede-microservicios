// Package identidad es el microservicio de Identidad y Accesos: login,
// sesiones y auditoria. lee SOLO su base (andina_identidad) con svc_identidad.
package identidad

import (
	"context"
	"crypto/md5"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// cuanto dura una sesion sin volver a iniciar sesion
const duracionSesion = 8 * time.Hour

// Servicio guarda la conexion a la base y las sesiones abiertas.
type Servicio struct {
	db       *pgxpool.Pool
	mu       sync.Mutex // protege sesiones: varias peticiones llegan a la vez
	sesiones map[string]sesion
	intentos *intentos // logins fallidos por usuario (ver intentos.go)
}

type sesion struct {
	usuario plataforma.Usuario
	expira  time.Time
}

func nuevo(db *pgxpool.Pool) *Servicio {
	return &Servicio{db: db, sesiones: map[string]sesion{}, intentos: nuevosIntentos()}
}

// ErrCredenciales: usuario o clave incorrectos, o usuario inactivo. a
// proposito no dice cual de las tres fallo, para no dar pistas.
var ErrCredenciales = errors.New("usuario o contrasena incorrectos")

// hash falso para cuando el usuario no existe: igual se corre bcrypt, asi
// la respuesta tarda lo mismo y no se puede adivinar que usuarios existen.
var hashFalso, _ = bcrypt.GenerateFromPassword([]byte("no-existe"), bcrypt.DefaultCost)

// Login revisa usuario y clave. si estan bien, abre una sesion y devuelve
// su token (un numero al azar que el navegador guarda en una cookie).
func (s *Servicio) Login(ctx context.Context, nombre, clave string) (string, plataforma.Usuario, error) {
	var u plataforma.Usuario
	// bloqueado: ni se mira la clave (si no, se podria seguir probando)
	if _, bloq := s.intentos.bloqueado(nombre); bloq {
		return "", u, ErrBloqueado
	}
	token, u, err := s.revisarClave(ctx, nombre, clave)
	switch {
	case errors.Is(err, ErrCredenciales):
		s.intentos.fallo(nombre)
	case err == nil:
		s.intentos.exito(nombre)
	}
	return token, u, err
}

func (s *Servicio) revisarClave(ctx context.Context, nombre, clave string) (string, plataforma.Usuario, error) {
	var u plataforma.Usuario
	var hash, estadoUsuario, estadoEmpleado string
	err := s.db.QueryRow(ctx, `
		SELECT u.id_usuario, u.nombre_usuario, u.rol, u.password_hash, u.estado,
		       e.id_empleado, e.id_sede, e.estado
		FROM identidad.usuarios u
		JOIN identidad.empleados e ON e.id_empleado = u.id_empleado
		WHERE u.nombre_usuario = $1`, nombre).
		Scan(&u.ID, &u.Nombre, &u.Rol, &hash, &estadoUsuario, &u.Empleado, &u.Sede, &estadoEmpleado)
	if errors.Is(err, pgx.ErrNoRows) {
		bcrypt.CompareHashAndPassword(hashFalso, []byte(clave))
		return "", u, ErrCredenciales
	}
	if err != nil {
		return "", u, err
	}

	ok, esMD5 := claveCorrecta(hash, clave)
	if !ok || estadoUsuario != "ACTIVO" || estadoEmpleado != "ACTIVO" {
		return "", u, ErrCredenciales
	}
	if esMD5 {
		s.migrarHash(ctx, u.ID, clave)
	}

	token := nuevoToken()
	s.mu.Lock()
	s.sesiones[token] = sesion{usuario: u, expira: time.Now().Add(duracionSesion)}
	s.mu.Unlock()

	s.registrar(ctx, u.ID, "LOGIN", "identidad.sesion")
	return token, u, nil
}

// claveCorrecta compara la clave con el hash guardado. los datos de prueba
// traen hashes md5 viejos (md5 de usuario || '2026'); los nuevos son bcrypt
// (empiezan por $2). esMD5 avisa que hay que cambiarlo por uno bcrypt.
func claveCorrecta(hash, clave string) (ok, esMD5 bool) {
	if strings.HasPrefix(hash, "$2") {
		return bcrypt.CompareHashAndPassword([]byte(hash), []byte(clave)) == nil, false
	}
	suma := md5.Sum([]byte(clave))
	igual := subtle.ConstantTimeCompare([]byte(hex.EncodeToString(suma[:])), []byte(hash)) == 1
	return igual, igual
}

// migrarHash cambia el md5 por bcrypt la primera vez que el usuario entra:
// es el unico momento en que tenemos la clave en texto plano. si falla, no
// pasa nada: se intenta en el siguiente login.
func (s *Servicio) migrarHash(ctx context.Context, idUsuario int, clave string) {
	nuevo, err := bcrypt.GenerateFromPassword([]byte(clave), bcrypt.DefaultCost)
	if err == nil {
		_, err = s.db.Exec(ctx, `UPDATE identidad.usuarios SET password_hash = $1 WHERE id_usuario = $2`,
			string(nuevo), idUsuario)
	}
	if err != nil {
		slog.Warn("no se pudo pasar la clave a bcrypt", "id_usuario", idUsuario, "error", err)
		return
	}
	slog.Info("clave pasada de md5 a bcrypt", "id_usuario", idUsuario)
}

// nuevoToken genera 32 bytes al azar (crypto/rand: imposible de adivinar).
func nuevoToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// Sesion devuelve el usuario dueno del token, si la sesion sigue vigente.
func (s *Servicio) Sesion(token string) (plataforma.Usuario, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	ses, ok := s.sesiones[token]
	if !ok {
		return plataforma.Usuario{}, false
	}
	if time.Now().After(ses.expira) {
		delete(s.sesiones, token)
		return plataforma.Usuario{}, false
	}
	return ses.usuario, true
}

// Logout cierra la sesion del token.
func (s *Servicio) Logout(ctx context.Context, token string) {
	s.mu.Lock()
	ses, ok := s.sesiones[token]
	delete(s.sesiones, token)
	s.mu.Unlock()
	if ok {
		s.registrar(ctx, ses.usuario.ID, "LOGOUT", "identidad.sesion")
	}
}

// limpiar borra las sesiones vencidas cada cierto tiempo, para que el mapa
// no crezca sin fin. corre en su propia goroutine hasta que el ctx termina.
func (s *Servicio) limpiar(ctx context.Context) {
	t := time.NewTicker(10 * time.Minute)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.mu.Lock()
			for k, ses := range s.sesiones {
				if time.Now().After(ses.expira) {
					delete(s.sesiones, k)
				}
			}
			s.mu.Unlock()
			s.intentos.limpiar()
		}
	}
}

// acciones validas (el CHECK de auditoria_accesos.accion)
var accionesValidas = map[string]bool{
	"LOGIN": true, "LOGOUT": true, "SELECT": true, "INSERT": true, "UPDATE": true, "DELETE": true,
}

// Registrar inserta una fila en la auditoria.
func (s *Servicio) Registrar(ctx context.Context, idUsuario int, accion, objeto string) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO identidad.auditoria_accesos (id_usuario, accion, objeto_consultado)
		VALUES ($1, $2, $3)`, idUsuario, accion, objeto)
	return err
}

// registrar es Registrar sin devolver error: el login no debe fallar
// porque no se pudo escribir la auditoria.
func (s *Servicio) registrar(ctx context.Context, idUsuario int, accion, objeto string) {
	if err := s.Registrar(ctx, idUsuario, accion, objeto); err != nil {
		slog.Warn("no se pudo registrar la auditoria", "accion", accion, "error", err)
	}
}

// Acceso es una fila de la auditoria.
type Acceso struct {
	ID      int       `json:"id_auditoria"`
	Usuario string    `json:"nombre_usuario"`
	Rol     string    `json:"rol"`
	Fecha   time.Time `json:"fecha_hora"`
	Accion  string    `json:"accion"`
	Objeto  string    `json:"objeto_consultado"`
}

// Auditoria devuelve los ultimos accesos, del mas nuevo al mas viejo.
func (s *Servicio) Auditoria(ctx context.Context, limite int) ([]Acceso, error) {
	rows, err := s.db.Query(ctx, `
		SELECT a.id_auditoria, u.nombre_usuario, u.rol, a.fecha_hora, a.accion, a.objeto_consultado
		FROM identidad.auditoria_accesos a
		JOIN identidad.usuarios u ON u.id_usuario = a.id_usuario
		ORDER BY a.fecha_hora DESC, a.id_auditoria DESC
		LIMIT $1`, limite)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByPos[Acceso])
}
