package ventas

import (
	"encoding/json"
	"testing"
)

// prueba de tabla: una lista de casos y un solo for que los revisa todos.
// es la forma mas comun de escribir pruebas en go.
func TestValidarPedido(t *testing.T) {
	casos := []struct {
		nombre string
		json   string
		valido bool
	}{
		{"bien", `{"id_cliente":5,"productos":[{"id_producto":1,"cantidad":3}]}`, true},
		{"sin cliente", `{"productos":[{"id_producto":1,"cantidad":3}]}`, false},
		{"sin productos", `{"id_cliente":5,"productos":[]}`, false},
		{"cantidad cero", `{"id_cliente":5,"productos":[{"id_producto":1,"cantidad":0}]}`, false},
		{"cantidad negativa", `{"id_cliente":5,"productos":[{"id_producto":1,"cantidad":-2}]}`, false},
		{"repetido", `{"id_cliente":5,"productos":[{"id_producto":1,"cantidad":1},{"id_producto":1,"cantidad":2}]}`, false},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			var sp solicitudPedido
			if err := json.Unmarshal([]byte(c.json), &sp); err != nil {
				t.Fatal(err)
			}
			err := sp.validar()
			if (err == nil) != c.valido {
				t.Errorf("valido = %v, se esperaba %v (error: %v)", err == nil, c.valido, err)
			}
		})
	}
}

func TestFragmentos(t *testing.T) {
	if got := NombreFragmento(3); got != "ventas.ped_cali" {
		t.Errorf("sede 3 = %q", got)
	}
	if _, err := fragmentoDe(9); err != ErrSedeInvalida {
		t.Errorf("sede 9 deberia ser invalida, dio %v", err)
	}
	// el nombre se escapa con comillas: asi nunca se puede inyectar sql
	f, _ := fragmentoDe(1)
	if got := f.detalle.Sanitize(); got != `"ventas"."det_ped_bogota"` {
		t.Errorf("Sanitize = %s", got)
	}
}
