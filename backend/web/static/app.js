// app.js: todo el front en un archivo, javascript plano (sin frameworks).
//
// es una "single page app": hay un solo index.html y la parte despues del #
// dice que pagina mostrar (#/pedidos, #/reportes/vista_x...). al cambiar el
// #, navegar() pide los datos al gateway con fetch y pinta la pagina.
//
// lo importante para entender la seguridad: el front NO decide permisos.
// solo esconde del menu lo que tu rol no usa; si entras a mano a una ruta
// que no te toca, el servicio responde 403 y eso es lo que se muestra.
"use strict";

// ------------------------------------------------------------------
// datos generales
// ------------------------------------------------------------------

const ADM = "ADMINISTRADOR", GER = "GERENCIA", INV = "INVENTARIO",
      COM = "COMPRAS", VEN = "VENDEDOR", AUD = "AUDITOR";

const NOMBRE_ROL = {
  [ADM]: "Administrador", [GER]: "Gerencia", [INV]: "Inventario",
  [COM]: "Compras", [VEN]: "Vendedor", [AUD]: "Auditor",
};

// sufijo de los fragmentos de cada sede (ventas.ped_cali, inventarios.inv_cali)
const SUFIJO_SEDE = { 1: "bogota", 2: "medellin", 3: "cali", 4: "cedi" };

// usuarios de prueba (la clave es el usuario + 2026)
const DEMO = [
  ["admin_andina", ADM], ["gerente_general", GER], ["vendedor_cali", VEN],
  ["vendedor_bogota", VEN], ["inventario_cali", INV], ["compras_cedi", COM],
  ["auditor_interno", AUD],
];

const MENU = [
  { ruta: "#/inicio", texto: "Inicio" },
  { ruta: "#/pedidos", texto: "Pedidos", roles: [VEN, ADM] },
  { ruta: "#/inventario", texto: "Inventario", roles: [INV, ADM] },
  { ruta: "#/transferencias", texto: "Transferencias", roles: [INV, ADM] },
  { ruta: "#/compras", texto: "Compras", roles: [COM, ADM] },
  { ruta: "#/reportes", texto: "Reportes", roles: [GER, AUD, ADM, INV, COM] },
  { ruta: "#/catalogo", texto: "Catálogo", roles: [ADM, GER, INV, COM, VEN] },
  { ruta: "#/clientes", texto: "Clientes", roles: [ADM, VEN] },
  { ruta: "#/auditoria", texto: "Auditoría", roles: [AUD, ADM] },
  { ruta: "#/estado", texto: "Servicios" },
];

const estado = {
  usuario: null,   // lo que devuelve /api/identidad/yo
  sedes: [],       // /api/catalogo/sedes
  salud: null,     // la ultima respuesta de /salud
  turno: 0,        // sube en cada navegacion: si llega una respuesta vieja, se ignora
  reloj: null,     // intervalo de la pagina de estado
};

const puede = (...roles) => estado.usuario && roles.includes(estado.usuario.rol);

// ------------------------------------------------------------------
// utilidades
// ------------------------------------------------------------------

