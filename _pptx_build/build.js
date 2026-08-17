const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const Fa = require("react-icons/fa");

// ---------- palette ----------
const ORANGE = "E2711D";      // basketball orange (main)
const ORANGE_LT = "F4A259";
const DARK = "17171A";        // near-black for dark slides
const DARKCARD = "26262B";
const LIGHT = "FFFFFF";
const SOFT = "F6F2EC";        // soft warm-neutral card on light slides
const INK = "1F1F23";
const MUTED = "6E6E73";
const LINE = "E7E2DA";

const HF = "Arial Black";     // headers
const TF = "Trebuchet MS";    // kickers / labels
const BF = "Calibri";         // body

// ---------- icon cache ----------
const iconCache = {};
async function icon(Comp, color = "FFFFFF", size = 256) {
  const key = Comp.name + color;
  if (iconCache[key]) return iconCache[key];
  const svg = ReactDOMServer.renderToStaticMarkup(
    React.createElement(Comp, { color: "#" + color, size: String(size) })
  );
  const png = await sharp(Buffer.from(svg)).png().toBuffer();
  const d = "image/png;base64," + png.toString("base64");
  iconCache[key] = d;
  return d;
}

let pres;
let WITH_NOTES = false;
let _noteIdx = 0;
const MEMREF = [
  "resumen y estructura general del documento (apartado 1.4).",
  "el documento sigue esta misma estructura por capítulos (apartado 1.4, «Estructura del documento»).",
  "capítulo 1.1 «Contexto y motivación»; la planificación temporal está en el apartado 1.5 y la figura 1.1 (diagrama de Gantt).",
  "capítulo 1.2 «Objetivos» y 1.3 «Alcance».",
  "apartado 1.5 «Planificación del proyecto» (figura 1.1, diagrama de Gantt) y 5.2 «Metodología y entorno de desarrollo».",
  "capítulo 2 «Estado del Arte»: aplicaciones de gestión deportiva (2.1–2.2, tabla 2.1), frameworks (2.3, tabla 2.2) y servicios backend (2.4).",
  "apartado 2.6 «Justificación de la solución propuesta», apoyado en las comparativas del capítulo 2 (tablas 2.1 y 2.2).",
  "capítulo 4: Clean Architecture (apartado 4.1, figura 4.1 y tabla 4.1), Riverpod (4.2, figura 4.2) y GoRouter (4.3, figura 4.3); el stack en la tabla 5.1 y el despliegue en la figura 4.5.",
  "apartado 4.5 «Modelo de datos» (figura 4.4 y tabla 4.2), 4.6 «Diseño de seguridad y roles» y el detalle de tablas en el Anexo A (tabla A.1).",
  "capítulo 5 «Implementación» en conjunto, y los casos de uso del apartado 3.4 (figura 3.1).",
  "apartados 5.4 «Gestión de equipos» y 5.5 «Generación automática» (caso de uso CU-01; figuras 5.5 a 5.7).",
  "apartados 5.6 «Competiciones por estaciones» (figuras 5.8–5.11), 5.7 «Competiciones de siesta» (figuras 5.12–5.15) y 5.8 «Veladas» (figuras 5.16–5.17).",
  "apartado 5.11 (caso de uso CU-02; figuras 5.21 y 5.22) y el requisito RF-13; la latencia se verifica en el capítulo 6.",
  "rankings y estadísticas (5.11, figuras 5.23–5.24), dashboard (5.13, figura 5.25) y exportaciones (5.15: PDF en 5.15.1 / figura 5.26, Excel en 5.15.2 / figura 5.27; caso de uso CU-03).",
  "las capturas de todas las pantallas están en el capítulo 5 (figuras 5.1–5.27); el despliegue, en el apartado 5.16 y el Anexo B.",
  "capítulo 6 «Pruebas»: estrategia (6.2), casos de prueba (tabla 6.1) y pruebas beta con entrenadores (6.5).",
  "capítulo 7 «Resultados»: estado de los módulos (tabla 7.1) y cumplimiento de objetivos (tabla 7.2); el RNF-02 se verifica en 6.4.",
  "capítulo 8: conclusiones (8.1) y líneas futuras (8.2).",
];
const NOTES = [
 "Buenos días. Soy Alberto Rodríguez González y presento mi Trabajo de Fin de Grado, tutorizado por José Ramón Sánchez Couso: Campus Baloncesto App, una aplicación multiplataforma y PWA para gestionar de forma integral un campus de baloncesto. Surge de mi experiencia como entrenador en el campus que se celebra en Toledo cada julio, donde cerca de cien chavales de distintas edades y niveles entrenan, compiten y hacen vida de campamento durante once días. En los próximos minutos os explicaré el problema que resuelve, las decisiones técnicas, la arquitectura, las funcionalidades —con foco en el tiempo real— y los resultados. La aplicación está además desplegada y en uso, accesible en campus-baloncesto.web.app.",
 "Seguiré este guion, que coincide con la estructura de la memoria: primero el contexto y los objetivos; después el estado del arte y las decisiones tecnológicas con su arquitectura; luego las funcionalidades principales, deteniéndome en la generación de equipos, el tiempo real y las exportaciones; y cerraré con las pruebas, los resultados y las conclusiones. La idea es dar una visión completa del proyecto sin entrar en cada detalle, que queda recogido en el documento.",
 "El campus reúne cada edición a cerca de un centenar de jugadores de distintas edades y niveles, y toda su gestión se apoyaba en herramientas que no se hablan entre sí: una hoja de cálculo para las clasificaciones, un grupo de WhatsApp por equipo, folios para las estadísticas y una pizarra para los resultados. Eso genera errores, duplica trabajo y da una imagen poco profesional; la información se queda vieja enseguida y la comunicación se vuelve un caos con treinta o cuarenta personas en un grupo. A esto se sumó que la propia organización quería dar un salto informático y modernizar su imagen. La solución fue centralizarlo todo en una sola aplicación accesible desde cualquier dispositivo: los administradores trabajan desde el ordenador y entrenadores, jugadores y familias desde el móvil. Por 'gestión integral' entiendo cubrir el ciclo concreto del campus de principio a fin; los pagos y la facturación los dejé conscientemente fuera, como línea futura.",
 "El objetivo general era diseñar y desarrollar esa aplicación multiplataforma —app nativa en Android e iOS y PWA en navegador— que sustituyera lo manual por algo unificado, seguro y en tiempo real. De ahí salen los objetivos específicos: un sistema de autenticación con seis roles; la gestión de equipos con generación automática equilibrada; las competiciones con fase de grupos, eliminatorias y veladas, más el seguimiento en directo; el registro de estadísticas —puntos, rebotes, asistencias, robos y tapones— con sus rankings y el MVP; la gamificación y el jugador premium; los canales de comunicación; las dos exportaciones; la sincronización en tiempo real; las notificaciones push; y el despliegue como PWA instalable de acceso público.",
 "Trabajé con una metodología iterativa e incremental: en lugar de un único bloque, fui construyendo la aplicación módulo a módulo y probando cada funcionalidad nada más terminarla, ajustando sobre la marcha. El desarrollo se planificó de diciembre de 2025 a junio de 2026, y el diagrama de Gantt resume las fases —investigación y análisis, diseño, desarrollo por capas (front-end, base de datos y back-end), pruebas, paso a producción y memoria—, que en parte se solaparon. Como entorno usé Flutter con VS Code y control de versiones con Git, con el código alojado en un repositorio público de GitHub. Este enfoque, con entregas pequeñas y verificación continua, encajaba muy bien en un proyecto llevado por una sola persona.",
 "Antes de decidir nada miré qué había. Por un lado, aplicaciones de gestión deportiva ya existentes, del estilo de TeamSnap o GameChanger: son potentes, pero están pensadas para ligas genéricas, suelen ser de pago y no encajan con las particularidades de un campus, que tiene competiciones por estaciones, veladas y competiciones de siesta. Por otro lado, comparé los frameworks multiplataforma —Flutter, React Native e Ionic— y los servicios backend —Supabase, Firebase y AWS Amplify—, valorando rendimiento, idoneidad del modelo de datos, coste y mantenibilidad. De ese análisis salieron las dos decisiones clave que veréis a continuación: Flutter para el cliente y Supabase para el backend.",
 "Comparé las opciones en vez de elegir lo que más me sonaba. Para el cliente me decanté por Flutter, que era el que mejor equilibraba rendimiento nativo, consistencia visual entre plataformas y un soporte web suficientemente maduro, todo desde una sola base de código; frente a React Native o a Ionic, que corre sobre un WebView y pierde fluidez. Para el backend elegí Supabase, construido sobre PostgreSQL, porque me daba una base de datos relacional completa, seguridad a nivel de fila, tiempo real y autenticación ya hechos; para un dominio tan relacional como un campus encajaba mucho mejor que el NoSQL de Firebase. Acabé en una estrategia mixta: Supabase como backend principal, Firebase Cloud Messaging para las notificaciones, Firebase Hosting para la PWA y Cloudinary para las imágenes. Además, al ser Supabase de código abierto y con planes gratuitos generosos, abarata el mantenimiento y evita el vendor lock-in, algo crítico para una organización de base.",
 "La aplicación sigue una Clean Architecture pero organizada por funcionalidades: en lugar de carpetas globales por tipo, cada módulo guarda sus propias capas de presentación, dominio y datos, con la dependencia siempre hacia el dominio. El código se divide en lib/core, con lo compartido —configuración, tema, enrutador y servicios globales—, y lib/features, con una carpeta por funcionalidad. El estado se gestiona con Riverpod y sus AsyncNotifier, cuyo tipo AsyncValue representa de forma explícita los estados de carga, dato y error; además los proveedores se componen entre sí, de modo que, por ejemplo, la clasificación se recalcula sola cuando cambian los partidos. La navegación es declarativa con go_router, que en la PWA refleja las rutas en la URL y permite enlaces directos, con guardas de acceso según la sesión. El stack completo está a la derecha.",
 "El modelo son 20 tablas en PostgreSQL gestionadas por Supabase, con un diseño marcadamente relacional: tablas de entidad y de relación, como team_members, que modela la pertenencia de jugadores a equipos en muchos-a-muchos. La seguridad se apoya en dos pilares: la autenticación de Supabase y, sobre todo, las políticas de Row Level Security definidas en la propia base de datos. Cuando alguien se registra, un trigger crea su fila con el rol 'visitante' y un administrador lo promociona después. Defino seis roles —administrador, entrenador, jugador, jugador premium, familiar y visitante—, cada uno con un conjunto coherente de permisos. La clave de la RLS es que la autorización vive en el servidor: cada política es una expresión booleana que el motor evalúa fila a fila, así que la seguridad se mantiene aunque alguien acceda directamente a la API.",
 "Estas son las funcionalidades principales, derivadas de los casos de uso y de los requisitos: gestión de equipos y usuarios, generación automática de equipos, los formatos de competición, los partidos en directo, las estadísticas y rankings, el dashboard de administración, las exportaciones a PDF y Excel y las notificaciones push. Cada una está implementada como un módulo independiente dentro de lib/features. A continuación me detengo en las más representativas, que son también las que más aportan frente a las herramientas que se usaban antes.",
 "Uno de los problemas clásicos del campus era repartir a los jugadores en equipos parejos para que los partidos fueran competidos. El generador automático, implementado en el método autoGenerateBalancedTeams, parte de la edad, el nivel y la posición de cada jugador. Asigna a cada uno una puntuación de fuerza con una fórmula sencilla —el nivel pesa diez veces más que la edad: nivel por diez, más la edad—, separa a los jugadores por posiciones (pívots, bases y aleros) y reparte cada bloque, ordenado de más fuerte a más débil, con una heurística voraz tipo serpiente. En el fondo es un problema de partición equilibrada: una asignación al azar daría equipos descompensados y una optimización exhaustiva sería carísima, así que esta heurística logra un buen resultado a coste muy bajo. Además existen los equipos de partido, que se generan aparte y se excluyen del ranking de competición mediante el flag is_match_team.",
 "Hay tres formatos de competición. Las competiciones por estaciones, pruebas físicas y técnicas puntuadas por jornadas con una clasificación general. Las competiciones de siesta, que combinan liga y eliminatorias con su cuadro; aquí tuve que cuidar el desempate, replicando un esquema parecido al de la FIBA cuando dos participantes terminan con los mismos puntos. Y las veladas, actividades por equipos pensadas para la tarde-noche. Son justo el tipo de competiciones singulares de un campus que las herramientas genéricas no cubren bien, y por eso tenía sentido una solución propia.",
 "Esta fue la parte técnicamente más exigente, así que me detengo un poco. Lo normal en la web es el modelo petición–respuesta: el cliente pregunta y el servidor contesta; para enterarte de los cambios tendrías que estar preguntando sin parar. Un WebSocket, en cambio, es una conexión permanente y bidireccional: una vez abierta, el servidor puede empujar los datos al instante sin que el cliente pregunte. Los partidos en directo se apoyan en Supabase Realtime, que usa WebSockets por debajo: cada dispositivo se suscribe a la tabla live_matches y, cuando un entrenador suma puntos o faltas, se escribe en esa tabla, PostgreSQL detecta el cambio en su registro de replicación y Supabase lo retransmite por el WebSocket a todos los suscritos. Esas suscripciones se integran con los StreamProvider de Riverpod, de modo que el marcador se redibuja solo; medí la latencia y llega en menos de un segundo. Un detalle de diseño importante: aunque haya varios partidos a la vez, no abro una conexión por partido, sino una única suscripción a toda la tabla, y cada marcador filtra su propia fila de ese mismo flujo. Así el sistema escala sin conexiones extra y, al ser cada partido una fila independiente, no interfieren entre sí.",
 "Las estadísticas se registran por jugador y partido en la tabla player_match_stats —puntos, rebotes, asistencias, robos, tapones y MVP— y de ahí se calculan los rankings de anotador, reboteador y asistente. El dashboard de administración concentra el control del campus: promocionar a un usuario recién registrado, corregir un equipo o abrir una competición, algo clave durante los días de campus, cuando el ritmo es alto. Y están las dos exportaciones: el servicio SiestaExportService genera el PDF con la clasificación y el cuadro de eliminatorias, y ExportService produce el Excel de las estaciones con una hoja por grupo y las puntuaciones por día más el total. Su comportamiento cambia entre la web y el móvil, así que las validé por separado en cada plataforma.",
 "Aquí se ve la aplicación real: el marcador en directo, los rankings del campus y el cuadro de una competición de siesta. Todas las pantallas están documentadas en la memoria. Está desplegada como PWA en Firebase Hosting y es de acceso público en campus-baloncesto.web.app, instalable desde el navegador sin pasar por las tiendas. (Si el tribunal lo permite, este es el momento de enseñarla funcionando en vivo.)",
 "La estrategia de pruebas fue principalmente manual e incremental: al terminar cada funcionalidad la probaba metiendo datos y navegando por las pantallas para validar el comportamiento antes de seguir. Después organicé una fase de pruebas beta con otros entrenadores del campus, que al usar la aplicación con libertad destaparon fallos y detalles de usabilidad que a mí se me escapaban por conocerla demasiado. Gracias a ellos corregí cosas como pantallas que no se refrescaban, un límite de correos al registrar, los cuadros de eliminatorias en orden invertido o un Excel que en algún caso salía vacío. Reconozco que un conjunto de pruebas automatizadas habría dado más garantías, y lo dejo como línea de mejora.",
 "Se cumplieron todos los objetivos planteados: la aplicación gestiona el campus de forma integral, incorpora el algoritmo de generación de equipos, registra estadísticas, sincroniza en tiempo real, envía notificaciones y ofrece las dos exportaciones. En lo técnico, la pareja Flutter más Supabase fue la decisión más acertada: cubre tres plataformas con una sola base de código y delega en el backend la persistencia, la autenticación, el tiempo real y la seguridad. En cuanto al rendimiento, las pantallas cargan en menos de dos segundos —cumpliendo el RNF-02— y las actualizaciones en tiempo real llegan en menos de un segundo. Frente a las alternativas comerciales, el resultado reúne en un único producto, de código abierto y bajo coste, capacidades que esas soluciones solo ofrecen fragmentadas o a precios altos.",
 "Como conclusión, el proyecto demuestra que una sola persona puede construir una aplicación multiplataforma completa y profesional desde una única base de código, recorriendo el ciclo entero de ingeniería: análisis, diseño, desarrollo y despliegue en producción. Las aportaciones de más valor son el algoritmo de equilibrado de equipos y las dos exportaciones, ajustadas a necesidades reales. Por el camino afronté retos como las notificaciones push duplicadas o la adaptación de las exportaciones a cada plataforma. Como líneas futuras quedan las analíticas avanzadas, la inscripción y el pago en línea, una versión para wearables, el soporte multilingüe y, sobre todo, automatizar las pruebas con integración continua. El verdadero examen será la edición de julio de 2026, con el campus a pleno rendimiento. Muchas gracias; quedo a vuestra disposición para las preguntas.",
];
function note(s, t) {
  if (WITH_NOTES) {
    const body = NOTES[_noteIdx] || t;
    const ref = MEMREF[_noteIdx] ? (body + "\n\nEn la memoria → " + MEMREF[_noteIdx]) : body;
    s.addNotes(ref);
  }
  _noteIdx++;
}

