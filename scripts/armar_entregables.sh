#!/usr/bin/env bash
# armar_entregables.sh
# arma docs/entregables/: una carpeta por cada entregable de la seccion 12
# del enunciado, en el mismo orden, con COPIAS de los archivos. sirve para
# revisar la entrega punto por punto.
#
#   scripts/armar_entregables.sh
#
# los originales siguen donde estan (docs/, sql/...): si cambias algo,
# cambialo alli y vuelve a correr este script. la carpeta se borra y se
# arma de nuevo cada vez (menos su README.md, el indice, que se edita a mano). en las copias .md se corrigen los enlaces
# relativos para que sigan apuntando a los archivos de verdad.

set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
DEST=docs/entregables

python3 - "$DEST" <<'PYEOF'
import os, re, shutil, sys

dest = sys.argv[1]
# (carpeta, [(origen, destino dentro de la carpeta)])  destino None = mismo nombre
ENTREGABLES = [
    ("01-problema-alcance-supuestos-reglas", [
        ("docs/problema-alcance-supuestos-reglasdenegocio.md", None)]),
    ("02-diagrama-arquitectura", [
        ("docs/diagramas/01_arquitectura", "diagramas")]),
    ("03-modelo-entidad-relacion", [
        ("docs/diagramas/02_modelo_ER", "diagramas")]),
    ("04-modelo-relacional-normalizacion-diccionario", [
        ("docs/diagramas/03_modelo_relacional", "diagrama-relacional"),
        ("docs/normalizacion.md", None),
        ("docs/diagramas/05_normalizacion", "diagramas-normalizacion"),
        ("docs/diccionario-datos.md", None),
        ("docs/diagramas/04_diccionario", "diagramas-diccionario")]),
    ("05-esquemas-servicios-fragmentos-vistas", [
        ("docs/distribucion.md", None),
        ("docs/despliegue.md", None)]),
    ("06-scripts-estructura", [
        ("run_all.sql", None),
        ("sql/README.md", None),
        ("sql/00_config", "00_config"),
        ("sql/01_bases", "01_bases"),
        ("sql/02_tablas", "02_tablas"),
        ("sql/03_dblink", "03_dblink")]),
    ("07-scripts-datos-prueba", [
        ("sql/04_datos", "04_datos")]),
    ("08-scripts-seguridad", [
        ("sql/06_roles", "06_roles")]),
    ("09-scripts-fragmentacion-vistas-unificadas", [
        ("sql/02_tablas/inventarios.sql", "fragmentos/inventarios.sql"),
        ("sql/02_tablas/ventas.sql", "fragmentos/ventas.sql"),
        ("sql/02_tablas/README.md", "fragmentos/README.md"),
        ("sql/05_reportes/vistas.sql", "vistas-unificadas/vistas.sql")]),
    ("10-scripts-vistas", [
        ("sql/05_reportes", "05_reportes")]),
    ("11-scripts-consultas", [
        ("sql/07_consultas", "07_consultas")]),
    ("12-resultados-evidencias", [
        ("docs/matriz-pruebas.md", None),
        ("docs/evidencias.txt", None),
        ("docs/evidencias-neon.txt", None),
        ("docs/evidencias-backend.txt", None),
        ("sql/08_pruebas", "08_pruebas")]),
    ("13-analisis-resultados", [
        ("docs/analisis-resultados.md", None)]),
    ("14-manual-instalacion-ejecucion", [
        ("docs/manual-ejecucion.md", None),
        ("docs/despliegue.md", None)]),
    ("15-conclusiones-limitaciones-extensiones", [
        ("docs/conclusiones.md", None)]),
]

ENLACE = re.compile(r'(!?\[[^\]]*\]\()([^)\s]+)(\))')

def corregir_enlaces(texto, dir_original, dir_nuevo):
    # un enlace relativo se resuelve desde donde estaba el original y se
    # vuelve a escribir relativo a donde queda la copia
    def cambiar(m):
        destino = m.group(2)
        if re.match(r'^[a-z]+:', destino) or destino.startswith('#'):
            return m.group(0)
        ruta, ancla = (destino.split('#', 1) + [''])[:2]
        absoluta = os.path.normpath(os.path.join(dir_original, ruta))
        nueva = os.path.relpath(absoluta, dir_nuevo)
        return m.group(1) + nueva + ('#' + ancla if ancla else '') + m.group(3)
    return ENLACE.sub(cambiar, texto)

def copiar_archivo(origen, destino):
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    if origen.endswith('.md'):
        texto = open(origen, encoding='utf-8').read()
        texto = corregir_enlaces(texto, os.path.dirname(origen), os.path.dirname(destino))
        open(destino, 'w', encoding='utf-8').write(texto)
    else:
        shutil.copy2(origen, destino)

# se borra todo menos el README.md (el indice, que se edita a mano)
os.makedirs(dest, exist_ok=True)
for e in os.listdir(dest):
    if e != 'README.md':
        p = os.path.join(dest, e)
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
total = 0
for carpeta, piezas in ENTREGABLES:
    base = os.path.join(dest, carpeta)
    for origen, nombre in piezas:
        if not os.path.exists(origen):
            sys.exit(f"falta {origen}")
        destino = os.path.join(base, nombre or os.path.basename(origen))
        if os.path.isdir(origen):
            for raiz, _, archivos in os.walk(origen):
                for a in sorted(archivos):
                    o = os.path.join(raiz, a)
                    copiar_archivo(o, os.path.join(destino, os.path.relpath(o, origen)))
                    total += 1
        else:
            copiar_archivo(origen, destino)
            total += 1
    print(f"   {carpeta}")
print(f">> {total} archivos copiados en {dest}/")
PYEOF
