// Package plataforma es el codigo que comparten todos los programas del
// backend: configuracion, conexion a la base, respuestas http y llamadas
// entre servicios. solo es "plomeria": aqui no hay reglas de negocio.
package plataforma

import (
	"bufio"
	"flag"
	"fmt"
	"net/url"
	"os"
	"strings"
)

// CargarEnv lee un archivo .env (una variable por linea, NOMBRE=valor) y
// pone en el entorno las que todavia no existan. las lineas vacias y las
// que empiezan con # se ignoran. es el mismo archivo que usan los scripts
// sql (config/local.env o config/neon.env).
func CargarEnv(ruta string) error {
	f, err := os.Open(ruta)
	if err != nil {
		return fmt.Errorf("no se pudo abrir %s: %w", ruta, err)
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		linea := strings.TrimSpace(sc.Text())
		if linea == "" || strings.HasPrefix(linea, "#") {
			continue
		}
		nombre, valor, ok := strings.Cut(linea, "=")
		if !ok {
			continue
		}
		nombre = strings.TrimSpace(nombre)
		// si la variable ya existe en el entorno, gana la del entorno
		if _, existe := os.LookupEnv(nombre); !existe {
			os.Setenv(nombre, strings.TrimSpace(valor))
		}
	}
	return sc.Err()
}

// LeerConfig carga la configuracion al arrancar un programa. dos formas:
//   - en tu pc: un archivo .env (por defecto config/local.env, o -config otro.env)
//   - en docker: CONFIG= (vacio) y todo llega como variables de entorno,
//     que es como se configura un contenedor. no se lee ningun archivo.
func LeerConfig() error {
	porDefecto := "config/local.env"
	if v, existe := os.LookupEnv("CONFIG"); existe {
		porDefecto = v
	}
	ruta := flag.String("config", porDefecto, "archivo .env con la configuracion (vacio: solo variables de entorno)")
	flag.Parse()
	if *ruta == "" {
		return nil
	}
	return CargarEnv(*ruta)
}

// Var devuelve una variable de entorno, o porDefecto si no existe o esta vacia.
func Var(nombre, porDefecto string) string {
	if v := os.Getenv(nombre); v != "" {
		return v
	}
	return porDefecto
}

// puertos por defecto de cada servicio (solo escuchan en 127.0.0.1)
var puertos = map[string]string{
	"catalogo":    "8101",
	"identidad":   "8102",
	"compras":     "8103",
	"inventarios": "8104",
	"ventas":      "8105",
	"reportes":    "8106",
}

// Servicios es la lista de los seis microservicios, en orden.
var Servicios = []string{"catalogo", "identidad", "compras", "inventarios", "ventas", "reportes"}

// Config es todo lo que un servicio necesita para arrancar.
type Config struct {
	Nombre       string // catalogo, ventas...
	Direccion    string // donde escucha: 127.0.0.1:8101
	DBURL        string // conexion a SU instancia, con su usuario svc_*
	TokenInterno string // clave compartida para las rutas /interno
}

// ConfigDe arma la configuracion de un servicio a partir del entorno.
// cada servicio se conecta a su propia instancia, con su usuario tecnico:
//
//	postgresql://svc_ventas:<clave>@<VENTAS_HOST>:<VENTAS_PORT>/andina_ventas?sslmode=<SSLMODE>
func ConfigDe(servicio string) (Config, error) {
	puerto, ok := puertos[servicio]
	if !ok {
		return Config{}, fmt.Errorf("servicio desconocido: %s", servicio)
	}
	S := strings.ToUpper(servicio)

	host := os.Getenv(S + "_HOST")
	if host == "" {
		return Config{}, fmt.Errorf("falta %s_HOST: carga config/local.env (ver backend/README.md)", S)
	}
	token := os.Getenv("TOKEN_INTERNO")
	if token == "" {
		return Config{}, fmt.Errorf("falta TOKEN_INTERNO en el .env")
	}

	// url.URL escapa bien la clave aunque tenga caracteres raros
	u := url.URL{
		Scheme:   "postgresql",
		User:     url.UserPassword("svc_"+servicio, os.Getenv("SVC_"+S+"_PASSWORD")),
		Host:     host + ":" + Var(S+"_PORT", "5432"),
		Path:     "andina_" + servicio,
		RawQuery: "sslmode=" + Var("SSLMODE", "disable"),
	}

	return Config{
		Nombre: servicio,
		// ESCUCHAR_EN: 127.0.0.1 en una maquina (nadie de afuera llega), o
		// 0.0.0.0 en docker, donde cada servicio esta en su propio contenedor
		Direccion:    Var("ESCUCHAR_EN", "127.0.0.1") + ":" + Var("PUERTO_"+S, puerto),
		DBURL:        u.String(),
		TokenInterno: token,
	}, nil
}

// URLServicio devuelve la direccion http de un servicio, para llamarlo
// desde otro servicio o desde el gateway (por defecto http://127.0.0.1:810x).
func URLServicio(servicio string) string {
	return Var("URL_"+strings.ToUpper(servicio), "http://127.0.0.1:"+puertos[servicio])
}