const W = 10, H = 5.625;
const shadow = () => ({ type: "outer", color: "000000", blur: 7, offset: 3, angle: 135, opacity: 0.18 });

// header for light content slides (no underline accent — uses whitespace)
function header(slide, kicker, title) {
  slide.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.18, h: H, fill: { color: ORANGE } });
  slide.addText(kicker.toUpperCase(), {
    x: 0.6, y: 0.34, w: 8.9, h: 0.3, fontFace: TF, fontSize: 12, bold: true,
    color: ORANGE, charSpacing: 2, margin: 0,
  });
  slide.addText(title, {
    x: 0.6, y: 0.62, w: 8.9, h: 0.8, fontFace: HF, fontSize: 26, color: INK, margin: 0,
  });
}

// icon inside an orange (or custom) filled circle
async function iconCircle(slide, Comp, x, y, d = 0.62, bg = ORANGE, ic = "FFFFFF") {
  slide.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: bg }, shadow: shadow() });
  const id = await icon(Comp, ic);
  const s = d * 0.52;
  slide.addImage({ data: id, x: x + (d - s) / 2, y: y + (d - s) / 2, w: s, h: s });
}

// framed screenshot (rounded white card + shadow behind, image on top)
function shot(slide, path, x, y, w, h) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x - 0.07, y: y - 0.07, w: w + 0.14, h: h + 0.14, rectRadius: 0.08,
    fill: { color: LIGHT }, line: { color: LINE, width: 1 }, shadow: shadow(),
  });
  slide.addImage({ path, x, y, w, h });
}

