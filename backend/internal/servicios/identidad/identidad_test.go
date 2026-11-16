package identidad

import (
	"crypto/md5"
	"encoding/hex"
	"testing"
	"time"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"golang.org/x/crypto/bcrypt"
)

func TestClaveCorrecta(t *testing.T) {
	suma := md5.Sum([]byte("vendedor_cali2026"))
	hashMD5 := hex.EncodeToString(suma[:])
	hashBcrypt, _ := bcrypt.GenerateFromPassword([]byte("vendedor_cali2026"), bcrypt.MinCost)

	if ok, esMD5 := claveCorrecta(hashMD5, "vendedor_cali2026"); !ok || !esMD5 {
		t.Error("md5 con la clave buena deberia pasar y pedir migracion")
	}
	if ok, _ := claveCorrecta(hashMD5, "otra"); ok {
		t.Error("md5 con clave mala no deberia pasar")
	}
	if ok, esMD5 := claveCorrecta(string(hashBcrypt), "vendedor_cali2026"); !ok || esMD5 {
		t.Error("bcrypt con la clave buena deberia pasar sin migrar")
	}
	if ok, _ := claveCorrecta(string(hashBcrypt), "otra"); ok {
		t.Error("bcrypt con clave mala no deberia pasar")
	}
}

func TestSesionVence(t *testing.T) {
	s := nuevo(nil)
	s.sesiones["viva"] = sesion{usuario: plataforma.Usuario{ID: 1}, expira: time.Now().Add(time.Hour)}
	s.sesiones["vieja"] = sesion{usuario: plataforma.Usuario{ID: 2}, expira: time.Now().Add(-time.Second)}

	if _, ok := s.Sesion("viva"); !ok {
		t.Error("la sesion vigente deberia valer")
	}
	if _, ok := s.Sesion("vieja"); ok {
		t.Error("la sesion vencida no deberia valer")
	}
	if _, ok := s.Sesion("inventada"); ok {
		t.Error("un token inventado no deberia valer")
	}
}