// esc: TODO dato que viene del servidor pasa por aqui antes de ir al html.
// asi un nombre como "<script>" se muestra como texto y no se ejecuta.
function esc(v) {
  return String(v ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

const fmtPesos = new Intl.NumberFormat("es-CO", { style: "currency", currency: "COP", maximumFractionDigits: 2, minimumFractionDigits: 0 });
const fmtNumero = new Intl.NumberFormat("es-CO", { maximumFractionDigits: 2 });
const dinero = (centavos) => fmtPesos.format((centavos ?? 0) / 100); // el backend manda centavos
const pesos = (valor) => fmtPesos.format(valor ?? 0);                // los reportes mandan pesos
const numero = (n) => fmtNumero.format(n ?? 0);

// las fechas sin hora llegan como "2026-10-12T00:00:00Z": se muestran en UTC,
// si no, en Colombia (UTC-5) saldria el dia anterior
function fecha(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d)) return esc(iso);
  if (/T00:00:00(\.0+)?Z$/.test(iso)) {
    return d.toLocaleDateString("es-CO", { timeZone: "UTC", day: "2-digit", month: "short", year: "numeric" });
  }
  return d.toLocaleString("es-CO", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
}

function nombreSede(id) {
  const s = estado.sedes.find((x) => x.id_sede === Number(id));
  return s ? s.nombre : `Sede ${id}`;
}

function leerHash() {
  const [camino, consulta = ""] = (location.hash || "#/inicio").split("?");
  return { camino, params: new URLSearchParams(consulta) };
}

const ir = (hash) => { if (location.hash === hash) navegar(); else location.hash = hash; };

// chip de color segun el estado de una fila
function chipEstado(v) {
  const t = String(v ?? "");
  const tipo = /^(ACTIVO|ACTIVA|ENTREGADO|RECIBIDA|CONFIRMADO|REGISTRADA|APROBADA)$/.test(t) ? "ok"
    : /^(PENDIENTE|PARCIAL|SOLICITADA|DESPACHADA|EMITIDA)$/.test(t) ? "aviso"
    : /^(ANULADO|ANULADA|CANCELADA|INACTIVO|INACTIVA|DESCONTINUADO|RECHAZADO|RECHAZADA|BLOQUEADO)$/.test(t) ? "mal"
    : "";
  return `<span class="chip ${tipo}">${esc(t.toLowerCase())}</span>`;
}

// ------------------------------------------------------------------
// hablar con el gateway
// ------------------------------------------------------------------

class ErrorApi extends Error {
  constructor(codigo, mensaje) { super(mensaje); this.codigo = codigo; }
}

// api hace un fetch al gateway. la cookie de sesion la manda el navegador
// solo (HttpOnly: este codigo ni siquiera puede leerla).
async function api(ruta, { metodo = "GET", cuerpo, sinRedirigir = false } = {}) {
  let resp;
  try {
    resp = await fetch(ruta, {
      method: metodo,
      credentials: "same-origin",
      headers: cuerpo ? { "Content-Type": "application/json" } : {},
      body: cuerpo ? JSON.stringify(cuerpo) : undefined,
    });
  } catch {
    throw new ErrorApi(0, "No hay conexión con el servidor.");
  }
  let datos = null;
  try { datos = await resp.json(); } catch { /* sin cuerpo json */ }
  if (!resp.ok) {
    if (resp.status === 401 && !sinRedirigir) {
      estado.usuario = null;
      location.hash = "#/login";
    }
    throw new ErrorApi(resp.status, (datos && datos.error) || `Error ${resp.status}`);
  }
  return datos;
}

// ------------------------------------------------------------------
// piezas de html
// ------------------------------------------------------------------

function mensaje(tipo, titulo, texto = "") {
  return `<div class="mensaje ${tipo}"><strong>${esc(titulo)}</strong>${texto ? `<span class="tenue">${esc(texto)}</span>` : ""}</div>`;
}

// explica un error de la api en palabras simples
function mensajeError(e) {
  const c = e.codigo;
  const titulo = c === 403 ? "No tienes permiso para ver esto"
    : c === 503 ? "Un servicio no está disponible"
    : c === 404 ? "No existe"
    : c === 400 ? "Los datos no son válidos"
    : c === 429 ? "Demasiados intentos"
    : c === 0 ? "Sin conexión"
    : "Algo salió mal";
  const nota = c === 403 ? " El permiso lo revisa el servicio en el servidor, no esta página."
    : c === 503 ? " Mira la página Servicios para ver cuál está caído." : "";
  return mensaje(c === 503 || c === 429 ? "aviso" : "error", titulo, e.message + nota);
}

function aviso(datos) {
  return datos && datos.aviso ? mensaje("aviso", "Funcionando a medias", datos.aviso + ". Los datos de esta página sí son correctos.") : "";
}

function cabecera(titulo, texto = "", acciones = "") {
  return `<div class="cabecera"><div><h1>${esc(titulo)}</h1>${texto ? `<p>${texto}</p>` : ""}</div>
    ${acciones ? `<div class="acciones">${acciones}</div>` : ""}</div>`;
}

// selector de sede: solo el administrador puede mirar otra sede (?sede=N).
// para los demas la sede SIEMPRE sale de la sesion, en el servidor.
function selectorSede(params) {
  if (!puede(ADM)) return "";
  const actual = params.get("sede") || String(estado.usuario.id_sede);
  const opciones = [1, 2, 3, 4].map((id) =>
    `<option value="${id}" ${String(id) === actual ? "selected" : ""}>${esc(nombreSede(id))}</option>`).join("");
  return `<select id="sede" aria-label="Sede">${opciones}</select>`;
}

function conSede(ruta, params) {
  const s = params.get("sede");
  return s && puede(ADM) ? `${ruta}${ruta.includes("?") ? "&" : "?"}sede=${encodeURIComponent(s)}` : ruta;
}

// cambia un parametro del # y vuelve a pintar (filtros, sede)
function cambiarParam(nombre, valor) {
  const { camino, params } = leerHash();
  if (valor) params.set(nombre, valor); else params.delete(nombre);
  const q = params.toString();
  ir(camino + (q ? "?" + q : ""));
}

function opcionesSelect(lista, actual, todas = "Todos") {
  return `<option value="">${esc(todas)}</option>` +
    lista.map((v) => `<option value="${esc(v)}" ${v === actual ? "selected" : ""}>${esc(v.toLowerCase())}</option>`).join("");
}

// ---- tabla generica ----
// columnas: [{ clave, titulo, tipo }] ; tipo: texto | numero | dinero (centavos)
// | pesos | fecha | estado | bool | codigo. con enlace(fila) cada fila es clic.
function tabla(filas, columnas, { enlace, vacio = "No hay filas." } = {}) {
  if (!filas || filas.length === 0) return `<div class="tarjeta"><p>${esc(vacio)}</p></div>`;
  const num = (t) => ["numero", "dinero", "pesos"].includes(t);
  const celda = (fila, c) => {
    const v = fila[c.clave];
    if (v === null || v === undefined) return `<td class="vacio">—</td>`;
    switch (c.tipo) {
      case "numero": return `<td class="num">${numero(v)}</td>`;
      case "dinero": return `<td class="num">${dinero(v)}</td>`;
      case "pesos": return `<td class="num">${pesos(v)}</td>`;
      case "fecha": return `<td>${fecha(v)}</td>`;
      case "estado": return `<td>${chipEstado(v)}</td>`;
      case "bool": return `<td>${v ? '<span class="chip aviso">sí</span>' : '<span class="chip">no</span>'}</td>`;
      case "codigo": return `<td><code>${esc(v)}</code></td>`;
      default: return `<td>${esc(v)}</td>`;
    }
  };
  const cab = columnas.map((c) => `<th class="${num(c.tipo) ? "num" : ""}">${esc(c.titulo)}</th>`).join("");
  const cuerpo = filas.map((f) => {
    const destino = enlace ? enlace(f) : "";
    return `<tr${destino ? ` class="clic" data-ir="${esc(destino)}" tabindex="0"` : ""}>${columnas.map((c) => celda(f, c)).join("")}</tr>`;
  }).join("");
  return `<div class="tabla-marco"><table><thead><tr>${cab}</tr></thead><tbody>${cuerpo}</tbody></table></div>`;
}

// columnas automaticas para los reportes: se deducen del nombre y del valor
function columnasAuto(filas) {
  if (!filas.length) return [];
  return Object.keys(filas[0]).map((clave) => {
    const v = filas.find((f) => f[clave] !== null && f[clave] !== undefined)?.[clave];
    let tipo = "texto";
    if (/centavos$/.test(clave)) tipo = "dinero";
    else if (typeof v === "number" && /^(valor|total|saldo|precio|costo|monto|pagado|subtotal)/.test(clave)) tipo = "pesos";
    else if (typeof v === "number") tipo = "numero";
    else if (typeof v === "boolean") tipo = "bool";
    else if (clave === "estado") tipo = "estado";
    else if (typeof v === "string" && /^\d{4}-\d{2}-\d{2}T/.test(v)) tipo = "fecha";
    return { clave, titulo: clave.replace(/^id_/, "id ").replace(/_/g, " "), tipo };
  });
}

// grafico del inicio: cuadrados redondeados girados, huecos y con brillo
function poligonos() {
  const cuadro = (tam, giro, extra = "") => {
    const p = (400 - tam) / 2;
    return `<rect x="${p}" y="${p}" width="${tam}" height="${tam}" rx="${Math.round(tam / 12)}" transform="rotate(${giro} 200 200)" ${extra}/>`;
  };
  const blancos = [[250, 8], [214, 24], [286, -12], [178, 40]];
  return `<svg viewBox="0 0 400 400" fill="none" aria-hidden="true">
    <defs>
      <linearGradient id="espectro" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0.15" stop-color="#ffb931"/><stop offset="0.3" stop-color="#ffffff"/>
        <stop offset="0.4" stop-color="#ffffff"/><stop offset="0.55" stop-color="#2e73fc"/>
      </linearGradient>
      <filter id="desenfoque" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="7"/></filter>
    </defs>
    <g class="giro" stroke="#fafafa" stroke-width="1.2">
      <g filter="url(#desenfoque)" opacity="0.45">${blancos.map(([t, g]) => cuadro(t, g)).join("")}</g>
      ${blancos.map(([t, g], i) => cuadro(t, g, `opacity="${0.9 - i * 0.18}"`)).join("")}
    </g>
    <g class="giro lento" stroke="url(#espectro)" stroke-width="1.6">
      <g filter="url(#desenfoque)" opacity="0.7">${cuadro(322, 30)}</g>
      ${cuadro(322, 30)}
      ${cuadro(142, -30, 'opacity="0.8"')}
    </g>
  </svg>`;
}

// iconos de linea fina (estilo del DESIGN.md: mono, trazo blanco)
const ICONOS = {
  pedidos: '<path d="M6 6h15l-1.5 9h-12z"/><path d="M6 6 5 3H2"/><circle cx="9" cy="20" r="1.3"/><circle cx="18" cy="20" r="1.3"/>',
  inventario: '<path d="M3 7l9-4 9 4-9 4z"/><path d="M3 7v10l9 4 9-4V7"/><path d="M12 11v10"/>',
  transferencias: '<path d="M4 8h13l-3-3"/><path d="M20 16H7l3 3"/>',
  compras: '<path d="M7 3h10v18l-5-3-5 3z"/><path d="M10 8h4M10 12h4"/>',
  reportes: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  catalogo: '<path d="M3 12 12 3h8v8l-9 9z"/><circle cx="16" cy="8" r="1.4"/>',
  clientes: '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><path d="M16 4.5a3 3 0 0 1 0 6M18 14c2 .7 3 2.8 3 6"/>',
  auditoria: '<path d="M12 3 4 6v6c0 4.5 3.4 8 8 9 4.6-1 8-4.5 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
  servicios: '<path d="M3 12h4l3-7 4 14 3-7h4"/>',
  sede: '<path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>',
  navegador: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><circle cx="6.5" cy="6.5" r=".6"/><circle cx="9" cy="6.5" r=".6"/>',
  gateway: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 3v18M15 12h2"/>',
  base: '<ellipse cx="12" cy="5.5" rx="7.5" ry="2.8"/><path d="M4.5 5.5v13c0 1.5 3.4 2.8 7.5 2.8s7.5-1.3 7.5-2.8v-13"/><path d="M4.5 12c0 1.5 3.4 2.8 7.5 2.8s7.5-1.3 7.5-2.8"/>',
  identidad: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
  ventas: '<path d="M6 6h15l-1.5 9h-12z"/><path d="M6 6 5 3H2"/><circle cx="9" cy="20" r="1.3"/><circle cx="18" cy="20" r="1.3"/>',
  inventarios: '<path d="M3 7l9-4 9 4-9 4z"/><path d="M3 7v10l9 4 9-4V7"/><path d="M12 11v10"/>',
};
const icono = (nombre) => `<span class="icono"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONOS[nombre] || ICONOS.servicios}</svg></span>`;

const marcaSvg = `<svg viewBox="0 0 32 32" fill="none" aria-hidden="true">
  <rect x="8" y="8" width="16" height="16" rx="4" stroke="#fafafa" stroke-width="2" transform="rotate(12 16 16)"/>
  <rect x="10" y="10" width="12" height="12" rx="3" stroke="#ffb931" stroke-width="1.5" transform="rotate(-18 16 16)"/></svg>`;

// ------------------------------------------------------------------
// marco: barra de anuncio + navegacion
// ------------------------------------------------------------------

function pintarAnuncio() {
  const s = estado.salud;
  let puntos = "", texto = "Revisando servicios…";
  if (s) {
    const ok = s.servicios.filter((x) => x.estado === "ok").length;
    puntos = s.servicios.map((x) => `<span class="punto ${x.estado === "ok" ? "ok" : "mal"}" title="${esc(x.servicio)}: ${esc(x.estado)}"></span>`).join("");
    texto = ok === s.servicios.length ? "Los 6 servicios responden" : `${s.servicios.length - ok} de 6 servicios con problemas`;
  } else if (s === undefined) {
    texto = "El gateway no responde";
  }
  const u = estado.usuario;
  const quien = u ? `<span class="tenue">${esc(nombreSede(u.id_sede))} · ${esc(NOMBRE_ROL[u.rol] || u.rol)}</span>` : "";
  document.getElementById("anuncio").innerHTML = `<div class="anuncio">
    <span class="puntos">${puntos}</span><span>${esc(texto)}</span>${quien}
    <a href="#/estado" class="tenue flecha">Ver servicios</a></div>`;
}

function pintarNav(camino) {
  const u = estado.usuario;
  const nav = document.getElementById("nav");
  if (!u) { nav.innerHTML = ""; return; }
  const enlaces = MENU.filter((m) => !m.roles || m.roles.includes(u.rol))
    .map((m) => `<a href="${m.ruta}" class="${camino.startsWith(m.ruta) ? "activo" : ""}">${m.texto}</a>`).join("");
  nav.innerHTML = `<div class="contenedor"><nav class="nav">
    <a class="marca" href="#/inicio">${marcaSvg}Andina</a>
    <div class="enlaces">${enlaces}</div>
    <div class="usuario"><span>${esc(u.nombre_usuario)}</span>
      <button class="boton fantasma chico" id="salir">Salir</button></div>
  </nav></div>`;
  document.getElementById("salir").onclick = async () => {
    try { await api("/api/identidad/logout", { metodo: "POST", sinRedirigir: true }); } catch { /* igual se sale */ }
    estado.usuario = null;
    ir("#/login");
  };
}

async function revisarSalud() {
  try {
    const r = await fetch("/salud", { cache: "no-store" });
    estado.salud = await r.json();
  } catch {
    estado.salud = undefined;
  }
  pintarAnuncio();
  return estado.salud;
}

// ------------------------------------------------------------------
// paginas. cada una devuelve { html, alMontar } (alMontar conecta botones)
// ------------------------------------------------------------------

function paginaLogin() {
  const demo = DEMO.map(([u, r]) =>
    `<button type="button" class="chip" data-usuario="${u}" title="${esc(NOMBRE_ROL[r])}">${u}</button>`).join("");
  return {
    marco: false,
    html: `<section class="login">
      <div>
        <span class="chip brillo">6 microservicios · 4 sedes · 1 gateway</span>
        <h1 class="display margen-titulo">Comercializadora Andina</h1>
        <p class="bajada">Inventarios, pedidos, compras y reportes de las cuatro sedes. Cada sede ve
          lo suyo; la gerencia ve todo junto.</p>
        <div id="login-mensaje"></div>
        <form id="form-login" class="tarjeta" autocomplete="on">
          <div class="campo"><label for="usuario">Usuario</label>
            <input id="usuario" name="usuario" autocomplete="username" required autofocus></div>
          <div class="campo"><label for="password">Contraseña</label>
            <input id="password" name="password" type="password" autocomplete="current-password" required></div>
          <button class="boton principal" type="submit">Entrar</button>
        </form>
        <div class="demo"><span class="etiqueta">Usuarios de prueba (clave: usuario + 2026)</span>
          <div class="demo-usuarios">${demo}</div></div>
      </div>
      <div class="poligonos">${poligonos()}</div>
    </section>`,
    alMontar() {
      document.querySelectorAll("[data-usuario]").forEach((b) => b.onclick = () => {
        document.getElementById("usuario").value = b.dataset.usuario;
        document.getElementById("password").value = b.dataset.usuario + "2026";
        document.getElementById("password").focus();
      });
      const form = document.getElementById("form-login");
      form.onsubmit = async (ev) => {
        ev.preventDefault();
        const boton = form.querySelector("button");
        boton.disabled = true;
        try {
          await api("/api/identidad/login", {
            metodo: "POST", sinRedirigir: true,
            cuerpo: { usuario: form.usuario.value.trim(), password: form.password.value },
          });
          await cargarSesion();
          ir("#/inicio");
        } catch (e) {
          const t = e.codigo === 401 ? mensaje("error", "No se pudo entrar", e.message) : mensajeError(e);
          document.getElementById("login-mensaje").innerHTML = t;
          boton.disabled = false;
        }
      };
    },
  };
}

function paginaInicio() {
  const u = estado.usuario;
  const suf = SUFIJO_SEDE[u.id_sede];
  const tarjetas = [
    { id: "pedidos", ruta: "#/pedidos", roles: [VEN, ADM], titulo: "Pedidos", texto: `Los pedidos de ${esc(nombreSede(u.id_sede))}, leídos solo de <code>ventas.ped_${suf}</code>.${puede(VEN) ? " Desde aquí se crean pedidos nuevos." : ""}` },
    { id: "inventario", ruta: "#/inventario", roles: [INV, ADM], titulo: "Inventario", texto: `Existencias de tu sede en <code>inventarios.inv_${suf}</code>, con alertas de stock mínimo.` },
    { id: "transferencias", ruta: "#/transferencias", roles: [INV, ADM], titulo: "Transferencias", texto: "Traslados de mercancía entre almacenes de las sedes." },
    { id: "compras", ruta: "#/compras", roles: [COM, ADM], titulo: "Compras", texto: "Órdenes de compra a proveedores: lo pedido, lo recibido y lo pendiente." },
    { id: "reportes", ruta: "#/reportes", roles: [GER, AUD, ADM, INV, COM], titulo: "Reportes", texto: "Vistas materializadas que juntan las 6 bases. Se refrescan cada pocos minutos." },
    { id: "catalogo", ruta: "#/catalogo", roles: [ADM, GER, INV, COM, VEN], titulo: "Catálogo", texto: "Los 80 productos, con su categoría y precio de lista." },
    { id: "clientes", ruta: "#/clientes", roles: [ADM, VEN], titulo: "Clientes", texto: "Personas y empresas que compran en las sedes." },
    { id: "auditoria", ruta: "#/auditoria", roles: [AUD, ADM], titulo: "Auditoría", texto: "Quién entró, qué consultó y cuándo." },
    { id: "servicios", ruta: "#/estado", titulo: "Servicios", texto: "Los 6 microservicios en vivo: qué responde y cuánto tarda." },
  ].filter((t) => !t.roles || t.roles.includes(u.rol));

  const fragmentos = [VEN, INV, ADM].includes(u.rol)
    ? `<p>Inventarios y pedidos están partidos por sede: una tabla física por cada una. Tú trabajas sobre
        <code>ventas.ped_${suf}</code> e <code>inventarios.inv_${suf}</code>, y la sede sale de tu sesión,
        no de lo que mande esta página.</p>`
    : `<p>Tu rol trabaja con la información de las cuatro sedes, a través de los reportes corporativos.</p>`;

  return {
    html: `<section class="bienvenida">
        <div>
          <span class="etiqueta">${esc(NOMBRE_ROL[u.rol] || u.rol)}</span>
          <h1>Hola, ${esc(u.nombre_usuario)}</h1>
          ${fragmentos}
          <div class="chips"><span class="chip brillo">${esc(nombreSede(u.id_sede))}</span>
            <span class="chip">${tarjetas.length} módulos</span><span class="chip">sesión de 8 horas</span></div>
        </div>
        <div class="poligonos">${poligonos()}</div>
      </section>
      <div class="mosaico">
      ${tarjetas.map((t) => `<a class="tarjeta brilla" href="${t.ruta}">${icono(t.id)}<h3>${t.titulo}</h3><p>${t.texto}</p>
        <span class="flecha naranja">Abrir</span></a>`).join("")}</div>`,
  };
}

// ---------------- pedidos ----------------

async function paginaPedidos(_, params) {
  const est = params.get("estado") || "";
  let ruta = conSede("/api/ventas/pedidos", params);
  if (est) ruta += (ruta.includes("?") ? "&" : "?") + "estado=" + encodeURIComponent(est);
  const d = await api(ruta);
  const filtro = `<select id="filtro-estado" aria-label="Estado">${opcionesSelect(["PENDIENTE", "CONFIRMADO", "ENTREGADO", "ANULADO"], est)}</select>`;
  const nuevo = puede(VEN) ? `<a class="boton principal" href="#/pedidos/nuevo">Nuevo pedido</a>` : "";
  const sede = params.get("sede") ? `?sede=${encodeURIComponent(params.get("sede"))}` : "";
  return {
    html: cabecera("Pedidos",
      `Los últimos 100 pedidos de ${esc(nombreSede(d.sede))}, leídos solo del fragmento <code>${esc(d.fragmento)}</code>.`,
      selectorSede(params) + filtro + nuevo) +
      aviso(d) +
      tabla(d.pedidos, [
        { clave: "id_pedido", titulo: "#", tipo: "numero" },
        { clave: "fecha_pedido", titulo: "Fecha", tipo: "fecha" },
        { clave: "cliente", titulo: "Cliente" },
        { clave: "estado", titulo: "Estado", tipo: "estado" },
        { clave: "total_centavos", titulo: "Total", tipo: "dinero" },
      ], { enlace: (p) => `#/pedidos/${p.id_pedido}${sede}`, vacio: "No hay pedidos con ese filtro." }) +
      `<div class="pie-tabla"><span>${numero(d.filas)} pedidos</span><span>Haz clic en uno para ver su detalle</span></div>`,
    alMontar() {
      document.getElementById("filtro-estado").onchange = (e) => cambiarParam("estado", e.target.value);
    },
  };
}

async function paginaPedido([, id], params) {
  const d = await api(conSede(`/api/ventas/pedidos/${id}`, params));
  const p = d.pedido;
  return {
    html: cabecera(`Pedido ${p.id_pedido}`, `De <code>${esc(d.fragmento)}</code>, con su detalle de <code>${esc(d.fragmento.replace("ped_", "det_ped_"))}</code>.`,
      `<a class="boton fantasma" href="#/pedidos${params.get("sede") ? "?sede=" + encodeURIComponent(params.get("sede")) : ""}">Volver</a>`) +
      aviso(d) +
      `<div class="dos-columnas">
        ${tabla(d.lineas, [
          { clave: "producto", titulo: "Producto" },
          { clave: "cantidad", titulo: "Cantidad", tipo: "numero" },
          { clave: "precio_unitario_centavos", titulo: "Precio", tipo: "dinero" },
          { clave: "subtotal_centavos", titulo: "Subtotal", tipo: "dinero" },
        ])}
        <div class="tarjeta"><span class="etiqueta">Pedido</span>
          <dl class="lista-datos">
            <dt>Sede</dt><dd>${esc(nombreSede(p.id_sede))}</dd>
            <dt>Fecha</dt><dd>${fecha(p.fecha_pedido)}</dd>
            <dt>Estado</dt><dd>${chipEstado(p.estado)}</dd>
            <dt>Cliente</dt><dd>${esc(p.id_cliente)}</dd>
            <dt>Vendedor</dt><dd>empleado ${esc(p.id_empleado)}</dd>
            <dt>Almacén</dt><dd>${esc(p.id_almacen)}</dd>
          </dl>
          <div class="total"><span class="etiqueta">Total</span><span class="dato">${dinero(p.total_centavos)}</span></div>
        </div>
      </div>`,
  };
}

async function paginaNuevoPedido() {
  // productos y clientes vienen de catalogo. si catalogo no responde, no se
  // puede vender (no hay precios), y el servidor tampoco dejaria crear el pedido
  const [productos, clientes] = await Promise.all([api("/api/catalogo/productos"), api("/api/catalogo/clientes")]);
  const u = estado.usuario;
  clientes.sort((a, b) => a.nombre_completo.localeCompare(b.nombre_completo, "es"));
  const opcCliente = clientes.map((c) =>
    `<option value="${c.id_cliente}" ${c.estado !== "ACTIVO" ? "data-inactivo" : ""}>${esc(c.nombre_completo)} · ${esc(c.tipo_documento)} ${esc(c.num_documento)}${c.estado !== "ACTIVO" ? " (inactivo)" : ""}</option>`).join("");
  // los descontinuados se dejan en la lista a proposito: asi se puede ver
  // que el servidor los rechaza (la regla esta en ventas, no en esta pagina)
  const opcProducto = `<option value="">Elige un producto</option>` + productos.map((p) =>
    `<option value="${p.id_producto}">${esc(p.nombre)} · ${dinero(p.precio_centavos)}${p.estado !== "ACTIVO" ? ` (${p.estado.toLowerCase()})` : ""}</option>`).join("");
  const precio = Object.fromEntries(productos.map((p) => [p.id_producto, p.precio_centavos]));

  return {
    html: cabecera("Nuevo pedido",
      `Se guarda en <code>ventas.ped_${SUFIJO_SEDE[u.id_sede]}</code> (${esc(nombreSede(u.id_sede))}). Ventas le pregunta a catálogo
       si el cliente y los productos existen y cuál es el precio de hoy: el precio nunca sale de esta página.`,
      `<a class="boton fantasma" href="#/pedidos">Volver</a>`) +
      `<div id="resultado"></div>
      <div class="dos-columnas">
        <form id="form-pedido" class="tarjeta">
          <div class="campo"><label for="cliente">Cliente</label><select id="cliente" required>${opcCliente}</select></div>
          <label>Productos</label>
          <div id="lineas"></div>
          <button type="button" class="boton secundario chico" id="agregar">+ Agregar producto</button>
        </form>
        <div class="tarjeta"><span class="etiqueta">Resumen</span>
          <dl class="lista-datos" id="resumen"></dl>
          <div class="total"><span class="etiqueta">Total estimado</span><span class="dato" id="total">$0</span></div>
          <p class="pie-tabla">El total final lo calcula el servidor con los precios de catálogo.</p>
          <button class="boton principal" id="crear" type="button">Crear pedido</button>
        </div>
      </div>`,
    alMontar() {
      const lineas = document.getElementById("lineas");
      const agregarLinea = () => {
        const fila = document.createElement("div");
        fila.className = "fila-campos";
        fila.innerHTML = `<select class="producto" aria-label="Producto">${opcProducto}</select>
          <input class="cantidad" type="number" min="1" max="10000" value="1" aria-label="Cantidad">
          <button type="button" class="icono-boton quitar" aria-label="Quitar">×</button>`;
        fila.querySelector(".quitar").onclick = () => { fila.remove(); recalcular(); };
        fila.querySelectorAll("select, input").forEach((x) => x.oninput = recalcular);
        lineas.appendChild(fila);
      };
      const leer = () => [...lineas.querySelectorAll(".fila-campos")]
        .map((f) => ({ id_producto: Number(f.querySelector(".producto").value), cantidad: Number(f.querySelector(".cantidad").value) }))
        .filter((l) => l.id_producto);
      const recalcular = () => {
        const ls = leer();
        const total = ls.reduce((s, l) => s + (precio[l.id_producto] || 0) * (l.cantidad || 0), 0);
        document.getElementById("total").textContent = dinero(total);
        document.getElementById("resumen").innerHTML =
          `<dt>Productos</dt><dd>${ls.length}</dd><dt>Unidades</dt><dd>${numero(ls.reduce((s, l) => s + (l.cantidad || 0), 0))}</dd>`;
      };
      document.getElementById("agregar").onclick = agregarLinea;
      agregarLinea();
      recalcular();

      document.getElementById("crear").onclick = async (ev) => {
        const boton = ev.currentTarget;
        const res = document.getElementById("resultado");
        const cuerpo = { id_cliente: Number(document.getElementById("cliente").value), productos: leer() };
        boton.disabled = true;
        try {
          const r = await api("/api/ventas/pedidos", { metodo: "POST", cuerpo });
          res.innerHTML = `<div class="mensaje ok"><strong>Pedido ${esc(r.pedido.id_pedido)} creado en ${esc(r.fragmento)}</strong>
            <span class="tenue">Total ${dinero(r.pedido.total_centavos)}. En los reportes aparece en el siguiente refresco
            (consistencia eventual).</span> <a class="flecha" href="#/pedidos/${esc(r.pedido.id_pedido)}">Ver el pedido</a></div>`;
          lineas.innerHTML = "";
          agregarLinea();
          recalcular();
        } catch (e) {
          res.innerHTML = mensajeError(e);
        }
        boton.disabled = false;
        window.scrollTo({ top: 0, behavior: "smooth" });
      };
    },
  };
}

// ---------------- inventario ----------------

async function paginaInventario(_, params) {
  const bajos = params.get("bajos") === "true";
  let ruta = conSede("/api/inventarios/mi-sede", params);
  if (bajos) ruta += (ruta.includes("?") ? "&" : "?") + "bajos=true";
  const d = await api(ruta);
  const items = d.existencias;
  const bajoMin = items.filter((i) => i.bajo_minimo).length;
  const unidades = items.reduce((s, i) => s + i.existencia_actual, 0);
  return {
    html: cabecera("Inventario",
      `Existencias de ${esc(nombreSede(d.sede))}, leídas solo del fragmento <code>${esc(d.fragmento)}</code>.`,
      selectorSede(params) +
      `<label class="check"><input type="checkbox" id="bajos" ${bajos ? "checked" : ""}> Solo bajo el mínimo</label>
       <input id="buscar" type="search" placeholder="Buscar producto" aria-label="Buscar producto">`) +
      aviso(d) +
      `<div class="mosaico">
        <div class="tarjeta"><span class="etiqueta">Productos</span><span class="dato">${numero(items.length)}</span></div>
        <div class="tarjeta"><span class="etiqueta">Bajo el mínimo</span><span class="dato">${numero(bajoMin)}</span></div>
        <div class="tarjeta"><span class="etiqueta">Unidades</span><span class="dato">${numero(unidades)}</span></div>
      </div><br>
      <div id="tabla-inv"></div>`,
    alMontar() {
      document.getElementById("bajos").onchange = (e) => cambiarParam("bajos", e.target.checked ? "true" : "");
      const pintar = (texto) => {
        const t = texto.toLowerCase();
        const filas = items.filter((i) => String(i.producto ?? i.id_producto).toLowerCase().includes(t));
        document.getElementById("tabla-inv").innerHTML = tabla(filas, [
          { clave: "id_producto", titulo: "id", tipo: "numero" },
          { clave: "producto", titulo: "Producto" },
          { clave: "existencia_actual", titulo: "Existencia", tipo: "numero" },
          { clave: "stock_minimo", titulo: "Mínimo", tipo: "numero" },
          { clave: "bajo_minimo", titulo: "Bajo el mínimo", tipo: "bool" },
          { clave: "fecha_actualizacion", titulo: "Actualizado", tipo: "fecha" },
        ], { vacio: "Ningún producto coincide." });
      };
      document.getElementById("buscar").oninput = (e) => pintar(e.target.value);
      pintar("");
    },
  };
}

async function paginaTransferencias(_, params) {
  const est = params.get("estado") || "";
  const d = await api("/api/inventarios/transferencias" + (est ? "?estado=" + encodeURIComponent(est) : ""));
  return {
    html: cabecera("Transferencias", "Traslados de mercancía entre los almacenes de las sedes.",
      `<select id="filtro-estado" aria-label="Estado">${opcionesSelect(["SOLICITADA", "DESPACHADA", "RECIBIDA", "CANCELADA"], est, "Todas")}</select>`) +
      aviso(d) +
      tabla(d.transferencias, [
        { clave: "id_transferencia", titulo: "#", tipo: "numero" },
        { clave: "almacen_origen", titulo: "Origen" },
        { clave: "almacen_destino", titulo: "Destino" },
        { clave: "estado", titulo: "Estado", tipo: "estado" },
        { clave: "fecha_solicitud", titulo: "Solicitada", tipo: "fecha" },
        { clave: "fecha_despacho", titulo: "Despachada", tipo: "fecha" },
        { clave: "fecha_recepcion", titulo: "Recibida", tipo: "fecha" },
        { clave: "productos", titulo: "Productos", tipo: "numero" },
        { clave: "unidades_enviadas", titulo: "Unidades", tipo: "numero" },
      ], { vacio: "No hay transferencias con ese filtro." }) +
      `<div class="pie-tabla"><span>${numero(d.filas)} transferencias</span></div>`,
    alMontar() {
      document.getElementById("filtro-estado").onchange = (e) => cambiarParam("estado", e.target.value);
    },
  };
}

// ---------------- compras ----------------

async function paginaCompras(_, params) {
  const est = params.get("estado") || "";
  const d = await api("/api/compras/ordenes" + (est ? "?estado=" + encodeURIComponent(est) : ""));
  return {
    html: cabecera("Órdenes de compra", "Lo que se le pidió a cada proveedor, y cuánto ha llegado.",
      `<select id="filtro-estado" aria-label="Estado">${opcionesSelect(["EMITIDA", "PARCIAL", "RECIBIDA", "CANCELADA"], est, "Todas")}</select>`) +
      aviso(d) +
      tabla(d.ordenes, [
        { clave: "id_orden_compra", titulo: "#", tipo: "numero" },
        { clave: "fecha_orden", titulo: "Fecha", tipo: "fecha" },
        { clave: "proveedor", titulo: "Proveedor" },
        { clave: "estado", titulo: "Estado", tipo: "estado" },
        { clave: "fecha_estimada", titulo: "Llega", tipo: "fecha" },
        { clave: "productos", titulo: "Productos", tipo: "numero" },
        { clave: "total_centavos", titulo: "Total", tipo: "dinero" },
      ], { enlace: (o) => `#/compras/${o.id_orden_compra}`, vacio: "No hay órdenes con ese filtro." }) +
      `<div class="pie-tabla"><span>${numero(d.filas)} órdenes</span><span>Haz clic en una para ver su detalle</span></div>`,
    alMontar() {
      document.getElementById("filtro-estado").onchange = (e) => cambiarParam("estado", e.target.value);
    },
  };
}

async function paginaOrden([, id]) {
  const d = await api(`/api/compras/ordenes/${id}`);
  const o = d.orden;
  return {
    html: cabecera(`Orden de compra ${o.id_orden_compra}`, esc(o.proveedor || `Proveedor ${o.id_proveedor}`),
      `<a class="boton fantasma" href="#/compras">Volver</a>`) +
      aviso(d) +
      `<div class="dos-columnas">
        ${tabla(d.lineas, [
          { clave: "producto", titulo: "Producto" },
          { clave: "cantidad_solicitada", titulo: "Pedido", tipo: "numero" },
          { clave: "cantidad_recibida", titulo: "Recibido", tipo: "numero" },
          { clave: "cantidad_pendiente", titulo: "Falta", tipo: "numero" },
          { clave: "costo_unitario_centavos", titulo: "Costo", tipo: "dinero" },
        ])}
        <div class="tarjeta"><span class="etiqueta">Orden</span>
          <dl class="lista-datos">
            <dt>Estado</dt><dd>${chipEstado(o.estado)}</dd>
            <dt>Fecha</dt><dd>${fecha(o.fecha_orden)}</dd>
            <dt>Llega</dt><dd>${fecha(o.fecha_estimada)}</dd>
            <dt>Almacén destino</dt><dd>${esc(o.id_almacen_destino)}</dd>
          </dl>
          <div class="total"><span class="etiqueta">Total</span><span class="dato">${dinero(o.total_centavos)}</span></div>
        </div>
      </div>`,
  };
}

// ---------------- reportes ----------------

async function paginaReportes([, vista], params) {
  const lista = await api("/api/reportes");
  const vistas = lista.vistas;
  if (!vistas.length) return { html: cabecera("Reportes") + mensaje("aviso", "Tu rol no tiene reportes") };
  const actual = vistas.find((v) => v.nombre === vista) || vistas[0];

  // inventario solo ve su sede (lo fuerza el servidor); los demas pueden filtrar
  const sede = params.get("sede") || "";
  const puedeFiltrar = actual.por_sede && !puede(INV);
  let ruta = `/api/reportes/${encodeURIComponent(actual.nombre)}`;
  if (puedeFiltrar && sede) ruta += `?sede=${encodeURIComponent(sede)}`;
  const d = await api(ruta);

  const menu = vistas.map((v) => `<a href="#/reportes/${esc(v.nombre)}${sede && v.por_sede ? "?sede=" + encodeURIComponent(sede) : ""}"
      class="${v.nombre === actual.nombre ? "activo" : ""}">${esc(v.nombre.replace(/^vista_/, "").replace(/_/g, " "))}<span>${esc(v.descripcion)}</span></a>`).join("");
  const filtro = puedeFiltrar
    ? `<select id="sede-reporte" aria-label="Sede"><option value="">Todas las sedes</option>${[1, 2, 3, 4].map((id) =>
        `<option value="${id}" ${String(id) === sede ? "selected" : ""}>${esc(nombreSede(id))}</option>`).join("")}</select>` : "";
  const refrescar = puede(ADM) ? `<button class="boton secundario" id="refrescar">Refrescar ahora</button>` : "";

  return {
    html: cabecera("Reportes", `Vistas materializadas en la base de reportes: traen los datos de las otras 5 bases con
        <code>dblink</code> y se refrescan cada pocos minutos.`) +
      `<div id="msg-refresco"></div>
      <div class="reportes">
        <div class="tarjeta vistas">${menu}</div>
        <div>
          <div class="cabecera"><div><h3>${esc(actual.nombre)}</h3><p>${esc(actual.descripcion)}</p></div>
            <div class="acciones">${filtro}${refrescar}</div></div>
          ${tabla(d.datos, columnasAuto(d.datos), { vacio: "Esta vista no tiene filas." })}
          <div class="pie-tabla"><span>${numero(d.filas)} filas${d.sede ? ` · ${esc(nombreSede(d.sede))}` : ""}</span>
            <span>Datos al ${d.datos_al ? fecha(d.datos_al) : "—"} · pueden ir unos minutos atrás (consistencia eventual)</span></div>
        </div>
      </div>`,
    alMontar() {
      const s = document.getElementById("sede-reporte");
      if (s) s.onchange = (e) => cambiarParam("sede", e.target.value);
      const r = document.getElementById("refrescar");
      if (r) r.onclick = async () => {
        r.disabled = true;
        r.textContent = "Refrescando…";
        const msg = document.getElementById("msg-refresco");
        try {
          const res = await api("/api/reportes/refrescar", { metodo: "POST" });
          msg.innerHTML = mensaje("ok", "Reportes al día", `Las 13 vistas se refrescaron en ${numero(res.duracion_ms / 1000)} s.`);
          setTimeout(navegar, 900);
        } catch (e) {
          msg.innerHTML = mensajeError(e);
          r.disabled = false;
          r.textContent = "Refrescar ahora";
        }
      };
    },
  };
}

// ---------------- catalogo, clientes, auditoria ----------------

async function paginaCatalogo() {
  const productos = await api("/api/catalogo/productos");
  const categorias = [...new Set(productos.map((p) => p.categoria))].sort();
  return {
    html: cabecera("Catálogo", "Datos maestros del servicio de catálogo: productos, categorías y precio de lista.",
      `<select id="categoria" aria-label="Categoría"><option value="">Todas las categorías</option>${categorias.map((c) => `<option>${esc(c)}</option>`).join("")}</select>
       <input id="buscar" type="search" placeholder="Buscar por nombre o SKU" aria-label="Buscar">`) +
      `<div id="tabla-cat"></div>`,
    alMontar() {
      const pintar = () => {
        const t = document.getElementById("buscar").value.toLowerCase();
        const c = document.getElementById("categoria").value;
        const filas = productos.filter((p) => (!c || p.categoria === c) &&
          (p.nombre.toLowerCase().includes(t) || p.sku.toLowerCase().includes(t)));
        document.getElementById("tabla-cat").innerHTML = tabla(filas, [
          { clave: "sku", titulo: "SKU", tipo: "codigo" },
          { clave: "nombre", titulo: "Producto" },
          { clave: "categoria", titulo: "Categoría" },
          { clave: "unidad_medida", titulo: "Unidad" },
          { clave: "precio_centavos", titulo: "Precio", tipo: "dinero" },
          { clave: "estado", titulo: "Estado", tipo: "estado" },
        ], { vacio: "Ningún producto coincide." }) +
          `<div class="pie-tabla"><span>${numero(filas.length)} de ${numero(productos.length)} productos</span></div>`;
      };
      document.getElementById("buscar").oninput = pintar;
      document.getElementById("categoria").onchange = pintar;
      pintar();
    },
  };
}

async function paginaClientes() {
  const clientes = await api("/api/catalogo/clientes");
  return {
    html: cabecera("Clientes", "Personas y empresas registradas en catálogo.",
      `<input id="buscar" type="search" placeholder="Buscar por nombre o documento" aria-label="Buscar">`) +
      `<div id="tabla-cli"></div>`,
    alMontar() {
      const pintar = (texto) => {
        const t = texto.toLowerCase();
        const filas = clientes.filter((c) => c.nombre_completo.toLowerCase().includes(t) || c.num_documento.includes(t));
        document.getElementById("tabla-cli").innerHTML = tabla(filas, [
          { clave: "id_cliente", titulo: "id", tipo: "numero" },
          { clave: "nombre_completo", titulo: "Nombre" },
          { clave: "tipo_documento", titulo: "Doc." },
          { clave: "num_documento", titulo: "Número" },
          { clave: "correo", titulo: "Correo" },
          { clave: "estado", titulo: "Estado", tipo: "estado" },
        ], { vacio: "Ningún cliente coincide." }) +
          `<div class="pie-tabla"><span>${numero(filas.length)} de ${numero(clientes.length)} clientes</span></div>`;
      };
      document.getElementById("buscar").oninput = (e) => pintar(e.target.value);
      pintar("");
    },
  };
}

async function paginaAuditoria() {
  const accesos = await api("/api/identidad/auditoria?limite=200");
  return {
    html: cabecera("Auditoría", "Los últimos 200 accesos. Cada servicio le avisa a identidad cuando alguien consulta o crea algo.") +
      tabla(accesos, [
        { clave: "fecha_hora", titulo: "Cuándo", tipo: "fecha" },
        { clave: "nombre_usuario", titulo: "Usuario" },
        { clave: "rol", titulo: "Rol" },
        { clave: "accion", titulo: "Acción", tipo: "codigo" },
        { clave: "objeto_consultado", titulo: "Qué", tipo: "codigo" },
      ], { vacio: "Todavía no hay accesos." }),
  };
}

// ---------------- estado de los servicios ----------------

const QUE_PASA = {
  catalogo: "No se pueden crear pedidos (no hay precios). Inventario, compras y pedidos siguen, con ids en vez de nombres.",
  identidad: "Nadie puede iniciar sesión ni usar el sistema: el gateway no puede validar la sesión.",
  compras: "Solo se cae la página de compras. Lo demás sigue igual.",
  inventarios: "Solo se caen inventario y transferencias. Lo demás sigue igual.",
  ventas: "No se ven ni se crean pedidos. Lo demás sigue igual.",
  reportes: "No hay reportes. Los servicios del día a día siguen igual.",
};
const PUERTO = { catalogo: 8101, identidad: 8102, compras: 8103, inventarios: 8104, ventas: 8105, reportes: 8106 };

// cuanto tardo /salud desde el navegador (navegador -> gateway -> 6 servicios)
let msGateway = null;

function pintarServicios() {
  const cont = document.getElementById("diagrama");
  if (!cont) return;
  const s = estado.salud;
  const gatewayOk = !!s;
  const servicios = s ? s.servicios : Object.keys(PUERTO).map((x) => ({ servicio: x, estado: "sin respuesta", ms: 0 }));
  const bien = servicios.filter((x) => x.estado === "ok").length;

  const rama = (x) => {
    const ok = x.estado === "ok";
    const sinBase = x.estado === "sin base de datos";
    const caido = !ok && !sinBase;
    return `<div class="rama">
      <div class="cable ${gatewayOk ? (caido ? "mal" : "ok") : "mal"}"></div>
      <div class="nodo ${ok ? "" : "mal"}">
        <div class="fila">${icono(x.servicio)}
          <div><div class="nombre">${esc(x.servicio)}</div><div class="detalle">:${PUERTO[x.servicio] || ""}</div></div>
          <span class="punto ${ok ? "ok" : "mal"} derecha"></span></div>
        <div class="barra-ms"><span data-ms="${ok ? x.ms : 0}"></span></div>
        <div class="ms">${ok ? `${numero(x.ms)} ms` : esc(x.estado)}</div>
      </div>
      <div class="cable ${ok ? "ok" : caido ? "" : "mal"}"></div>
      <div class="nodo base ${sinBase ? "mal" : caido ? "apagado" : ""}">
        ${icono("base")}<div class="nombre">andina_${esc(x.servicio)}</div>
      </div>
    </div>`;
  };

  cont.innerHTML = `
    <div class="centro">
      <div class="nodo">${icono("navegador")}<div><div class="nombre">Tu navegador</div>
        <div class="detalle">${esc(location.host)}</div></div></div>
      <div class="cable ${gatewayOk ? "ok" : "mal"}"></div>
      <div class="nodo gateway ${gatewayOk ? "" : "mal"}">${icono("gateway")}
        <div><div class="nombre">Gateway</div><div class="detalle">valida la sesión y reparte /api/&lt;servicio&gt;</div></div>
        <div class="derecha"><span class="punto ${gatewayOk ? "ok" : "mal"}"></span>
          <div class="detalle">${gatewayOk && msGateway !== null ? `${numero(msGateway)} ms` : gatewayOk ? "" : "no responde"}</div></div>
      </div>
      <div class="cable ${gatewayOk ? "ok" : "mal"}"></div>
    </div>
    <div class="bus"></div>
    <div class="ramas">${servicios.map(rama).join("")}</div>`;

  // el ancho de las barras se pone por js: la CSP no deja style="" en el html
  const max = Math.max(1, ...servicios.map((x) => x.ms || 0));
  cont.querySelectorAll(".barra-ms span").forEach((b) => { b.style.width = `${Math.max(4, (Number(b.dataset.ms) / max) * 100)}%`; });

  document.getElementById("resumen-salud").innerHTML = gatewayOk
    ? `<span class="chip ${bien === 6 ? "ok" : "mal"}">${bien} de 6 servicios ok</span>
       <span class="chip">${numero(msGateway ?? 0)} ms la vuelta completa</span>
       <span class="chip">${s.servicios.length} bases, una por servicio</span>`
    : `<span class="chip mal">el gateway no responde</span>`;
  const hora = document.getElementById("hora-salud");
  if (hora) hora.textContent = new Date().toLocaleTimeString("es-CO");
}

function paginaEstado() {
  const tarjetas = Object.entries(QUE_PASA).map(([nombre, texto]) =>
    `<div class="tarjeta"><h3>${icono(nombre)}Si se cae ${esc(nombre)}</h3><p>${esc(texto)}</p></div>`).join("");
  return {
    html: cabecera("Servicios",
      `El gateway le pregunta a los 6 servicios a la vez (<code>GET /salud</code>), y cada uno le hace un ping
       a su propia base. Se actualiza cada 3 segundos: apaga uno y mira qué pasa.`) +
      `<div class="estado-resumen" id="resumen-salud"></div>
      <section class="diagrama" id="diagrama"><p class="cargando">Preguntando</p></section>
      <div class="leyenda">
        <span><span class="punto ok"></span>ok</span>
        <span><span class="punto mal"></span>sin base de datos: el servicio corre pero no llega a su base</span>
        <span><span class="punto mal"></span>caido: el servicio no responde</span>
        <span>Última revisión: <span id="hora-salud">—</span></span>
      </div>
      <br><div class="cabecera"><div><h1>¿Y si se cae uno?</h1>
        <p>Cada servicio es un programa aparte con su propia base: si uno se cae, los demás siguen.</p></div></div>
      <div class="que-pasa">${tarjetas}</div>`,
    alMontar() {
      const tic = async () => {
        const t0 = performance.now();
        await revisarSalud();
        msGateway = Math.round(performance.now() - t0);
        pintarServicios();
      };
      tic();
      estado.reloj = setInterval(tic, 3000);
    },
  };
}

const PIE = `<footer class="pie"><div class="contenedor">
  <span class="marca">${marcaSvg}Comercializadora Andina</span>
  <span>gateway + 6 microservicios en Go · una base PostgreSQL por servicio</span></div></footer>`;

// ------------------------------------------------------------------
// rutas y navegacion
// ------------------------------------------------------------------

const RUTAS = [
  [/^#\/login$/, paginaLogin, true],
  [/^#\/estado$/, paginaEstado, true],
  [/^#\/inicio$/, paginaInicio],
  [/^#\/pedidos$/, paginaPedidos],
  [/^#\/pedidos\/nuevo$/, paginaNuevoPedido],
  [/^#\/pedidos\/(\d+)$/, paginaPedido],
  [/^#\/inventario$/, paginaInventario],
  [/^#\/transferencias$/, paginaTransferencias],
  [/^#\/compras$/, paginaCompras],
  [/^#\/compras\/(\d+)$/, paginaOrden],
  [/^#\/reportes(?:\/(\w+))?$/, paginaReportes],
  [/^#\/catalogo$/, paginaCatalogo],
  [/^#\/clientes$/, paginaClientes],
  [/^#\/auditoria$/, paginaAuditoria],
];

// quien soy y las sedes se piden A LA VEZ (no una despues de la otra): con
// el servidor lejos, cada peticion son varios cientos de ms
async function cargarSesion() {
  if (!estado.sedes.length) {
    try { estado.sedes = JSON.parse(sessionStorage.getItem("sedes")) || []; } catch { /* sin storage */ }
  }
  const [yo, sedes] = await Promise.all([
    api("/api/identidad/yo", { sinRedirigir: true }),
    estado.sedes.length ? estado.sedes
      : api("/api/catalogo/sedes", { sinRedirigir: true }).catch(() => []), // sin catalogo: "Sede N"
  ]);
  estado.usuario = yo;
  if (sedes.length && !estado.sedes.length) {
    estado.sedes = sedes;
    try { sessionStorage.setItem("sedes", JSON.stringify(sedes)); } catch { /* modo privado */ }
  }
}

async function navegar() {
  const turno = ++estado.turno;
  clearInterval(estado.reloj);
  estado.reloj = null;
  const app = document.getElementById("app");
  const { camino, params } = leerHash();
  let encontrada = null, partes = null;
  for (const [patron, pagina, publica] of RUTAS) {
    const m = camino.match(patron);
    if (m) { encontrada = { pagina, publica }; partes = m; break; }
  }
  if (!encontrada) { location.hash = "#/inicio"; return; }

  // sin sesion conocida: preguntar a identidad si la cookie sirve
  if (!estado.usuario && !encontrada.publica) {
    try {
      await cargarSesion();
    } catch (e) {
      if (turno !== estado.turno) return;
      if (e.codigo !== 401) sessionStorageSeguro("error-inicio", e.message);
      location.hash = "#/login";
      return;
    }
  }
  if (estado.usuario && camino === "#/login") { location.hash = "#/inicio"; return; }

  pintarNav(camino);
  pintarAnuncio();
  app.innerHTML = `<main class="contenedor"><p class="cargando">Cargando</p></main>`;
  let pagina;
  try {
    pagina = await encontrada.pagina(partes, params);
  } catch (e) {
    pagina = { html: mensajeError(e) };
  }
  if (turno !== estado.turno) return; // el usuario ya se fue a otra pagina
  app.innerHTML = pagina.marco === false ? pagina.html : `<main class="contenedor">${pagina.html}</main>${PIE}`;
  if (camino === "#/login") {
    const e = leerSeguro("error-inicio");
    if (e) document.getElementById("login-mensaje").innerHTML = mensaje("aviso", "No se pudo revisar la sesión", e);
  }
  pagina.alMontar?.();
  const sede = document.getElementById("sede");
  if (sede) sede.onchange = (ev) => cambiarParam("sede", ev.target.value);
  window.scrollTo(0, 0);
}

// el mensaje de "identidad no responde" sobrevive al salto a #/login
function sessionStorageSeguro(k, v) { try { sessionStorage.setItem(k, v); } catch { /* modo privado */ } }
function leerSeguro(k) {
  try { const v = sessionStorage.getItem(k); sessionStorage.removeItem(k); return v; } catch { return null; }
}

// filas con clic (tablas de pedidos y ordenes): un solo manejador para todas
document.addEventListener("click", (ev) => {
  const fila = ev.target.closest("tr[data-ir]");
  if (fila) ir(fila.dataset.ir);
});
document.addEventListener("keydown", (ev) => {
  const fila = ev.target.closest?.("tr[data-ir]");
  if (fila && ev.key === "Enter") ir(fila.dataset.ir);
});

window.addEventListener("hashchange", navegar);
revisarSalud();
setInterval(() => { if (!document.hidden && !estado.reloj) revisarSalud(); }, 20000);
navegar();
