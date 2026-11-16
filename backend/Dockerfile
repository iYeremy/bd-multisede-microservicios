# backend/Dockerfile
# una sola receta para los 7 programas: PROGRAMA dice cual compilar.
#   docker build --build-arg PROGRAMA=catalogo -t andina/catalogo backend/
#
# tiene dos etapas (multi-stage):
#   1. "compilar": una imagen grande con go, que compila el programa
#   2. la final: solo el ejecutable, sobre una imagen minima. go compila a
#      un binario que no necesita nada mas, asi que la imagen pesa ~15 MB

# ---- etapa 1: compilar ----
FROM golang:1.27-alpine AS compilar
WORKDIR /src

# primero solo go.mod y go.sum: si no cambian, docker reutiliza esta capa
# (las dependencias ya descargadas) y no las baja de nuevo en cada build
COPY go.mod go.sum ./
RUN go mod download

# ahora el codigo, y se compila
COPY . .
ARG PROGRAMA
# CGO_ENABLED=0: binario estatico, sin depender de librerias del sistema
# -ldflags "-s -w": sin informacion de depuracion, mas pequeno
RUN test -n "$PROGRAMA" || (echo "falta --build-arg PROGRAMA=<programa>" && exit 1)
RUN CGO_ENABLED=0 go build -ldflags "-s -w" -o /programa ./cmd/$PROGRAMA

# ---- etapa 2: la imagen que se ejecuta ----
# distroless: sin shell, sin gestor de paquetes, casi nada que atacar. trae
# los certificados para conectarse por ssl (neon) y un usuario sin
# privilegios (nonroot): el programa no corre como root
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=compilar /programa /programa
# en docker la configuracion llega por variables de entorno, no por archivo
ENV CONFIG="" \
    ESCUCHAR_EN=0.0.0.0
USER nonroot
ENTRYPOINT ["/programa"]
