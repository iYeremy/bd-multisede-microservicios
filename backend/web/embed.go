// Package web es el front: html, css y js planos, sin frameworks ni
// compilacion. go:embed los mete DENTRO del binario del gateway al
// compilar, asi que el gateway no necesita leer archivos del disco (y la
// imagen de docker sigue siendo un solo ejecutable).
package web

import (
	"embed"
	"io/fs"
)

//go:embed static
var archivos embed.FS

// Archivos devuelve la carpeta static como raiz: /index.html, /app.js...
func Archivos() fs.FS {
	sub, err := fs.Sub(archivos, "static")
	if err != nil {
		panic(err) // solo si se borra la carpeta static: no compila sin ella
	}
	return sub
}
