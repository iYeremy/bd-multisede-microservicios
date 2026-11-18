package plataforma_test

import (
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// la regla de los microservicios en el codigo: un servicio NUNCA importa el
// paquete de otro servicio. si ventas necesita un producto, se lo pide a
// catalogo por http. esta prueba revisa los import de cada servicio.
func TestNingunServicioImportaOtro(t *testing.T) {
	raiz := filepath.Join("..", "servicios")
	servicios, err := os.ReadDir(raiz)
	if err != nil {
		t.Fatal(err)
	}
	for _, s := range servicios {
		if !s.IsDir() {
			continue
		}
		archivos, _ := filepath.Glob(filepath.Join(raiz, s.Name(), "*.go"))
		for _, a := range archivos {
			f, err := parser.ParseFile(token.NewFileSet(), a, nil, parser.ImportsOnly)
			if err != nil {
				t.Fatal(err)
			}
			for _, imp := range f.Imports {
				ruta := strings.Trim(imp.Path.Value, `"`)
				if strings.Contains(ruta, "/internal/servicios/") && !strings.HasSuffix(ruta, "/servicios/"+s.Name()) {
					t.Errorf("%s importa a otro servicio (%s): debe pedirle los datos por http", a, ruta)
				}
			}
		}
	}
}