async function build(withNotes, fileName) {
  WITH_NOTES = withNotes;
  _noteIdx = 0;
  pres = new pptxgen();
  pres.defineLayout({ name: "W", width: 10, height: 5.625 });
  pres.layout = "W";
  pres.author = "Alberto Rodríguez González";
  pres.title = "Defensa TFG · Campus Baloncesto App";

  // ============ 1. PORTADA ============
  let s = pres.addSlide();
  s.background = { color: DARK };
  // big faint basketball motif
  s.addImage({ data: await icon(Fa.FaBasketballBall, "2E2A26"), x: 6.6, y: 1.7, w: 4.2, h: 4.2 });
  s.addShape(pres.shapes.RECTANGLE, { x: 0.9, y: 1.0, w: 0.55, h: 0.09, fill: { color: ORANGE } });
  s.addText("UNIVERSIDAD POLITÉCNICA DE MADRID · ETSIINF", {
    x: 0.9, y: 1.18, w: 8, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: ORANGE_LT, charSpacing: 1, margin: 0,
  });
  s.addText("Aplicación multiplataforma y PWA para la gestión integral de un campus de baloncesto", {
    x: 0.9, y: 1.55, w: 8.4, h: 2.0, fontFace: HF, fontSize: 27, color: LIGHT, lineSpacingMultiple: 1.04, valign: "top", margin: 0,
  });
  s.addText("Trabajo de Fin de Grado · Grado en Ingeniería de Software", {
    x: 0.9, y: 3.6, w: 8, h: 0.35, fontFace: BF, fontSize: 14, italic: true, color: "C9C4BC", margin: 0,
  });
  s.addText([
    { text: "Autor:  ", options: { bold: true, color: ORANGE_LT } },
    { text: "Alberto Rodríguez González", options: { color: LIGHT } },
    { text: "      Tutor:  ", options: { bold: true, color: ORANGE_LT } },
    { text: "José Ramón Sánchez Couso", options: { color: LIGHT } },
  ], { x: 0.9, y: 4.35, w: 8.6, h: 0.4, fontFace: BF, fontSize: 13, margin: 0 });
  s.addText("Madrid, junio de 2026", {
    x: 0.9, y: 4.78, w: 8, h: 0.3, fontFace: BF, fontSize: 12, color: MUTED, margin: 0,
  });

  note(s, "Buenos días. Soy Alberto Rodríguez González y voy a presentar mi Trabajo de Fin de Grado: una aplicación multiplataforma y PWA para la gestión integral de un campus de baloncesto, tutorizada por José Ramón Sánchez Couso. En los próximos minutos os explicaré el problema que resuelve, cómo está construida y los resultados obtenidos.");

  // ============ 2. ÍNDICE ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "Guion de la defensa", "Índice");
  const agenda = [
    ["01", "Contexto y motivación", Fa.FaBasketballBall],
    ["02", "Objetivos y planificación", Fa.FaBullseye],
    ["03", "Estado del arte y tecnologías", Fa.FaLayerGroup],
    ["04", "Arquitectura y funcionalidades", Fa.FaThLarge],
    ["05", "Tiempo real y exportaciones", Fa.FaBolt],
    ["06", "Pruebas y resultados", Fa.FaClipboardCheck],
  ];
  let ax = 0.6, ay = 1.65, aw = 4.45, ah = 0.95, gx = 0.35, gy = 0.28;
  for (let i = 0; i < agenda.length; i++) {
    const col = i % 2, row = Math.floor(i / 2);
    const x = ax + col * (aw + gx), y = ay + row * (ah + gy);
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: aw, h: ah, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    s.addText(agenda[i][0], { x: x + 0.18, y: y + 0.1, w: 0.9, h: ah - 0.2, fontFace: HF, fontSize: 30, color: ORANGE_LT, valign: "middle", margin: 0 });
    await iconCircle(s, agenda[i][2], x + aw - 0.85, y + (ah - 0.55) / 2, 0.55);
    s.addText(agenda[i][1], { x: x + 1.15, y, w: aw - 2.1, h: ah, fontFace: TF, fontSize: 15.5, bold: true, color: INK, valign: "middle", margin: 0 });
  }

  note(s, "Este es el guion que seguiré: empezaré por el contexto y los objetivos; después las tecnologías y la arquitectura; luego las funcionalidades principales, deteniéndome en el tiempo real y las exportaciones; y terminaré con las pruebas, los resultados y las conclusiones.");

  // ============ 3. CONTEXTO Y MOTIVACIÓN ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "01 · El problema", "Contexto y motivación");
  s.addText([
    { text: "Soy entrenador del campus de baloncesto de verano de Toledo. ", options: { bold: true, color: INK, breakLine: true } },
    { text: "Cada año la gestión se hacía con hojas de cálculo, grupos de WhatsApp y papel: información dispersa, lenta de actualizar y difícil de compartir con familias y jugadores.", options: { color: MUTED } },
  ], { x: 0.6, y: 1.6, w: 4.9, h: 1.6, fontFace: BF, fontSize: 15, lineSpacingMultiple: 1.05, valign: "top", margin: 0 });
  const pains = [
    [Fa.FaFileExcel, "Hojas de cálculo", "Clasificaciones manuales y propensas a errores"],
    [Fa.FaWhatsapp, "WhatsApp", "Avisos y resultados perdidos entre mensajes"],
    [Fa.FaRegStickyNote, "Papel", "Puntuaciones y equipos apuntados a mano"],
  ];
  let py = 1.6;
  for (const [ic, t, d] of pains) {
    await iconCircle(s, ic, 5.85, py, 0.6);
    s.addText(t, { x: 6.6, y: py - 0.02, w: 3.3, h: 0.32, fontFace: TF, fontSize: 14.5, bold: true, color: INK, margin: 0 });
    s.addText(d, { x: 6.6, y: py + 0.3, w: 3.35, h: 0.5, fontFace: BF, fontSize: 12, color: MUTED, margin: 0 });
    py += 1.0;
  }
  s.addText("«Una sola herramienta, accesible desde el móvil, la tablet o el navegador, sin instalar nada distinto en cada dispositivo.»", {
    x: 0.6, y: 3.55, w: 4.9, h: 1.4, fontFace: BF, fontSize: 14, italic: true, color: ORANGE, valign: "top", margin: 0,
  });

  note(s, "El proyecto nace de mi experiencia como entrenador en el campus de verano de Toledo. Toda la gestión se hacía con hojas de cálculo, grupos de WhatsApp y papel: la información estaba dispersa, era lenta de actualizar y difícil de compartir con familias y jugadores. La idea fue centralizarlo todo en una sola herramienta accesible desde cualquier dispositivo, sin instalar nada distinto.");

  // ============ 4. OBJETIVOS ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "02 · Metas", "Objetivos del proyecto");
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 1.55, w: 8.8, h: 0.85, rectRadius: 0.06, fill: { color: DARK } });
  s.addText([
    { text: "Objetivo general   ", options: { bold: true, color: ORANGE_LT } },
    { text: "Digitalizar la gestión integral del campus en una única aplicación multiplataforma (Android, iOS y web/PWA).", options: { color: LIGHT } },
  ], { x: 0.9, y: 1.55, w: 8.2, h: 0.85, fontFace: BF, fontSize: 14, valign: "middle", margin: 0 });
  const objs = [
    [Fa.FaUsers, "Gestionar usuarios y equipos", "Roles, perfiles y grupos del campus"],
    [Fa.FaTrophy, "Competiciones y rankings", "Estaciones, siesta, veladas y partidos"],
    [Fa.FaBolt, "Resultados en tiempo real", "Marcador en directo y estadísticas"],
    [Fa.FaShieldAlt, "Seguridad por roles", "Acceso controlado con políticas RLS"],
  ];
  let ox = 0.6, oy = 2.7, ow = 4.3, oh = 1.15, ogx = 0.2, ogy = 0.25;
  for (let i = 0; i < objs.length; i++) {
    const c = i % 2, r = Math.floor(i / 2);
    const x = ox + c * (ow + ogx), y = oy + r * (oh + ogy);
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: ow, h: oh, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    await iconCircle(s, objs[i][0], x + 0.22, y + (oh - 0.6) / 2, 0.6);
    s.addText(objs[i][1], { x: x + 1.05, y: y + 0.18, w: ow - 1.25, h: 0.35, fontFace: TF, fontSize: 13.5, bold: true, color: INK, margin: 0 });
    s.addText(objs[i][2], { x: x + 1.05, y: y + 0.55, w: ow - 1.25, h: 0.45, fontFace: BF, fontSize: 11.5, color: MUTED, margin: 0 });
  }

  note(s, "El objetivo general era digitalizar la gestión integral del campus en una única aplicación multiplataforma. De ahí salen cuatro objetivos específicos: gestionar usuarios y equipos, organizar las competiciones y rankings, ofrecer resultados en tiempo real y garantizar la seguridad mediante un sistema de roles.");

  // ============ 4b. METODOLOGÍA Y PLANIFICACIÓN ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "02 · Cómo lo hice", "Metodología y planificación");
  const meth = [
    [Fa.FaSyncAlt, "Iterativa e incremental", "Módulo a módulo, probando cada parte al terminarla."],
    [Fa.FaCodeBranch, "Git + GitHub", "Control de versiones y repositorio público."],
    [Fa.FaRegCalendarAlt, "Dic 2025 – Jun 2026", "Análisis, diseño, desarrollo, pruebas y memoria."],
  ];
  for (let i = 0; i < 3; i++) {
    const x = 0.6 + i * 3.0;
    await iconCircle(s, meth[i][0], x, 1.55, 0.55);
    s.addText(meth[i][1], { x: x + 0.68, y: 1.5, w: 2.25, h: 0.35, fontFace: TF, fontSize: 13, bold: true, color: INK, margin: 0 });
    s.addText(meth[i][2], { x: x + 0.68, y: 1.82, w: 2.3, h: 0.6, fontFace: BF, fontSize: 10.8, color: MUTED, valign: "top", margin: 0 });
  }
  s.addText("PLANIFICACIÓN TEMPORAL · DIAGRAMA DE GANTT", { x: 0.6, y: 2.5, w: 8.9, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: ORANGE, charSpacing: 1, margin: 0 });
  { const gw = 7.4, gh = gw * 543 / 1542, gx = (W - gw) / 2; shot(s, "media/gantt.png", gx, 2.85, gw, gh); }

  // ============ 4c. ESTADO DEL ARTE ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "03 · Qué había antes", "Estado del arte");
  s.addText("Las apps deportivas comerciales (TeamSnap, GameChanger…) son potentes, pero genéricas, de pago y no cubren las competiciones por estaciones, las veladas ni la siesta. Comparé también los frameworks multiplataforma y los servicios backend disponibles:", { x: 0.6, y: 1.5, w: 8.9, h: 0.8, fontFace: BF, fontSize: 13.5, color: MUTED, valign: "top", margin: 0 });
  s.addText("FRAMEWORKS", { x: 0.6, y: 2.45, w: 4.3, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: ORANGE, charSpacing: 1, margin: 0 });
  s.addText("BACKEND (BaaS)", { x: 5.1, y: 2.45, w: 4.3, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: ORANGE, charSpacing: 1, margin: 0 });
  const hopt = () => ({ fill: { color: DARK }, color: "FFFFFF", bold: true, fontFace: TF, fontSize: 11, align: "left" });
  const chosen = () => ({ fill: { color: ORANGE }, color: "FFFFFF", bold: true, fontFace: BF, fontSize: 11, align: "left" });
  const cell = (t) => ({ text: t, options: { fill: { color: SOFT }, color: INK, fontFace: BF, fontSize: 11, align: "left" } });
  const tblFw = [
    [{ text: "Framework", options: hopt() }, { text: "Punto clave", options: hopt() }],
    [{ text: "Flutter  ✓", options: chosen() }, { text: "Compila a nativo · 1 base de código", options: chosen() }],
    [cell("React Native"), cell("Puente JS · menos fluido")],
    [cell("Ionic"), cell("WebView · rendimiento bajo")],
  ];
  s.addTable(tblFw, { x: 0.6, y: 2.78, w: 4.3, colW: [1.35, 2.95], rowH: 0.52, border: { pt: 1, color: LINE }, valign: "middle", margin: 4 });
  const tblBk = [
    [{ text: "Backend", options: hopt() }, { text: "Punto clave", options: hopt() }],
    [{ text: "Supabase  ✓", options: chosen() }, { text: "PostgreSQL · RLS · tiempo real", options: chosen() }],
    [cell("Firebase"), cell("NoSQL · complica lo relacional")],
    [cell("AWS Amplify"), cell("Potente · configuración compleja")],
  ];
  s.addTable(tblBk, { x: 5.1, y: 2.78, w: 4.3, colW: [1.45, 2.85], rowH: 0.52, border: { pt: 1, color: LINE }, valign: "middle", margin: 4 });
  s.addText("De ahí salen las dos decisiones clave del proyecto: Flutter y Supabase.", { x: 0.6, y: 5.0, w: 8.9, h: 0.4, fontFace: BF, fontSize: 12.5, italic: true, color: ORANGE, margin: 0 });

  // ============ 5. ESTADO DEL ARTE / DECISIÓN TECNOLÓGICA ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "03 · Decisiones", "¿Por qué este stack?");
  const stack = [
    [Fa.FaMobileAlt, "Flutter", "Una sola base de código compila a Android, iOS y web. Frente a React Native o desarrollo nativo, máxima reutilización."],
    [Fa.FaServer, "Supabase", "Backend gestionado (PostgreSQL, Auth, Realtime y RLS). Más control relacional que Firebase para los datos del campus."],
    [Fa.FaGlobe, "PWA", "La versión web se instala como app y funciona sin tiendas, clave para que cualquiera la use al instante."],
  ];
  let cx = 0.6, cw = 2.93, cgap = 0.2, cy = 1.7, ch = 3.2;
  for (let i = 0; i < stack.length; i++) {
    const x = cx + i * (cw + cgap);
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: cy, w: cw, h: ch, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    await iconCircle(s, stack[i][0], x + (cw - 0.7) / 2, cy + 0.3, 0.7);
    s.addText(stack[i][1], { x, y: cy + 1.15, w: cw, h: 0.4, fontFace: HF, fontSize: 18, color: INK, align: "center", margin: 0 });
    s.addText(stack[i][2], { x: x + 0.25, y: cy + 1.6, w: cw - 0.5, h: 1.5, fontFace: BF, fontSize: 12, color: MUTED, align: "center", valign: "top", margin: 0 });
  }

  note(s, "Elegí Flutter porque con una sola base de código compilo para Android, iOS y web, frente a React Native o el desarrollo nativo. Como backend usé Supabase, que aporta PostgreSQL, autenticación, tiempo real y seguridad a nivel de fila, con más control relacional que Firebase. Y publiqué la versión web como PWA, que se instala como una app sin pasar por las tiendas.");

  // ============ 6. ARQUITECTURA ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "04 · Diseño", "Arquitectura del sistema");
  s.addText("Clean Architecture por funcionalidades (feature-first), con la regla de dependencia hacia el dominio:", {
    x: 0.6, y: 1.55, w: 5.2, h: 0.7, fontFace: BF, fontSize: 14, color: MUTED, valign: "top", margin: 0 });
  const layers = [
    ["Presentación", "Pantallas + Riverpod (estado)", ORANGE],
    ["Dominio", "Lógica de negocio y modelos", "B5601A"],
    ["Datos", "Repositorios · Supabase / Cloudinary", "7A3E10"],
  ];
  let ly = 2.35;
  for (const [t, d, col] of layers) {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: ly, w: 5.2, h: 0.82, rectRadius: 0.06, fill: { color: col } });
    s.addText(t, { x: 0.85, y: ly + 0.1, w: 2, h: 0.6, fontFace: HF, fontSize: 15, color: LIGHT, valign: "middle", margin: 0 });
    s.addText(d, { x: 2.7, y: ly + 0.1, w: 3.0, h: 0.6, fontFace: BF, fontSize: 12, color: "FBEFE3", valign: "middle", align: "right", margin: 0 });
    ly += 0.95;
  }
  // right column: tech chips
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 6.1, y: 1.55, w: 3.3, h: 3.55, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
  s.addText("STACK TÉCNICO", { x: 6.35, y: 1.72, w: 2.9, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: ORANGE, charSpacing: 1, margin: 0 });
  const techs = [
    [Fa.FaMobileAlt, "Flutter 3 / Dart"],
    [Fa.FaProjectDiagram, "Riverpod · go_router"],
    [Fa.FaDatabase, "Supabase (PostgreSQL)"],
    [Fa.FaBell, "Firebase Cloud Messaging"],
    [Fa.FaCloudUploadAlt, "Cloudinary (imágenes)"],
    [Fa.FaServer, "Firebase Hosting (PWA)"],
  ];
  let ty = 2.18;
  for (const [ic, t] of techs) {
    await iconCircle(s, ic, 6.4, ty, 0.42);
    s.addText(t, { x: 6.95, y: ty - 0.04, w: 2.4, h: 0.5, fontFace: BF, fontSize: 12.5, color: INK, valign: "middle", margin: 0 });
    ty += 0.5;
  }

  note(s, "La aplicación sigue Clean Architecture organizada por funcionalidades, con la dependencia siempre hacia el dominio: presentación con Riverpod, dominio con la lógica de negocio y capa de datos con los repositorios. A la derecha está el stack completo: Flutter, Riverpod y go_router, Supabase, Firebase Cloud Messaging, Cloudinary para las imágenes y Firebase Hosting para la PWA.");

  // ============ 7. MODELO DE DATOS Y SEGURIDAD ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "04 · Datos", "Modelo de datos y seguridad");
  // big stat
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 1.6, w: 2.55, h: 3.4, rectRadius: 0.06, fill: { color: DARK } });
  s.addText("20", { x: 0.6, y: 1.85, w: 2.55, h: 1.1, fontFace: HF, fontSize: 60, color: ORANGE, align: "center", margin: 0 });
  s.addText("tablas en PostgreSQL", { x: 0.7, y: 3.0, w: 2.35, h: 0.5, fontFace: TF, fontSize: 14, bold: true, color: LIGHT, align: "center", margin: 0 });
  s.addText("Modelo relacional normalizado: usuarios, equipos, competiciones, partidos, veladas, estadísticas…", {
    x: 0.75, y: 3.5, w: 2.25, h: 1.4, fontFace: BF, fontSize: 11.5, color: "C9C4BC", align: "center", valign: "top", margin: 0 });
  const sec = [
    [Fa.FaUserShield, "Seis roles", "Administrador, entrenador, jugador, jugador premium, familiar y visitante."],
    [Fa.FaShieldAlt, "Row Level Security", "Políticas en la base de datos: cada rol solo ve y edita lo que le corresponde."],
    [Fa.FaLock, "Autenticación Supabase", "Registro e inicio de sesión gestionados con tokens y trigger de alta automática."],
  ];
  let sy = 1.6;
  for (const [ic, t, d] of sec) {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 3.4, y: sy, w: 6.0, h: 1.05, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    await iconCircle(s, ic, 3.62, sy + 0.225, 0.6);
    s.addText(t, { x: 4.45, y: sy + 0.14, w: 4.8, h: 0.35, fontFace: TF, fontSize: 14, bold: true, color: INK, margin: 0 });
    s.addText(d, { x: 4.45, y: sy + 0.5, w: 4.8, h: 0.5, fontFace: BF, fontSize: 11.5, color: MUTED, margin: 0 });
    sy += 1.18;
  }

  note(s, "El modelo de datos son 20 tablas en PostgreSQL, normalizadas. La seguridad se apoya en tres roles —administrador, entrenador y visitante— y, sobre todo, en las políticas de Row Level Security, aplicadas en la propia base de datos para que cada rol solo vea y edite lo que le corresponde. La autenticación la gestiona Supabase, con un trigger que da de alta al usuario automáticamente.");

  // ============ 8. FUNCIONALIDADES (MAPA) ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "04 · Visión general", "Funcionalidades principales");
  const feats = [
    [Fa.FaUsers, "Equipos y usuarios"],
    [Fa.FaRandom, "Generación automática"],
    [Fa.FaTrophy, "Competiciones"],
    [Fa.FaBolt, "Partidos en directo"],
    [Fa.FaChartBar, "Estadísticas y rankings"],
    [Fa.FaTachometerAlt, "Dashboard de admin"],
    [Fa.FaFilePdf, "Exportación PDF/Excel"],
    [Fa.FaBell, "Notificaciones push"],
  ];
  let fx = 0.6, fy = 1.7, fw = 2.2, fh = 1.55, fgx = 0.18, fgy = 0.2;
  for (let i = 0; i < feats.length; i++) {
    const c = i % 4, r = Math.floor(i / 4);
    const x = fx + c * (fw + fgx), y = fy + r * (fh + fgy);
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: fw, h: fh, rectRadius: 0.07, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    await iconCircle(s, feats[i][0], x + (fw - 0.72) / 2, y + 0.28, 0.72);
    s.addText(feats[i][1], { x: x + 0.1, y: y + 1.06, w: fw - 0.2, h: 0.42, fontFace: TF, fontSize: 12.5, bold: true, color: INK, align: "center", valign: "middle", margin: 0 });
  }

  note(s, "Estas son las funcionalidades principales: gestión de equipos y usuarios, generación automática de equipos, los formatos de competición, los partidos en directo, las estadísticas y rankings, el dashboard de administración, la exportación a PDF y Excel y las notificaciones push. Me detendré en las más representativas.");

  // ============ 9. EQUIPOS + GENERACIÓN AUTOMÁTICA ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "04 · Destacado", "Equipos equilibrados con un toque");
  s.addText([
    { text: "El reto: ", options: { bold: true, color: INK } },
    { text: "repartir a los jugadores en equipos parejos para que los partidos sean competidos.", options: { color: MUTED }, breakLine: true },
  ], { x: 0.6, y: 1.6, w: 5.1, h: 0.8, fontFace: BF, fontSize: 14.5, valign: "top", margin: 0 });
  const algo = [
    [Fa.FaBalanceScale, "Algoritmo de equilibrado", "Reparte según nivel, edad y posición para igualar la fuerza de cada equipo."],
    [Fa.FaUsersCog, "Equipos de partido", "Generados aparte y excluidos del ranking de competición (is_match_team)."],
    [Fa.FaCheckCircle, "Manual o automático", "El entrenador puede crear grupos a mano o generarlos al instante."],
  ];
  let gyy = 2.45;
  for (const [ic, t, d] of algo) {
    await iconCircle(s, ic, 0.62, gyy, 0.58);
    s.addText(t, { x: 1.4, y: gyy - 0.04, w: 4.4, h: 0.32, fontFace: TF, fontSize: 13.5, bold: true, color: INK, margin: 0 });
    s.addText(d, { x: 1.4, y: gyy + 0.28, w: 4.4, h: 0.5, fontFace: BF, fontSize: 11.5, color: MUTED, margin: 0 });
    gyy += 0.92;
  }
  shot(s, "media/autoteams.png", 7.0, 1.55, 2.55, 3.33);

  note(s, "Un problema habitual del campus era repartir a los jugadores en equipos parejos. Implementé un algoritmo que los equilibra según nivel, edad y posición. Además existen los equipos de partido, que se generan aparte y se excluyen del ranking de competición mediante el flag is_match_team. El entrenador puede crear los grupos a mano o generarlos automáticamente al instante.");

  // ============ 10. COMPETICIONES ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "04 · Competición", "Tres formatos de competición");
  const comp = [
    [Fa.FaTrophy, "Por estaciones", "Pruebas físicas y técnicas con puntuación por jornadas y clasificación general."],
    [Fa.FaTable, "Competiciones de siesta", "Ligas y eliminatorias (grupos → cuadro) con clasificación y brackets."],
    [Fa.FaUsers, "Veladas", "Grupos por equipos con ganadores, pensado para las actividades de tarde-noche."],
  ];
  let cyy = 1.6;
  for (const [ic, t, d] of comp) {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: cyy, w: 5.6, h: 1.05, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    await iconCircle(s, ic, 0.82, cyy + 0.225, 0.6);
    s.addText(t, { x: 1.65, y: cyy + 0.13, w: 4.4, h: 0.35, fontFace: TF, fontSize: 14, bold: true, color: INK, margin: 0 });
    s.addText(d, { x: 1.65, y: cyy + 0.49, w: 4.4, h: 0.5, fontFace: BF, fontSize: 11.5, color: MUTED, margin: 0 });
    cyy += 1.16;
  }
  shot(s, "media/bracket.png", 6.7, 1.55, 2.85, 3.35);

  note(s, "Hay tres formatos de competición. Las competiciones por estaciones, con pruebas puntuadas por jornadas y clasificación general. Las competiciones de siesta, que combinan liga y eliminatorias con su cuadro, como se ve en la captura. Y las veladas, pensadas para las actividades de tarde-noche por equipos.");

  // ============ 11. TIEMPO REAL ============
  s = pres.addSlide();
  s.background = { color: DARK };
  s.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.18, h: H, fill: { color: ORANGE } });
  s.addText("05 · LO MÁS EXIGENTE", { x: 0.6, y: 0.45, w: 8, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: ORANGE_LT, charSpacing: 2, margin: 0 });
  s.addText("Partidos en directo, en tiempo real", { x: 0.6, y: 0.78, w: 8.5, h: 0.7, fontFace: HF, fontSize: 26, color: LIGHT, margin: 0 });
  const rt = [
    [Fa.FaBolt, "Supabase Realtime", "Vía WebSockets, el marcador se sincroniza al instante en todos los dispositivos."],
    [Fa.FaStopwatch, "Marcador y faltas", "Puntos y faltas por equipo; los partidos en juego se ven desde cualquier pantalla."],
    [Fa.FaSyncAlt, "Latencia < 1 s", "Las actualizaciones llegan a los clientes suscritos en menos de un segundo."],
  ];
  let ryy = 1.7;
  for (const [ic, t, d] of rt) {
    await iconCircle(s, ic, 0.62, ryy, 0.6);
    s.addText(t, { x: 1.45, y: ryy - 0.02, w: 4.5, h: 0.32, fontFace: TF, fontSize: 14.5, bold: true, color: LIGHT, margin: 0 });
    s.addText(d, { x: 1.45, y: ryy + 0.32, w: 4.55, h: 0.6, fontFace: BF, fontSize: 12, color: "C9C4BC", margin: 0 });
    ryy += 1.05;
  }
  shot(s, "media/scoreboard.png", 7.0, 1.5, 2.55, 3.33);

  note(s, "Esta fue la parte más exigente. Los partidos en directo usan Supabase Realtime sobre WebSockets, de modo que el marcador se sincroniza al instante en todos los dispositivos conectados. Se registran puntos y faltas por equipo, y cualquiera puede seguir el marcador desde su pantalla. Medí la latencia y las actualizaciones llegan en menos de un segundo.");

  // ============ 12. ESTADÍSTICAS, DASHBOARD Y EXPORTACIONES ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "05 · Datos a la vista", "Estadísticas y exportaciones");
  const ex = [
    [Fa.FaChartBar, "Rankings del campus", "Máximo anotador, reboteador, asistente y MVP, calculados automáticamente."],
    [Fa.FaTachometerAlt, "Dashboard de admin", "Visión global del campus de un vistazo: personas, competiciones y comunidad."],
    [Fa.FaFilePdf, "Exportación a PDF", "Clasificaciones y cuadros de las competiciones de siesta, listos para imprimir."],
    [Fa.FaFileExcel, "Exportación a Excel", "Clasificación por estaciones, una hoja por grupo y puntuaciones por jornada."],
  ];
  let ex_y = 1.6;
  for (let i = 0; i < ex.length; i++) {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: ex_y, w: 5.7, h: 0.78, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    await iconCircle(s, ex[i][0], 0.78, ex_y + 0.12, 0.52);
    s.addText(ex[i][1], { x: 1.5, y: ex_y + 0.08, w: 4.7, h: 0.3, fontFace: TF, fontSize: 13, bold: true, color: INK, margin: 0 });
    s.addText(ex[i][2], { x: 1.5, y: ex_y + 0.38, w: 4.7, h: 0.36, fontFace: BF, fontSize: 10.8, color: MUTED, margin: 0 });
    ex_y += 0.87;
  }
  shot(s, "media/dashboard.png", 6.85, 1.55, 2.7, 3.35);

  note(s, "La app calcula automáticamente los rankings del campus: máximo anotador, reboteador, asistente y MVP. El dashboard de administración ofrece una visión global de un vistazo. Y permite exportar: a PDF las clasificaciones y cuadros de las competiciones de siesta, y a Excel la clasificación por estaciones, con una hoja por grupo.");

  // ============ 13. DEMO / EN PRODUCCIÓN ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "Demostración", "La app, en producción");
  const phones = [["media/scoreboard.png", "Marcador en directo"], ["media/rankings.png", "Rankings del campus"], ["media/bracket.png", "Competición de siesta"]];
  let phw = 2.28, phh = 2.95, total = phw * 3 + 0.55 * 2, startx = (W - total) / 2, phy = 1.42;
  for (let i = 0; i < 3; i++) {
    const x = startx + i * (phw + 0.55);
    shot(s, phones[i][0], x, phy, phw, phh);
    s.addText(phones[i][1], { x: x - 0.15, y: phy + phh + 0.14, w: phw + 0.3, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: INK, align: "center", margin: 0 });
  }
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 1.85, y: 5.08, w: 6.3, h: 0.4, rectRadius: 0.2, fill: { color: DARK } });
  s.addText([
    { text: "● EN VIVO   ", options: { color: ORANGE_LT, bold: true } },
    { text: "campus-baloncesto.web.app", options: { color: LIGHT } },
  ], { x: 1.85, y: 5.08, w: 6.3, h: 0.4, fontFace: BF, fontSize: 12.5, align: "center", valign: "middle", margin: 0 });

  note(s, "Aquí se ve la aplicación real en funcionamiento: el marcador en directo, los rankings del campus y el cuadro de una competición de siesta. Está desplegada y accesible públicamente en campus-baloncesto.web.app. (Si el tribunal lo permite, este es el momento de hacer la demostración en vivo.)");

  // ============ 14. PRUEBAS ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "06 · Calidad", "Pruebas");
  const tests = [
    [Fa.FaClipboardCheck, "Pruebas manuales e incrementales", "Al terminar cada funcionalidad se probaba metiendo datos y navegando por las pantallas para validar el comportamiento."],
    [Fa.FaUsersCog, "Pruebas beta con entrenadores", "Otros entrenadores usaron la app con libertad y destaparon fallos que se me escapaban por conocerla demasiado."],
    [Fa.FaBug, "Errores detectados y corregidos", "Refrescos que faltaban, límite de correos al registrar, brackets invertidos y un Excel que salía vacío."],
  ];
  let tyy = 1.62;
  for (const [ic, t, d] of tests) {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: tyy, w: 8.8, h: 1.05, rectRadius: 0.06, fill: { color: SOFT }, line: { color: LINE, width: 1 } });
    await iconCircle(s, ic, 0.82, tyy + 0.225, 0.6);
    s.addText(t, { x: 1.65, y: tyy + 0.13, w: 7.5, h: 0.35, fontFace: TF, fontSize: 14, bold: true, color: INK, margin: 0 });
    s.addText(d, { x: 1.65, y: tyy + 0.5, w: 7.6, h: 0.5, fontFace: BF, fontSize: 12, color: MUTED, margin: 0 });
    tyy += 1.16;
  }

  note(s, "Las pruebas fueron principalmente manuales e incrementales: al terminar cada funcionalidad la probaba metiendo datos y navegando por las pantallas. Después hice una fase de pruebas beta con otros entrenadores, que al usarla con libertad destaparon fallos que a mí se me escapaban por conocer demasiado la herramienta. Gracias a ello corregí cosas como refrescos que faltaban, un límite de correos al registrar, brackets invertidos o un Excel que salía vacío.");

  // ============ 15. RESULTADOS ============
  s = pres.addSlide();
  s.background = { color: LIGHT };
  header(s, "06 · Resultados", "Objetivos cumplidos");
  const stats = [["3", "plataformas\ndesde un código"], ["< 2 s", "carga de las\npantallas (RNF-02)"], ["< 1 s", "actualización\nen tiempo real"]];
  let stx = 0.6, stw = 2.85, stgap = 0.22, sty = 1.6;
  for (let i = 0; i < 3; i++) {
    const x = stx + i * (stw + stgap);
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: sty, w: stw, h: 1.5, rectRadius: 0.06, fill: { color: DARK } });
    s.addText(stats[i][0], { x, y: sty + 0.18, w: stw, h: 0.7, fontFace: HF, fontSize: 38, color: ORANGE, align: "center", margin: 0 });
    s.addText(stats[i][1], { x: x + 0.15, y: sty + 0.92, w: stw - 0.3, h: 0.5, fontFace: TF, fontSize: 11.5, bold: true, color: LIGHT, align: "center", margin: 0 });
  }
  const dones = [
    "Aplicación desplegada y en uso real (PWA + APK)",
    "Gestión completa: usuarios, equipos y competiciones",
    "Tiempo real y exportaciones funcionando en las 4 plataformas",
    "Todos los requisitos funcionales implementados",
  ];
  let dy = 3.45;
  for (const t of dones) {
    await iconCircle(s, Fa.FaCheckCircle, 0.62, dy, 0.4, "FFFFFF", ORANGE);
    s.addShape(pres.shapes.OVAL, { x: 0.62, y: dy, w: 0.4, h: 0.4, fill: { color: SOFT }, line: { color: ORANGE, width: 1 } });
    const ci = await icon(Fa.FaCheck, ORANGE);
    s.addImage({ data: ci, x: 0.62 + 0.1, y: dy + 0.1, w: 0.2, h: 0.2 });
    s.addText(t, { x: 1.15, y: dy - 0.03, w: 8.3, h: 0.45, fontFace: BF, fontSize: 13.5, color: INK, valign: "middle", margin: 0 });
    dy += 0.5;
  }

  note(s, "En cuanto a resultados: una sola base de código para tres plataformas, las pantallas cargan en menos de dos segundos cumpliendo el RNF-02 y las actualizaciones en tiempo real llegan en menos de un segundo. La aplicación está desplegada y en uso real, la gestión es completa y todos los requisitos funcionales están implementados.");

  // ============ 16. CONCLUSIONES Y CIERRE ============
  s = pres.addSlide();
  s.background = { color: DARK };
  s.addImage({ data: await icon(Fa.FaBasketballBall, "242019"), x: -1.3, y: 2.4, w: 4, h: 4 });
  s.addShape(pres.shapes.RECTANGLE, { x: 0.9, y: 0.7, w: 0.55, h: 0.09, fill: { color: ORANGE } });
  s.addText("CONCLUSIONES", { x: 0.9, y: 0.88, w: 8, h: 0.3, fontFace: TF, fontSize: 12, bold: true, color: ORANGE_LT, charSpacing: 2, margin: 0 });
  s.addText("Un proyecto completo, de la idea al uso real", { x: 0.9, y: 1.2, w: 8.5, h: 0.7, fontFace: HF, fontSize: 24, color: LIGHT, margin: 0 });
  const concl = [
    "Resuelve un problema real con una sola herramienta multiplataforma",
    "Integra tiempo real, seguridad por roles y exportación de datos",
    "Demuestra el ciclo completo: análisis, diseño, desarrollo y despliegue",
  ];
  let nyy = 2.15;
  for (const t of concl) {
    const ci = await icon(Fa.FaCheckCircle, ORANGE_LT);
    s.addImage({ data: ci, x: 1.0, y: nyy + 0.03, w: 0.28, h: 0.28 });
    s.addText(t, { x: 1.45, y: nyy - 0.02, w: 8.0, h: 0.4, fontFace: BF, fontSize: 14, color: LIGHT, valign: "middle", margin: 0 });
    nyy += 0.52;
  }
  s.addText("Líneas futuras", { x: 0.9, y: 3.85, w: 8, h: 0.3, fontFace: TF, fontSize: 13, bold: true, color: ORANGE_LT, margin: 0 });
  s.addText("Pruebas automatizadas · estadísticas integradas en el propio partido · más analíticas para el entrenador.", {
    x: 0.9, y: 4.18, w: 8.5, h: 0.5, fontFace: BF, fontSize: 12.5, italic: true, color: "C9C4BC", margin: 0 });
  s.addText([
    { text: "¡Gracias!   ", options: { bold: true, color: LIGHT } },
    { text: "campus-baloncesto.web.app", options: { color: ORANGE_LT } },
  ], { x: 0.9, y: 4.85, w: 8.5, h: 0.4, fontFace: BF, fontSize: 14, margin: 0 });

  note(s, "Como conclusión, el proyecto resuelve un problema real con una única herramienta multiplataforma, integra tiempo real, seguridad por roles y exportación de datos, y demuestra el ciclo completo de ingeniería: análisis, diseño, desarrollo y despliegue. Como líneas futuras añadiría pruebas automatizadas, integrar las estadísticas en el propio partido y más analíticas para el entrenador. Muchas gracias; quedo a vuestra disposición para las preguntas.");

  await pres.writeFile({ fileName });
  console.log("Generado:", fileName);
}

(async () => {
  await build(false, "../presentacion_tfg_campus.pptx");
  await build(true, "../presentacion_tfg_campus_con_notas.pptx");
  console.log("Ambas versiones generadas.");
})().catch(e => { console.error(e); process.exit(1); });
