/*
 * Generador de la memoria del TFG "Campus Baloncesto App".
 * Construye el documento .docx completo con docx-js: portada, indice (TOC),
 * capitulos, figuras (imagenes PNG), huecos reservados para capturas y tablas.
 *
 * El contenido se porta desde la version actual del documento (editada a mano
 * por el autor), integrando el contexto nuevo: el autor es entrenador del
 * campus de Toledo (1-11 de julio), la aplicacion se estrena en la edicion de
 * julio de 2026.
 *
 * Uso:  node generar_memoria.js
 * Salida: memoria_tfg_campus_baloncesto.docx  (o ..._v2.docx si esta bloqueado)
 */

const fs = require('fs');
const path = require('path');

// Cargar docx-js desde la instalacion global.
const { execSync } = require('child_process');
let GLOBAL_ROOT;
try {
  GLOBAL_ROOT = execSync('npm root -g').toString().trim();
} catch (e) {
  GLOBAL_ROOT = 'C:/Users/abeto/AppData/Roaming/npm/node_modules';
}
const docx = require(path.join(GLOBAL_ROOT, 'docx'));

const {
  Document, Packer, Paragraph, TextRun, ImageRun,
  HeadingLevel, AlignmentType, LevelFormat,
  Table, TableRow, TableCell, WidthType, BorderStyle, ShadingType,
  TableOfContents, PageNumber, Header, Footer, PageBreak,
  VerticalAlign, TableLayoutType, convertMillimetersToTwip,
} = docx;

const DIR = __dirname;

// ---------------------------------------------------------------------------
// Constantes de formato
// ---------------------------------------------------------------------------
const FONT = 'Times New Roman';
const SZ_BODY = 24;     // 12pt (half-points)
const SZ_H1 = 28;       // 14pt
const SZ_H2 = 24;       // 12pt
const SZ_CAPTION = 20;  // 10pt
const LINE_15 = 360;    // interlineado 1,5 (240 = simple)
const CONTENT_WIDTH_DXA = 9070; // ~16 cm de ancho de contenido (A4 - 2x2,5cm)

const COLOR_HEADER_FILL = 'D9E2F3';   // gris azulado para cabeceras de tabla
const COLOR_PLACEHOLDER_FILL = 'F2F2F2';
const COLOR_BORDER = 'BFBFBF';
const COLOR_GREY_TEXT = '808080';

// Comillas tipograficas
const LQ = '“';
const RQ = '”';
function q(s) { return LQ + s + RQ; }

// ---------------------------------------------------------------------------
// Helpers de parrafos
// ---------------------------------------------------------------------------

// Parrafo de cuerpo justificado. Acepta string o array de TextRun.
function body(text, opts = {}) {
  const children = Array.isArray(text)
    ? text
    : [new TextRun({ text, font: FONT, size: SZ_BODY })];
  return new Paragraph({
    children,
    alignment: opts.align || AlignmentType.JUSTIFIED,
    spacing: { line: LINE_15, after: opts.after != null ? opts.after : 160 },
  });
}

function run(text, o = {}) {
  return new TextRun({
    text,
    font: FONT,
    size: o.size || SZ_BODY,
    bold: o.bold || false,
    italics: o.italics || false,
    color: o.color,
  });
}

// Titulo de capitulo (Heading1, salto de pagina antes).
function chapter(text, withBreak = true) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    pageBreakBefore: withBreak,
    spacing: { before: 0, after: 240, line: LINE_15 },
    children: [new TextRun({ text, font: FONT, size: SZ_H1, bold: true })],
  });
}

// Encabezado de seccion de primer nivel sin numerar (resumen, indice, etc.)
function chapterNoNum(text, withBreak = true) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    pageBreakBefore: withBreak,
    spacing: { before: 0, after: 240, line: LINE_15 },
    children: [new TextRun({ text, font: FONT, size: SZ_H1, bold: true })],
  });
}

function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 240, after: 120, line: LINE_15 },
    children: [new TextRun({ text, font: FONT, size: SZ_H2, bold: true })],
  });
}

function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 200, after: 100, line: LINE_15 },
    children: [new TextRun({ text, font: FONT, size: SZ_H2, bold: true })],
  });
}

// Lista con vinetas.
function bullet(text) {
  const children = Array.isArray(text)
    ? text
    : [new TextRun({ text, font: FONT, size: SZ_BODY })];
  return new Paragraph({
    children,
    bullet: { level: 0 },
    alignment: AlignmentType.JUSTIFIED,
    spacing: { line: LINE_15, after: 80 },
  });
}

// ---------------------------------------------------------------------------
// Figuras (imagen + pie)
// ---------------------------------------------------------------------------
function figure(file, widthCm, heightCm, captionText) {
  const data = fs.readFileSync(path.join(DIR, file));
  const img = new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 160, after: 40, line: LINE_15 },
    children: [
      new ImageRun({
        data,
        type: 'png',
        transformation: { width: Math.round(widthCm * 37.795), height: Math.round(heightCm * 37.795) },
      }),
    ],
  });
  const caption = new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 200, line: LINE_15 },
    children: [new TextRun({ text: captionText, font: FONT, size: SZ_CAPTION, italics: true })],
  });
  global.__imgCount++;
  return [img, caption];
}

// Calcula alto en cm a partir del ancho deseado manteniendo proporcion.
function heightFor(wPx, hPx, widthCm) {
  return widthCm * (hPx / wPx);
}

// ---------------------------------------------------------------------------
// Hueco reservado para captura de pantalla (tabla de 1 celda + pie)
// ---------------------------------------------------------------------------
function placeholder(captionText) {
  const cell = new TableCell({
    width: { size: CONTENT_WIDTH_DXA, type: WidthType.DXA },
    shading: { type: ShadingType.CLEAR, fill: COLOR_PLACEHOLDER_FILL, color: 'auto' },
    margins: { top: 600, bottom: 600, left: 200, right: 200 },
    verticalAlign: VerticalAlign.CENTER,
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { line: LINE_15 },
        children: [new TextRun({
          text: '[ Espacio reservado para la captura de pantalla ]',
          font: FONT, size: SZ_BODY, italics: true, color: COLOR_GREY_TEXT,
        })],
      }),
    ],
  });
  const row = new TableRow({ height: { value: 3686, rule: 'atLeast' }, children: [cell] }); // ~6,5 cm
  const border = { style: BorderStyle.SINGLE, size: 6, color: COLOR_BORDER };
  const table = new Table({
    width: { size: CONTENT_WIDTH_DXA, type: WidthType.DXA },
    layout: TableLayoutType.FIXED,
    borders: { top: border, bottom: border, left: border, right: border, insideHorizontal: border, insideVertical: border },
    rows: [row],
  });
  const wrapper = new Paragraph({ spacing: { before: 160, after: 40 }, children: [] });
  const caption = new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 80, after: 220, line: LINE_15 },
    children: [new TextRun({ text: captionText, font: FONT, size: SZ_CAPTION, italics: true })],
  });
  global.__phCount++;
  return [wrapper, table, caption];
}

// ---------------------------------------------------------------------------
// Tablas de datos con cabecera sombreada
// ---------------------------------------------------------------------------
function dataTable(headers, rows, colWidths) {
  const total = CONTENT_WIDTH_DXA;
  const widths = colWidths || headers.map(() => Math.floor(total / headers.length));

  const headerCell = (txt, w) => new TableCell({
    width: { size: w, type: WidthType.DXA },
    shading: { type: ShadingType.CLEAR, fill: COLOR_HEADER_FILL, color: 'auto' },
    margins: { top: 60, bottom: 60, left: 90, right: 90 },
    verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({
      spacing: { line: LINE_15, after: 0 },
      children: [new TextRun({ text: txt, font: FONT, size: SZ_BODY, bold: true })],
    })],
  });

  const dataCell = (txt, w) => new TableCell({
    width: { size: w, type: WidthType.DXA },
    margins: { top: 50, bottom: 50, left: 90, right: 90 },
    verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({
      spacing: { line: LINE_15, after: 0 },
      children: [new TextRun({ text: String(txt), font: FONT, size: SZ_BODY })],
    })],
  });

  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map((h, i) => headerCell(h, widths[i])),
  });
  const bodyRows = rows.map(r =>
    new TableRow({ children: r.map((c, i) => dataCell(c, widths[i])) })
  );

  const border = { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER };
  return new Table({
    width: { size: total, type: WidthType.DXA },
    layout: TableLayoutType.FIXED,
    borders: { top: border, bottom: border, left: border, right: border, insideHorizontal: border, insideVertical: border },
    rows: [headerRow, ...bodyRows],
  });
}

// Parrafo de separacion tras una tabla.
function gap(after = 200) {
  return new Paragraph({ spacing: { after }, children: [] });
}

// ===========================================================================
// CONTENIDO DEL DOCUMENTO
// ===========================================================================
const coverChildren = [];  // portada (seccion 1)
const content = [];        // resto del documento (seccion 2)
const C = content;         // alias del cuerpo

// Marcadores de imagen/hueco para el recuento final.
global.__imgCount = 0;
global.__phCount = 0;

// ---------------------------------------------------------------------------
// PORTADA (exacta, segun especificacion)
// ---------------------------------------------------------------------------
function coverLine(text, o = {}) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: o.after != null ? o.after : 120, line: LINE_15, before: o.before || 0 },
    children: [new TextRun({ text, font: FONT, size: o.size || SZ_BODY, bold: o.bold || false, italics: o.italics || false })],
  });
}

coverChildren.push(new Paragraph({ spacing: { after: 480 }, children: [] }));
coverChildren.push(coverLine('Universidad Politécnica de Madrid', { size: 30, bold: true, after: 60 }));
coverChildren.push(coverLine('Escuela Técnica Superior de Ingenieros Informáticos', { size: 24, bold: true, after: 40 }));
coverChildren.push(coverLine('Grado en Ingeniería de Software', { size: 22, after: 800 }));
coverChildren.push(coverLine('Trabajo de Fin de Grado', { size: 26, bold: true, after: 700 }));

coverChildren.push(coverLine('Desarrollo de una Aplicación Móvil Multiplataforma y PWA para la Gestión Integral de un Campus de Baloncesto', { size: 32, bold: true, after: 1000 }));

coverChildren.push(coverLine('Autor: Alberto Rodríguez González  |  BS0103', { size: 24, after: 100 }));
coverChildren.push(coverLine('Tutor: José Ramón Sánchez Couso', { size: 24, after: 600 }));
coverChildren.push(coverLine('Madrid, junio de 2026', { size: 24, before: 700 }));

// ---------------------------------------------------------------------------
// RESUMEN
// ---------------------------------------------------------------------------
C.push(chapterNoNum('Resumen', false)); // primer encabezado del cuerpo: sin salto extra
C.push(body('Este Trabajo de Fin de Grado recoge el diseño, el desarrollo y la puesta en producción de Campus Baloncesto App, una aplicación pensada para llevar la gestión de un campus de baloncesto desde el móvil, desde la tablet o desde el navegador, sin tener que instalar nada distinto en cada dispositivo. El proyecto nace de mi experiencia como entrenador en el campus de baloncesto que se celebra cada verano en Toledo, donde llevo años viendo cómo toda la gestión se hacía con hojas de cálculo, grupos de WhatsApp y papel, y de la voluntad de la propia organización de modernizar el campus y su gestión. La idea de partida era sencilla de enunciar y bastante menos sencilla de construir: reunir en un mismo sitio todo lo que hoy se reparte entre hojas de cálculo sueltas, grupos de mensajería y papeles. Equipos, competiciones, partidos, estadísticas, comunicación con las familias y las actividades más informales del campus, como las siestas o las veladas, pasan a vivir en una única plataforma.'));
C.push(body('En lo técnico, la aplicación está hecha con Flutter y Dart, de manera que una sola base de código se compila para Android, iOS y la web en forma de Progressive Web App. El backend no se programó desde cero: se apoya en Supabase, que aporta una base de datos PostgreSQL, la autenticación y la sincronización en tiempo real, junto con la seguridad a nivel de fila (Row Level Security) directamente en el motor. Las notificaciones push corren por cuenta de Firebase Cloud Messaging y las imágenes se sirven optimizadas desde Cloudinary. La arquitectura sigue las ideas de la Clean Architecture, pero organizada por funcionalidades en lugar de por capas técnicas; el estado se gestiona con Riverpod y la navegación con go_router.'));
C.push(body('De entre todo lo desarrollado, hay dos piezas que me parecen las más representativas. Una es el generador automático de equipos equilibrados, que reparte a los jugadores teniendo en cuenta su nivel, su edad y su posición en pista. La otra son las dos exportaciones del sistema: las competiciones de siesta se exportan a PDF (clasificación y, cuando procede, cuadro de eliminatorias) y la clasificación general de las competiciones por estaciones se exporta a Excel, con una hoja por grupo. El resultado es una aplicación que funciona, que está desplegada y en uso, y que ofrece la misma experiencia con independencia de desde dónde se abra. Su estreno con todos los datos reales llegará en la edición del campus de julio de 2026.'));
C.push(new Paragraph({ spacing: { before: 160, after: 80, line: LINE_15 }, children: [new TextRun({ text: 'Palabras clave: ', font: FONT, size: SZ_BODY, bold: true }), new TextRun({ text: 'Flutter, Dart, Supabase, PWA, baloncesto, aplicación multiplataforma, gestión deportiva, tiempo real, Riverpod, notificaciones push.', font: FONT, size: SZ_BODY })] }));

// ---------------------------------------------------------------------------
// ABSTRACT
// ---------------------------------------------------------------------------
C.push(chapterNoNum('Abstract'));
C.push(body('This Bachelor’s Degree Final Project describes the design, development and deployment of Campus Baloncesto App, an application built to manage a basketball camp from a phone, a tablet or a browser, without having to install something different on every device. The project grew out of my own experience as a coach at the basketball camp held every summer in Toledo, where for years I had seen the whole organisation handled with spreadsheets, WhatsApp groups and paper, and out of the camp organisation’s wish to modernise both its management and its image. The starting idea was easy to state and considerably harder to build: to bring together, in one place, everything that is nowadays scattered across loose spreadsheets, messaging groups and paper. Teams, competitions, matches, statistics, communication with families and the more informal camp activities, such as the nap contests or the evening events, all live now in a single platform.'));
C.push(body('On the technical side, the application is written in Flutter and Dart, so that a single code base compiles to Android, iOS and the web as a Progressive Web App. The backend was not built from scratch: it relies on Supabase, which provides a PostgreSQL database, authentication and real-time synchronisation, together with row-level security enforced directly in the engine. Push notifications are handled by Firebase Cloud Messaging and images are served, already optimised, from Cloudinary. The architecture follows Clean Architecture principles, but organised by feature rather than by technical layer; state is managed with Riverpod and navigation with go_router.'));
C.push(body('Two pieces stand out from everything that was developed. One is the automatic balanced-team generator, which distributes players according to their level, age and on-court position. The other is the pair of export features: nap competitions are exported to PDF (standings and, where applicable, the knockout bracket) and the overall standings of the station-based competitions are exported to Excel, with one sheet per group. The outcome is an application that works, that is deployed and in use, and that offers the same experience regardless of where it is opened from. Its first full run with real data will be the July 2026 edition of the camp.'));
C.push(new Paragraph({ spacing: { before: 160, after: 80, line: LINE_15 }, children: [new TextRun({ text: 'Keywords: ', font: FONT, size: SZ_BODY, bold: true }), new TextRun({ text: 'Flutter, Dart, Supabase, PWA, basketball, cross-platform application, sports management, real-time, Riverpod, push notifications.', font: FONT, size: SZ_BODY })] }));

// ---------------------------------------------------------------------------
// INDICE
// ---------------------------------------------------------------------------
C.push(chapterNoNum('Índice de Contenidos'));
C.push(new TableOfContents('Tabla de contenidos', {
  hyperlink: true,
  headingStyleRange: '1-3',
}));

// ===========================================================================
// CAPITULO 1 - INTRODUCCION
// ===========================================================================
C.push(chapter('1. Introducción'));

C.push(h2('1.1. Contexto y motivación'));
C.push(body('Desde hace varios años participo como entrenador en un campus de baloncesto que se celebra en Toledo durante los primeros días de julio, del 1 al 11. Son jornadas intensas: cada edición junta a cerca de un centenar de chavales de edades y niveles distintos, repartidos en equipos, que durante esos días entrenan, juegan partidos, compiten y, entre medias, hacen vida de campamento. Coordinar todo eso obliga a mover información sin parar entre quienes organizan, los entrenadores, los propios jugadores y sus familias, y a mantener al día clasificaciones, horarios, estadísticas y resultados, que cambian de un momento para otro.'));
C.push(body('Esa gestión se ha venido apoyando en un conjunto de herramientas que no hablan entre sí. Una hoja de cálculo para las clasificaciones. Un grupo de WhatsApp por equipo para avisar de las cosas. Folios impresos para apuntar las estadísticas de cada partido. Y los resultados anotados a mano en una pizarra o una cartulina a la vista de todos. Funciona a duras penas, pero genera errores, duplica trabajo y deja una sensación poco profesional, tanto a los organizadores como a las familias. La información se queda vieja enseguida, las clasificaciones a mano fallan más de lo que uno quisiera y la comunicación por mensajería se vuelve un caos en cuanto hay treinta o cuarenta personas en el grupo.'));
C.push(body('Lo he visto de primera mano edición tras edición. Un coordinador que lleve el campus con varios equipos tiene que mantener a la vez una hoja con los resultados de cada partido, otra con las estadísticas individuales, un grupo de mensajería por equipo y un calendario impreso con las actividades. Cualquier cambio (que se mueva un horario, que haya que corregir un marcador, que llegue un jugador nuevo) le obliga a tocar a mano varios documentos distintos. Es fácil que algo se quede desincronizado. Y las familias, mientras tanto, no tienen un sitio fiable donde seguir lo que hacen sus hijos.'));
C.push(body('A esa experiencia se sumó una necesidad que venía de la propia organización: la de dar un salto informático, modernizar la gestión del campus y, de paso, su imagen. Las dos cosas apuntaban en la misma dirección, así que de ahí salió este proyecto: meter toda esa gestión en una sola aplicación, accesible desde cualquier dispositivo. Que entrenadores, administradores, jugadores y familiares tengan una plataforma común, fácil de usar y actualizada al momento, que cubra desde la formación de los equipos hasta el seguimiento de las estadísticas y la difusión de contenidos. Opté por un enfoque multiplataforma precisamente por la variedad de dispositivos que usa cada perfil: los administradores suelen trabajar desde el ordenador, mientras que entrenadores, jugadores y familias entran casi siempre desde el móvil.'));
C.push(body('El problema, además, no es exclusivo de este campus. Se repite en casi cualquier organización deportiva de base, donde el dinero escasea y la gestión recae muchas veces en gente voluntaria. En ese escenario, las soluciones comerciales de pago suelen quedar grandes, por precio y por complejidad, y las herramientas gratuitas genéricas no encajan con la singularidad de un campus, con sus competiciones por estaciones, sus veladas nocturnas y sus competiciones de siesta. Hacía falta algo sencillo, ágil y barato de mantener.'));
C.push(body('Hubo otro motivo que pesó bastante: la inmediatez. Cuando un padre puede mirar al instante la clasificación de su hijo, las estadísticas del último partido o el entrenamiento del día, la percepción de calidad del campus sube muchísimo. La sincronización en tiempo real y las notificaciones push sirven para mantener informada a toda la comunidad del campus sin que nadie tenga que estar copiando datos a mano.'));
C.push(body('Y, ya en lo personal, me planteé el proyecto como un reto de aprendizaje. Quería recorrer el ciclo completo de un producto software de verdad, desde la captura de requisitos hasta el despliegue en producción, tocando tecnologías que me interesaban: desarrollo multiplataforma, bases de datos relacionales en la nube, seguridad a nivel de fila, mensajería push y distribución como PWA. Esa doble cara, la utilidad real y el aprendizaje, ha condicionado prácticamente todas las decisiones que cuento a lo largo de la memoria.'));
C.push(body('Quiero aclarar también qué entiendo aquí por ' + q('gestión integral') + '. No me refiero a una herramienta que lo haga absolutamente todo, sino a una que cubra de principio a fin el ciclo concreto de este campus: formar los equipos, organizar las competiciones (las deportivas y las lúdicas), seguir los partidos, llevar las estadísticas y comunicarse con la comunidad, sin tener que salir de la aplicación para ninguna de esas tareas. Lo que quede fuera de ese ciclo, como los pagos o la facturación, lo dejé conscientemente para más adelante.'));

C.push(h2('1.2. Objetivos'));
C.push(body('El objetivo general es diseñar y desarrollar una aplicación multiplataforma para la gestión integral de un campus de baloncesto, accesible como app nativa en Android e iOS y como Progressive Web App en navegadores de escritorio y móvil, que sustituya las herramientas manuales por algo unificado, seguro y en tiempo real.'));
C.push(body('De ese objetivo general se desprenden los siguientes objetivos específicos:'));
C.push(bullet('Montar un sistema de autenticación y autorización con seis roles diferenciados: administrador, entrenador, jugador, jugador premium, familiar y visitante.'));
C.push(bullet('Desarrollar la gestión de equipos y la asignación de jugadores, incluyendo un algoritmo que genere equipos equilibrados de forma automática según edad, nivel y posición.'));
C.push(bullet('Gestionar competiciones deportivas con fase de grupos, eliminatorias y veladas, junto con el seguimiento de los partidos en tiempo real.'));
C.push(bullet('Registrar estadísticas individuales y colectivas (puntos, rebotes, asistencias, robos y tapones) y elaborar los rankings de anotador, reboteador, asistente y el MVP.'));
C.push(bullet('Incorporar gamificación mediante logros y un módulo de jugador premium con historial detallado por partido.'));
C.push(bullet('Ofrecer canales de comunicación (blog y tablón de anuncios) y la difusión de entrenamientos multimedia.'));
C.push(bullet('Gestionar las actividades complementarias del campus: competiciones de siesta, con exportación a PDF, y competiciones por estaciones, con exportación a Excel.'));
C.push(bullet('Garantizar la sincronización en tiempo real de los datos entre todos los dispositivos conectados.'));
C.push(bullet('Enviar notificaciones push para avisar de los eventos relevantes del campus.'));
C.push(bullet('Desplegar la aplicación como PWA en Firebase Hosting, asegurando que sea instalable y de acceso público.'));

C.push(h2('1.3. Alcance'));
C.push(body('El proyecto abarca el ciclo completo de desarrollo, desde el análisis de requisitos hasta el despliegue en producción. Entran de lleno en el alcance:'));
C.push(bullet('La autenticación, la gestión de roles y el control de acceso basado en políticas de seguridad a nivel de fila.'));
C.push(bullet('La gestión de equipos y jugadores, con generación automática de equipos equilibrados.'));
C.push(bullet('La organización de competiciones por estaciones, competiciones de siesta y veladas, así como el seguimiento de partidos y el registro de estadísticas.'));
C.push(bullet('Los canales de comunicación (blog y tablón) y la difusión de entrenamientos multimedia.'));
C.push(bullet('Las dos exportaciones: el PDF de las competiciones de siesta y el Excel de la clasificación por estaciones.'));
C.push(bullet('El despliegue como PWA y el envío de notificaciones push.'));
C.push(body('Quedan fuera, por no ser prioritarios para el campus o por no caber en el tiempo disponible, los siguientes puntos:'));
C.push(bullet('La gestión de pagos e inscripciones en línea y la facturación.'));
C.push(bullet('La integración con fichas federativas o con sistemas oficiales de federaciones.'));
C.push(bullet('El streaming de vídeo en directo de los partidos.'));
C.push(bullet('La integración con sistemas externos de terceros distintos de los servicios de backend usados (Supabase, Firebase y Cloudinary).'));
C.push(body('Hay una fecha que marcó el alcance y los plazos de todo: el campus arranca el 1 de julio de 2026. Esa era la meta real e inamovible, así que la planificación se hizo hacia atrás desde ahí, para llegar con la aplicación desplegada y probada antes de que empiece la edición.'));

C.push(h2('1.4. Estructura del documento'));
C.push(body('La memoria se organiza en ocho capítulos, seguidos de las referencias y dos anexos. En resumen:'));
C.push(bullet([run('Capítulo 1. Introducción: ', { bold: true }), run('contexto, motivación, objetivos, alcance, estructura y planificación temporal del proyecto.')]));
C.push(bullet([run('Capítulo 2. Estado del arte: ', { bold: true }), run('soluciones existentes en el mercado, comparativa de frameworks multiplataforma y de servicios de backend, y la justificación de las decisiones tecnológicas.')]));
C.push(bullet([run('Capítulo 3. Análisis de requisitos: ', { bold: true }), run('stakeholders, requisitos funcionales y no funcionales, y los casos de uso más representativos.')]));
C.push(bullet([run('Capítulo 4. Arquitectura y diseño: ', { bold: true }), run('arquitectura del sistema, gestión de estado, enrutamiento, arquitectura PWA, modelo de datos y diseño de seguridad e interfaz.')]));
C.push(bullet([run('Capítulo 5. Implementación: ', { bold: true }), run('la construcción de cada módulo y de las funcionalidades transversales, con capturas de las pantallas.')]));
C.push(bullet([run('Capítulo 6. Pruebas: ', { bold: true }), run('estrategia de pruebas, casos destacados y resultados de rendimiento.')]));
C.push(bullet([run('Capítulo 7. Resultados: ', { bold: true }), run('estado final de los módulos y valoración técnica.')]));
C.push(bullet([run('Capítulo 8. Conclusiones y líneas futuras: ', { bold: true }), run('conclusiones del proyecto y posibles vías de evolución.')]));
C.push(bullet([run('Referencias y anexos: ', { bold: true }), run('la bibliografía, el esquema de la base de datos (Anexo A) y la guía de instalación y despliegue (Anexo B).')]));

C.push(h2('1.5. Planificación del proyecto'));
C.push(body('Para organizar el trabajo elaboré una planificación que va desde el arranque, en diciembre de 2025, hasta la entrega en junio de 2026. La fijé teniendo presente la fecha del campus: como la edición empieza el 1 de julio de 2026, repartí las fases hacia atrás desde ahí para llegar con margen, con la aplicación lista y probada antes de esa fecha. La Figura 1.1 la recoge en forma de diagrama de Gantt, con las fases, las tareas que las componen y cómo se reparten en el tiempo.'));
C.push(body('Dividí el proyecto en tres bloques grandes. El primero, de investigación y estrategia, incluyó el análisis de la competencia, la definición de objetivos, la redacción de los casos de uso y los requisitos, y el diseño preliminar: bocetos y mockups de las pantallas, el modelo conceptual de datos y la arquitectura. El segundo bloque fue el desarrollo propiamente dicho. El tercero, el paso a producción, con el despliegue como PWA en Firebase Hosting y el análisis de los resultados.'));
C.push(body('El desarrollo siguió un enfoque ' + q('front-end first') + '. Construí primero las pantallas con datos de prueba, para validar cuanto antes la experiencia de usuario y la navegación entre vistas. Solo después, a partir de la información que esas pantallas necesitaban de verdad, diseñé la base de datos en Supabase y ya, por último, la capa de backend que conecta la interfaz con la lógica de negocio y la persistencia. Trabajar así me evitó diseñar tablas para datos que luego no usaba. Las pruebas, eso sí, fueron continuas y solapadas con el desarrollo, no una fase aparte al final.'));
C.push(body('La redacción de esta memoria la mantuve en paralelo durante todo el proyecto, documentando cada fase según la iba cerrando.'));
{
  const w = 16.0;
  C.push(...figure('diagrama_gantt.png', w, heightFor(2380, 1379, w),
    'Figura 1.1: Diagrama de Gantt con la planificación temporal del proyecto.'));
}

// ===========================================================================
// CAPITULO 2 - ESTADO DEL ARTE
// ===========================================================================
C.push(chapter('2. Estado del Arte'));

C.push(h2('2.1. Aplicaciones de gestión deportiva'));
C.push(body('Antes de ponerme a programar quise mirar qué había ya hecho. En el mercado hay bastantes aplicaciones de gestión deportiva, unas generalistas y otras pensadas para un deporte concreto. Cubren parte de lo que un campus necesita, pero casi todas se centran en una sola cosa (la comunicación, la estadística o la organización de partidos) y rara vez lo juntan todo en una plataforma con soporte multiplataforma de verdad. Estas son las que me parecieron más representativas.'));
C.push(body('TeamSnap es de las más conocidas para gestionar equipos amateur. Tiene calendarios, listas de asistencia, mensajería interna y la posibilidad de compartir fotos. Su punto fuerte es la coordinación logística del día a día de un equipo. El problema es que su soporte de estadísticas de baloncesto es flojo, no tiene gamificación ni nada parecido a una generación automática de equipos, y no se distribuye como PWA instalable, así que dependes de las apps de cada tienda.'));
C.push(body('GameChanger, más orientada al béisbol y al baloncesto, destaca por el registro estadístico en vivo y por los resúmenes de partido que genera. Está muy volcada en la narración del partido y en el seguimiento por parte de las familias, y no toca la gestión integral de un campus con actividades complementarias, estaciones o veladas. Tampoco trae una construcción equilibrada de equipos ni un sistema de roles como el que yo necesitaba.'));
C.push(body('SportsEngine, del ecosistema de NBC Sports, es una plataforma potente para clubes y federaciones, con módulos de inscripción, pagos y gestión de ligas. Administrativamente es muy capaz, pero su complejidad y su coste la hacen poco apropiada para un campus de verano que dura unos pocos días. Encima, se personaliza poco y no contempla nada parecido a una competición de siesta.'));
C.push(body('Y luego está lo que de verdad usa casi todo el mundo: la combinación de hojas de cálculo (Excel o Google Sheets) con apps de mensajería. Es flexible y no cuesta nada, con el problema de que no escala, no tiene sincronización en tiempo real fiable ni control de acceso por roles, y multiplica los errores manuales. Las clasificaciones hay que recalcularlas a mano, la información se parte entre varios documentos y conversaciones, y nadie te garantiza que todos estén mirando la versión más reciente. Es justamente esta solución improvisada la que Campus Baloncesto App quiere reemplazar.'));
C.push(body('La conclusión que saqué del repaso fue siempre la misma: cada herramienta brilla en lo suyo (TeamSnap en la logística, GameChanger en la estadística en vivo, SportsEngine en la administración de ligas), pero ninguna aborda en conjunto todo lo que pide un campus entendido como un evento intensivo, corto y con un fuerte componente lúdico. Ese hueco es el que da sentido al proyecto.'));

C.push(h2('2.2. Análisis comparativo de aplicaciones'));
C.push(body('La tabla siguiente resume cómo quedan las soluciones analizadas frente a la aplicación desarrollada, mirando criterios como el soporte multiplataforma, el tiempo real, las estadísticas, la gamificación, la disponibilidad como PWA y las exportaciones.'));
C.push(dataTable(
  ['Característica', 'TeamSnap', 'GameChanger', 'SportsEngine', 'Campus Baloncesto App'],
  [
    ['Multiplataforma', 'Sí', 'Sí', 'Parcial', 'Sí (Android, iOS, PWA)'],
    ['Tiempo real', 'Limitado', 'Sí', 'Sí', 'Sí (Supabase Realtime)'],
    ['Estadísticas de baloncesto', 'Básicas', 'Avanzadas', 'Avanzadas', 'Avanzadas (rankings y MVP)'],
    ['Gamificación / logros', 'No', 'No', 'Limitada', 'Sí'],
    ['Generación de equipos', 'No', 'No', 'No', 'Sí (edad/nivel/posición)'],
    ['Disponible como PWA', 'No', 'No', 'No', 'Sí (Firebase Hosting)'],
    ['Exportación', 'PDF', 'PDF', 'PDF', 'PDF (siesta) y Excel (estaciones)'],
    ['Código abierto', 'No', 'No', 'No', 'Sí'],
  ],
  [2400, 1300, 1500, 1500, 2370]
));
C.push(gap());
C.push(body('Ninguna de las analizadas reúne a la vez el soporte multiplataforma completo, el tiempo real, la gamificación y la generación automática de equipos. Campus Baloncesto App se diferencia precisamente por juntar todo eso, y por añadir dos exportaciones pensadas para el contexto concreto del campus.'));

C.push(h2('2.3. Comparativa de frameworks multiplataforma'));
C.push(body('La decisión más determinante de todo el proyecto fue elegir el framework. Comparé las tres opciones más extendidas para desarrollo multiplataforma: Flutter, React Native e Ionic. Buscaba una tecnología capaz de generar, desde una única base de código, apps nativas para Android e iOS y, a la vez, una versión web buena que pudiera distribuirse como PWA.'));
C.push(body('Flutter, de Google y basado en Dart, dibuja su propia interfaz con el motor gráfico Skia, así que se ve y se comporta igual en todas las plataformas. A su favor: buen rendimiento, un catálogo enorme de widgets, el hot reload (que agiliza muchísimo el desarrollo) y un soporte web ya maduro que permite compilar a PWA. En contra: el paquete web inicial pesa más que el de una web tradicional y Dart es menos popular que JavaScript.'));
C.push(body('React Native, mantenido por Meta, usa JavaScript y React y se apoya en componentes nativos a través de un puente. Su gran baza es el ecosistema de JavaScript y que mucha gente ya conoce React. Su inconveniente está en su soporte web (React Native for Web), menos cohesionado, en que la consistencia visual entre plataformas exige más esfuerzo y en que el puente nativo puede penalizar el rendimiento.'));
C.push(body('Ionic tira de tecnologías web (HTML, CSS y JavaScript) dentro de un WebView mediante Capacitor. Si vienes del mundo web, la curva es suave, y por naturaleza encaja con las PWA. Pero al correr sobre un WebView, el rendimiento y la fluidez de las animaciones quedan por debajo de las soluciones que compilan a nativo o renderizan directamente, y se nota en la sensación de ' + q('app nativa') + '.'));
C.push(body('Analizado todo, me decanté por Flutter. Era el que mejor equilibraba rendimiento nativo, consistencia visual entre plataformas y un soporte web suficientemente maduro para una PWA de calidad, todo desde una sola base de código.'));
C.push(dataTable(
  ['Criterio', 'Flutter', 'React Native', 'Ionic'],
  [
    ['Lenguaje', 'Dart', 'JavaScript / TypeScript', 'JavaScript / TypeScript'],
    ['Renderizado', 'Motor propio (Skia / Impeller)', 'Componentes nativos', 'WebView (Capacitor)'],
    ['Rendimiento', 'Alto', 'Medio-alto', 'Medio'],
    ['Soporte PWA', 'Maduro', 'Limitado', 'Nativo del enfoque web'],
    ['Consistencia visual', 'Muy alta', 'Media', 'Alta (web)'],
    ['Curva de aprendizaje', 'Media', 'Media', 'Baja (perfil web)'],
  ],
  [2270, 2300, 2300, 2200]
));
C.push(gap());

C.push(h2('2.4. Comparativa de servicios backend (BaaS)'));
C.push(body('Para la parte de servidor opté por un modelo Backend as a Service, que evita montar y mantener infraestructura propia y da ya hechos la base de datos, la autenticación y la sincronización en tiempo real. Comparé tres: Supabase, Firebase y AWS Amplify.'));
C.push(body('Supabase se presenta como la alternativa de código abierto a Firebase, construida sobre PostgreSQL. Lo que más me atrajo: una base de datos relacional completa con SQL, las políticas de seguridad a nivel de fila integradas en el propio motor, el tiempo real mediante suscripciones a los cambios de las tablas y una autenticación lista para usar. Para un dominio tan relacional como el de un campus (equipos, jugadores, partidos y estadísticas todos enredados entre sí), el modelo de PostgreSQL encajaba a la perfección.'));
C.push(body('Firebase, de Google, ofrece bases de datos NoSQL (Firestore y Realtime Database), autenticación, hosting y mensajería. Es muy madura y rinde muy bien con mucha concurrencia, pero su modelo documental complica las consultas relacionales y la integridad referencial, que aquí eran requisitos centrales. Eso sí, su servicio de mensajería (Firebase Cloud Messaging) y su hosting sí me convencieron para las notificaciones push y para desplegar la PWA.'));
C.push(body('AWS Amplify trae un abanico enorme de servicios sobre la infraestructura de Amazon, con muchísima personalización y escalabilidad. La contrapartida es una configuración considerablemente más compleja y una curva pronunciada, difícil de justificar para el tamaño y la duración de este proyecto.'));
C.push(body('Al final adopté una estrategia mixta: Supabase como backend principal (base de datos, autenticación, tiempo real y RLS), con Firebase Cloud Messaging para las notificaciones, Firebase Hosting para desplegar la PWA y Cloudinary para guardar y servir las imágenes optimizadas.'));

C.push(h2('2.5. Progressive Web Apps y Service Workers'));
C.push(body('Las Progressive Web Apps son aplicaciones web que, usando tecnologías estándar, se acercan bastante a la experiencia de una app nativa: se instalan en el dispositivo, se ejecutan a pantalla completa, funcionan en parte sin conexión y pueden recibir notificaciones. La gran ventaja es que se distribuyen con una simple URL, sin pasar por las tiendas, lo que simplifica enormemente la difusión en un campus.'));
C.push(body('La pieza técnica clave de una PWA es el Service Worker, un script que el navegador ejecuta en segundo plano, al margen de la página, y que hace de proxy programable entre la aplicación y la red. Gracias a él se pueden cachear los recursos estáticos, servirlos sin conexión y atender la recepción de notificaciones push. La otra pieza esencial es el fichero manifest.json, que describe el nombre de la aplicación, los iconos, los colores y el modo de visualización, y que es lo que habilita instalar la PWA en la pantalla de inicio.'));
C.push(body('En este proyecto, la compilación web de Flutter genera de forma automática el Service Worker y el manifiesto, que luego se sirven desde Firebase Hosting. Así, cualquiera puede instalar Campus Baloncesto App directamente desde el navegador, en escritorio o en móvil, y tener un acceso directo equivalente al de una app nativa.'));

C.push(h2('2.6. Justificación de la solución propuesta'));
C.push(body('Con todo lo anterior sobre la mesa, tenía sentido desarrollar una solución propia que cubriera de forma integral las necesidades del campus. Flutter me permite mantener una sola base de código para todas las plataformas, bajando el coste de mantenimiento y asegurando coherencia visual. Supabase como backend gestionado aporta autenticación, base de datos relacional, tiempo real y seguridad a nivel de fila sin tener que administrar servidores.'));
C.push(body('Combinar Supabase con Firebase Cloud Messaging y Firebase Hosting saca lo mejor de cada ecosistema: el modelo relacional y las políticas RLS de Supabase para los datos del dominio, y la solidez de Firebase para las notificaciones y el despliegue. El resultado es un desarrollo ágil, un despliegue sencillo y una propuesta que ninguna de las aplicaciones comerciales analizadas ofrece de forma conjunta.'));
C.push(body('Hay un detalle nada menor: esta combinación abarata el mantenimiento, algo crítico para una organización deportiva de base. Tanto Supabase como Firebase tienen planes gratuitos generosos que cubren de sobra a un campus de verano. Y el hecho de que Supabase sea código abierto elimina el riesgo de quedar atrapado en un proveedor (vendor lock-in): si hiciera falta, el proyecto podría migrarse en el futuro a una instancia de PostgreSQL autoalojada sin reescribir la lógica de datos.'));
C.push(body('Las decisiones tecnológicas, en suma, no salieron de forma aleatoria ni de elegir lo que más me sonaba. Salieron de comparar rendimiento, consistencia multiplataforma, idoneidad del modelo de datos, coste y mantenibilidad a largo plazo. El resto de la memoria cuenta cómo todo eso se convirtió en una arquitectura concreta y en una aplicación que funciona.'));

// ===========================================================================
// CAPITULO 3 - ANALISIS DE REQUISITOS
// ===========================================================================
C.push(chapter('3. Análisis de Requisitos'));

C.push(h2('3.1. Stakeholders'));
C.push(body('El análisis de requisitos partió de mirar de cerca cómo funciona un campus de baloncesto y de anotar las carencias de las herramientas manuales que se venían usando. A partir de ahí identifiqué los perfiles de usuario, sus necesidades y lo que la aplicación tenía que cubrir, y lo ordené en requisitos funcionales y no funcionales, validándolo después con casos de uso.'));
C.push(body('Antes de entrar en los requisitos conviene presentar a los distintos perfiles (los stakeholders), porque de sus necesidades salen tanto los roles del sistema como buena parte de los requisitos funcionales:'));
C.push(bullet([run('Administrador: ', { bold: true }), run('el responsable máximo del campus. Gestiona usuarios y roles, crea equipos y competiciones, configura las actividades y dispone de un dashboard con la visión global.')]));
C.push(bullet([run('Entrenador: ', { bold: true }), run('dirige uno o varios equipos. Registra estadísticas y resultados, publica entrenamientos y consulta clasificaciones y rankings.')]));
C.push(bullet([run('Jugador: ', { bold: true }), run('participante del campus. Consulta sus equipos, sus estadísticas, las clasificaciones, el blog, el tablón y los entrenamientos, y recibe notificaciones.')]));
C.push(bullet([run('Jugador premium: ', { bold: true }), run('un jugador con acceso a un historial detallado de sus estadísticas por partido y a un seguimiento más fino de su rendimiento.')]));
C.push(bullet([run('Familiar: ', { bold: true }), run('allegado de un jugador. Sigue la evolución del campus, las clasificaciones y las publicaciones, y recibe avisos de lo relevante.')]));
C.push(bullet([run('Visitante: ', { bold: true }), run('el rol que se asigna por defecto al registrarse, con acceso limitado a los contenidos públicos hasta que un administrador lo promociona.')]));

C.push(h2('3.2. Requisitos funcionales'));
C.push(body('A continuación enumero los requisitos funcionales detectados, agrupados por módulo y con su prioridad (alta, media o baja). Las prioridades responden a lo crítico que es cada cosa para que el campus funcione: marqué como altas las que sin ellas la aplicación no cumpliría su propósito (autenticación, gestión de equipos y competiciones, registro de estadísticas), como medias las que aportan valor pero no son imprescindibles, y como bajas las complementarias, como las veladas o la gamificación.'));
C.push(dataTable(
  ['Código', 'Requisito', 'Descripción', 'Prioridad'],
  [
    ['RF-01', 'Registro de usuario', 'Registro mediante correo y contraseña, con el rol ' + q('visitante') + ' asignado por defecto a través de un trigger de base de datos.', 'Alta'],
    ['RF-02', 'Autenticación', 'Autenticación de los usuarios registrados, manteniendo la sesión de forma persistente entre ejecuciones.', 'Alta'],
    ['RF-03', 'Gestión de roles', 'Los administradores podrán asignar y modificar los roles entre los seis definidos.', 'Alta'],
    ['RF-04', 'Gestión de perfil', 'Los usuarios podrán consultar y editar su perfil: foto, posición, estatura, edad y nivel.', 'Media'],
    ['RF-05', 'Gestión de equipos', 'Administradores y entrenadores podrán crear, editar y eliminar equipos.', 'Alta'],
    ['RF-06', 'Asignación de jugadores', 'Administradores y entrenadores podrán asignar y retirar jugadores de los equipos.', 'Alta'],
    ['RF-07', 'Generación automática de equipos', 'El sistema generará equipos equilibrados según la edad, el nivel y la posición de cada jugador.', 'Media'],
    ['RF-08', 'Competiciones por estaciones', 'Los administradores podrán crear competiciones por estaciones con sus jornadas y puntuaciones por jugador y día.', 'Alta'],
    ['RF-09', 'Clasificación por estaciones', 'El sistema calculará y mostrará la clasificación general agrupada por grupo.', 'Alta'],
    ['RF-10', 'Competiciones de siesta', 'Gestión de competiciones de siesta en los formatos liga/grupos con playoffs, individual/escalera diaria y tiros libres seguidos.', 'Media'],
    ['RF-11', 'Cuadro de eliminatorias', 'Generación del cuadro de eliminatorias (octavos, cuartos, semifinal y final) en las competiciones de siesta con playoffs.', 'Media'],
    ['RF-12', 'Veladas', 'Gestión de veladas con grupos, capitanes y ganadores.', 'Baja'],
    ['RF-13', 'Partidos en tiempo real', 'El marcador y los eventos de los partidos se reflejarán en tiempo real mediante WebSockets.', 'Alta'],
    ['RF-14', 'Registro de estadísticas', 'Registro de puntos, rebotes, asistencias, robos y tapones por jugador y partido.', 'Alta'],
    ['RF-15', 'Rankings y MVP', 'Cálculo de los rankings de anotador, reboteador y asistente, y designación del MVP.', 'Media'],
    ['RF-16', 'Exportación PDF de siesta', 'Administradores y entrenadores podrán exportar a PDF la clasificación y, en su caso, el cuadro de eliminatorias de una competición de siesta mediante SiestaExportService.', 'Media'],
    ['RF-17', 'Exportación Excel', 'La clasificación general de las competiciones por estaciones podrá exportarse a un archivo Excel (.xlsx) con una hoja por grupo mediante ExportService.', 'Media'],
    ['RF-18', 'Logros y gamificación', 'El sistema otorgará logros en función del desempeño deportivo.', 'Baja'],
    ['RF-19', 'Jugador premium', 'Los jugadores premium dispondrán de un historial detallado de sus estadísticas por partido.', 'Media'],
    ['RF-20', 'Blog', 'Los usuarios autorizados podrán publicar, editar y eliminar entradas en el blog.', 'Media'],
    ['RF-21', 'Tablón de anuncios', 'Los usuarios autorizados podrán publicar avisos en el tablón.', 'Media'],
    ['RF-22', 'Entrenamientos multimedia', 'Publicación y consulta de entrenamientos con contenido multimedia (texto, imágenes y vídeo).', 'Media'],
    ['RF-23', 'Notificaciones push', 'Envío de notificaciones push mediante Firebase Cloud Messaging, sin generar duplicados.', 'Media'],
    ['RF-24', 'Tokens de dispositivo', 'Registro y mantenimiento de los tokens de los dispositivos en las tablas fcm_tokens y device_tokens.', 'Media'],
    ['RF-25', 'Dashboard de administración', 'Panel con la visión global del estado del campus para los administradores.', 'Media'],
    ['RF-26', 'Subida de imágenes', 'Subida y muestra de imágenes optimizadas a través de Cloudinary.', 'Baja'],
    ['RF-27', 'Instalación como PWA', 'La aplicación podrá instalarse como PWA desde el navegador en escritorio y móvil.', 'Media'],
    ['RF-28', 'Funcionamiento offline parcial', 'La PWA cacheará sus recursos estáticos mediante un Service Worker para funcionar parcialmente sin conexión.', 'Baja'],
  ],
  [1100, 1900, 4670, 1400]
));
C.push(gap());

C.push(h2('3.3. Requisitos no funcionales'));
C.push(body('Los requisitos no funcionales fijan las cualidades del sistema: rendimiento, seguridad, usabilidad, escalabilidad, portabilidad y disponibilidad. Si los funcionales dicen qué debe hacer la aplicación, estos dicen cómo debe hacerlo, y son en buena medida los criterios contra los que se mide el éxito. Su cumplimiento se comprueba en el capítulo de pruebas con mediciones concretas y validaciones en varias plataformas.'));
C.push(dataTable(
  ['Código', 'Requisito', 'Descripción'],
  [
    ['RNF-01', 'Portabilidad', 'La aplicación deberá ejecutarse en Android, iOS y la Web (PWA) a partir de una única base de código.'],
    ['RNF-02', 'Rendimiento', 'Las pantallas principales deberán cargarse en menos de dos segundos en condiciones normales de red.'],
    ['RNF-03', 'Seguridad', 'El acceso a los datos estará protegido mediante autenticación y políticas de seguridad a nivel de fila (RLS) según el rol.'],
    ['RNF-04', 'Usabilidad', 'La interfaz seguirá Material Design 3 y será coherente e intuitiva en todas las plataformas.'],
    ['RNF-05', 'Escalabilidad', 'La arquitectura permitirá incorporar nuevos módulos sin afectar a los existentes.'],
    ['RNF-06', 'Disponibilidad', 'La PWA estará disponible públicamente de forma continua mediante Firebase Hosting.'],
    ['RNF-07', 'Mantenibilidad', 'El código seguirá los principios de la Clean Architecture organizada por funcionalidades.'],
    ['RNF-08', 'Tiempo real', 'Las actualizaciones de marcadores y estadísticas se propagarán a los clientes suscritos en menos de un segundo.'],
  ],
  [1300, 2000, 5770]
));
C.push(gap());

C.push(h2('3.4. Casos de uso'));
C.push(body('Identifiqué los casos de uso principales asociados a cada rol. La Figura 3.1 los recoge de forma global, relacionando cada actor con las funcionalidades a las que accede. A continuación describo los más representativos.'));
{
  const w = 14.0;
  C.push(...figure('casos_uso.png', w, heightFor(1920, 1600, w),
    'Figura 3.1: Diagrama de casos de uso del sistema.'));
}
C.push(h3('CU-01: Generación automática de equipos'));
C.push(body('Actor principal: administrador o entrenador. Precondición: hay jugadores registrados con su edad, nivel y posición. El actor entra en la gestión de equipos, elige la generación automática e indica cuántos equipos quiere. El sistema recupera la lista de jugadores disponibles y aplica el algoritmo de equilibrado, que reparte procurando igualar la media de nivel y de edad y distribuir las posiciones. El actor revisa la propuesta y la confirma, y los equipos quedan guardados. Postcondición: los equipos quedan creados con sus jugadores asignados.'));
C.push(h3('CU-02: Seguimiento de partido en tiempo real'));
C.push(body('Actor principal: entrenador. Precondición: existe un partido programado. El entrenador abre un partido en curso y va registrando los eventos (puntos, faltas, rebotes, asistencias). Gracias al tiempo real de Supabase, el marcador y las estadísticas se actualizan al instante en los dispositivos de todos los que estén viendo ese mismo partido. Postcondición: las estadísticas quedan registradas y reflejadas en los rankings.'));
C.push(h3('CU-03: Exportación de clasificaciones'));
C.push(body('Este caso recoge las dos únicas vías de exportación de la aplicación.'));
C.push(body([run('Flujo (a) — PDF de siesta. ', { bold: true }), run('Un entrenador abre una competición de siesta y, desde la pantalla de clasificación, pulsa el botón de exportar PDF. El servicio SiestaExportService genera un documento con la clasificación y, si la hay, el cuadro de eliminatorias. En la web se abre el diálogo del navegador para guardar el PDF; en móvil aparece la vista previa de impresión o el menú de compartir.')]));
C.push(body([run('Flujo (b) — Excel de estaciones. ', { bold: true }), run('Un administrador entra en la clasificación general de las competiciones por estaciones y pide la exportación a Excel. El servicio ExportService produce un archivo .xlsx con una hoja por grupo, en la que figuran las puntuaciones de cada jugador por día y el total. Postcondición: el usuario obtiene el documento en su dispositivo.')]));
C.push(h3('CU-04: Gestión de roles'));
C.push(body('Actor principal: administrador. Entra en el dashboard de administración, localiza a un usuario ' + q('visitante') + ' recién registrado y le asigna el rol que toque (jugador, entrenador, familiar o jugador premium). El sistema actualiza el rol en la tabla users y, por las políticas de RLS, el usuario pasa a disponer de los permisos de su nuevo rol. Postcondición: el usuario accede a las funcionalidades propias de su rol.'));
C.push(h3('CU-05: Publicación de un entrenamiento multimedia'));
C.push(body('Actor principal: entrenador. Entra en el módulo de entrenamientos y crea una entrada con título, descripción y contenido multimedia (imágenes en Cloudinary o enlaces de vídeo). Al guardar, el sistema almacena el entrenamiento y, si así se decide, dispara una notificación push a jugadores y familiares. Postcondición: el entrenamiento queda disponible para quien tenga permiso de consulta.'));

// ===========================================================================
// CAPITULO 4 - ARQUITECTURA Y DISENO
// ===========================================================================
C.push(chapter('4. Arquitectura y Diseño'));

C.push(h2('4.1. Visión general y Clean Architecture'));
C.push(body('La aplicación sigue una Clean Architecture, pero organizada por funcionalidades (feature-based) en vez de por tipo técnico. En lugar de tener una carpeta con todos los modelos, otra con todas las pantallas y así, cada módulo del dominio guarda sus propias capas de presentación, lógica de negocio y acceso a datos. Esto favorece la separación de responsabilidades, la cohesión y el mantenimiento. En la práctica, significa que puedo trabajar sobre, pongamos, las competiciones de siesta sin tener que pasearme por todo el proyecto. La Figura 4.1 muestra esta disposición en capas.'));
{
  const w = 10.5;
  C.push(...figure('arquitectura.png', w, heightFor(1532, 1754, w),
    'Figura 4.1: Arquitectura del sistema basada en Clean Architecture.'));
}
C.push(body('El flujo de información va así: capa de presentación (un ConsumerWidget con GoRouter) → proveedores de estado (Riverpod) → repositorios → fuentes de datos (Supabase y Firebase). La presentación se construye con widgets reactivos que observan los proveedores. Esos proveedores, casi todos implementados como AsyncNotifier, coordinan la lógica y delegan el acceso a datos en los repositorios. Y los repositorios abstraen las llamadas a Supabase (PostgreSQL, autenticación, tiempo real y RLS) y a los servicios externos, de modo que la presentación queda desacoplada de la infraestructura.'));
C.push(body('Esta separación en capas tiene una ventaja muy práctica de cara a las pruebas: como la presentación depende de abstracciones y no de implementaciones concretas, puedo cambiar un repositorio real por uno simulado en las pruebas unitarias y verificar la lógica de negocio aislada.'));
C.push(body('Frente a la organización clásica por capas técnicas, la organización por funcionalidades me dio dos beneficios claros en un proyecto de este tamaño. Maximiza la cohesión, porque todo lo de un dominio vive en el mismo sitio y lo encuentro rápido, con poco acoplamiento entre módulos que no tienen nada que ver. Y facilita crecer: añadir una funcionalidad nueva es básicamente añadir un módulo autocontenido, sin andar tocando carpetas técnicas que comparte medio proyecto.'));
C.push(body('Los principios de la Clean Architecture (la regla de dependencia, según la cual las capas externas dependen de las internas y nunca al revés, y la inversión de dependencias mediante abstracciones) se traducen en que el dominio y la lógica de negocio no saben nada de Supabase ni de Flutter. Un eventual cambio de proveedor de backend o de framework de interfaz tendría un impacto acotado a las capas externas, sin propagarse al núcleo de reglas.'));
C.push(dataTable(
  ['Capa', 'Tecnología / Componente', 'Responsabilidad'],
  [
    ['Presentación', 'ConsumerWidget, GoRouter, Material Design 3', 'Renderizado de la interfaz y navegación declarativa.'],
    ['Estado', 'flutter_riverpod (AsyncNotifier)', 'Gestión reactiva del estado y la lógica de presentación.'],
    ['Dominio / Datos', 'Repositorios', 'Abstracción del acceso a datos y reglas de negocio.'],
    ['Infraestructura', 'Supabase, Firebase, Cloudinary', 'Persistencia, autenticación, tiempo real y servicios externos.'],
  ],
  [1900, 3200, 3970]
));
C.push(gap());

C.push(h2('4.2. Gestión de estado con Riverpod'));
C.push(body('El estado lo resolví con Riverpod en su versión 3. Aporta seguridad en tiempo de compilación, no depende del árbol de widgets y compone de maravilla. Frente al InheritedWidget clásico o al uso de Provider, Riverpod elimina los errores en tiempo de ejecución asociados al contexto y deja declarar los proveedores de forma global y tipada.'));
C.push(body('El proyecto se apoya sobre todo en proveedores de tipo AsyncNotifier, ideales para estados asíncronos que arrancan en ' + q('cargando') + ', evolucionan a ' + q('datos') + ' o a ' + q('error') + ' y pueden refrescarse o mutarse. Cada dominio define los suyos: hay proveedores específicos para los equipos, para las competiciones de siesta, para las estaciones, para las estadísticas, para las notificaciones. Esa segmentación por dominio refuerza la modularidad de la arquitectura.'));
C.push(body('Los widgets de presentación, que son ConsumerWidget, observan esos proveedores con ref.watch y reaccionan solos a los cambios, mostrando el indicador de carga, los datos o el mensaje de error según toque. Las acciones del usuario se canalizan con ref.read, que invoca los métodos del notifier responsable de la lógica.'));
C.push(body('Lo que más me gustó de los AsyncNotifier es el modelo unificado de estado que ofrece el tipo AsyncValue, capaz de representar de forma explícita los tres estados de una operación (cargando, con datos o con error) y de obligar a la presentación a contemplarlos todos. Este patrón elimina toda una familia de fallos típicos, como pintar datos que aún no han llegado o no manejar bien un error de red, y deja una interfaz más fiable y predecible.'));
C.push(body('La composición de proveedores es otra baza importante: un proveedor puede depender de otros con ref.watch, así que, por ejemplo, el de clasificación observa al de partidos y se recalcula solo cuando estos cambian. Esta reactividad encadenada permite expresar relaciones complejas entre datos de forma declarativa, sin tener que orquestar las actualizaciones a mano, lo que reduce un montón de código de coordinación y las inconsistencias.'));

C.push(h2('4.3. Enrutamiento con GoRouter'));
C.push(body('La navegación se gestiona de forma declarativa con go_router, que define un mapa de rutas asociadas a las pantallas. La Figura 4.3 muestra ese mapa. En una aplicación multiplataforma con versión PWA esto es especialmente útil, porque las rutas se reflejan en la URL del navegador, lo que habilita los enlaces directos (deep linking) y el uso de los botones de atrás y adelante del propio navegador. Las rutas se declaran en lib/core/router/app_router.dart, donde, por ejemplo, /siesta/league/:id abre la pantalla de una liga concreta a partir de su identificador.'));
C.push(body('Sobre go_router hay guardas de navegación (redirect) que controlan el acceso según el estado de autenticación. Un usuario sin sesión que vaya a una ruta de login o registro estando ya autenticado es reconducido a la pantalla principal. La función de redirección se reevalúa de forma reactiva ante los cambios de autenticación gracias a un GoRouterRefreshStream que escucha onAuthStateChange de Supabase; cuando el usuario inicia o cierra sesión, el router reacciona solo y reconduce la navegación, sin tener que gestionar transiciones desde cada pantalla.'));
C.push(body('Hay que insistir en una cosa: estas guardas no son la única barrera de seguridad, sino una capa de comodidad que evita enseñar pantallas a las que el usuario no debería llegar. La autorización de verdad sobre los datos vive en las políticas de RLS de la base de datos, así que, aunque alguien lograra saltarse las guardas del cliente, el backend rechazaría cualquier operación no permitida. Esta defensa en profundidad es uno de los principios del diseño de seguridad del proyecto.'));
{
  const w = 16.0;
  C.push(...figure('navegacion.png', w, heightFor(2075, 1369, w),
    'Figura 4.3: Mapa de navegación de la aplicación.'));
}

C.push(h2('4.4. Arquitectura PWA'));
C.push(body('La versión web se compila con Flutter Web y se publica como Progressive Web App. La arquitectura PWA descansa sobre dos artefactos que genera la compilación: el Service Worker, que cachea los recursos estáticos (HTML, CSS, JavaScript y assets) y los sirve incluso sin conexión, y el manifest.json, que describe los metadatos para la instalación (nombre, iconos, colores y modo de visualización).'));
C.push(body('Conviene detenerse en cómo se dibuja realmente esa interfaz, porque Flutter no se apoya en los componentes nativos del sistema: pinta él mismo cada elemento de la pantalla sobre un lienzo. El motor encargado de ese pintado es Skia, la biblioteca gráfica 2D de Google. En la versión web esto tiene una consecuencia muy concreta: la compilación incluye Skia portado a WebAssembly (los ficheros canvaskit.wasm y skwasm.wasm que aparecen en build/web), de modo que la PWA renderiza su interfaz con Skia ejecutándose dentro del propio navegador. La ventaja es que el resultado se ve igual que en las versiones nativas y no queda dependiendo de cómo dibuje cada navegador; el precio es una descarga inicial algo mayor, ya que el cliente tiene que traerse ese motor la primera vez. En ningún momento tuve que tocar Skia de forma directa: yo trabajo siempre con widgets de Flutter y es el framework quien delega el pintado en el motor. En las versiones nativas, en cambio, Flutter emplea por defecto su motor Impeller, quedando Skia como alternativa de respaldo.'));
C.push(body('El despliegue va sobre Firebase Hosting, que sirve los artefactos a través de una CDN con HTTPS. Así, la aplicación es instalable desde el navegador en escritorio y en móvil, con una experiencia equivalente a la de una app nativa y sin pasar por las tiendas.'));
C.push(body('La PWA aporta ventajas operativas decisivas en un campus. La actualización es inmediata y transparente: con desplegar una versión nueva en Firebase Hosting, todos reciben las novedades en su siguiente visita, sin esperar a la revisión de las tiendas ni depender de que cada uno actualice a mano. Y la ausencia de fricción para instalar (un simple enlace) facilita mucho que la use más gente entre jugadores y familias, un público que no siempre tiene interés en buscar e instalar una app nativa.'));
C.push(body('Eso sí, el modelo PWA trae algunas pegas. El soporte de notificaciones push en la web depende del Service Worker y cambia entre navegadores y plataformas, lo que me obligó a tratar ese entorno de forma específica. Y la estrategia de caché del Service Worker tiene que equilibrar el funcionamiento sin conexión con la necesidad de servir siempre la última versión, evitando que una caché demasiado agresiva se quede con versiones viejas. De hecho, esto último me dio bastantes problemas durante los despliegues, como cuento en el Anexo B.'));

C.push(h2('4.5. Modelo de datos'));
C.push(body('El modelo de datos se materializa en una base de datos PostgreSQL gestionada por Supabase, con políticas de Row Level Security que restringen el acceso según el rol. El diseño es marcadamente relacional, con tablas de entidad y tablas de relación que reflejan los vínculos entre usuarios, equipos, competiciones y estadísticas. La Figura 4.2 representa las entidades principales y sus relaciones.'));
{
  const w = 16.0;
  C.push(...figure('modelo_datos.png', w, heightFor(2437, 1523, w),
    'Figura 4.2: Modelo de datos con las principales entidades y relaciones.'));
}
C.push(body('La decisión de optar por un modelo relacional bien normalizado, en vez de uno documental, se justifica por la naturaleza tan conectada del dominio. Un jugador pertenece a equipos, juega partidos, acumula estadísticas y puntuaciones, y participa en competiciones de varios tipos; todo eso se expresa con naturalidad mediante claves foráneas y tablas de unión, y permite consultas analíticas (rankings, clasificaciones, históricos) que sobre un almacén de documentos serían mucho más costosas. PostgreSQL aporta, encima, integridad referencial, transacciones y un SQL maduro. A continuación describo las tablas principales.'));
C.push(dataTable(
  ['Tabla', 'Descripción'],
  [
    ['users', 'Usuarios del sistema, con su rol, nombre, apellidos, foto, posición, estatura, edad y nivel.'],
    ['teams', 'Equipos del campus.'],
    ['team_members', 'Relación N:M entre equipos y jugadores.'],
    ['trainings', 'Entrenamientos multimedia publicados por los entrenadores.'],
    ['blog_posts', 'Entradas del blog del campus.'],
    ['tablon_posts', 'Avisos publicados en el tablón de anuncios.'],
    ['fcm_tokens', 'Tokens de Firebase Cloud Messaging asociados a cada usuario para las notificaciones push.'],
    ['device_tokens', 'Tokens de dispositivo complementarios para el envío de notificaciones.'],
    ['stations', 'Estaciones de las competiciones por estaciones.'],
    ['station_days', 'Jornadas o días de las competiciones por estaciones.'],
    ['station_scores', 'Puntuaciones por estación, jugador y día.'],
    ['siesta_competitions', 'Competiciones de siesta, con su juego, formato y estado.'],
    ['siesta_participants', 'Participantes de las competiciones de siesta, con puntos de liga, partidos jugados, ganados, perdidos y grupo.'],
    ['siesta_matches', 'Partidos de las competiciones de siesta, con participantes, resultados, ronda y estado.'],
    ['siesta_daily_scores', 'Puntuaciones diarias de los formatos de escalera diaria.'],
    ['veladas', 'Veladas nocturnas del campus.'],
    ['velada_groups', 'Grupos que participan en cada velada.'],
    ['velada_group_members', 'Miembros de cada grupo de velada, con sus capitanes.'],
    ['player_match_stats', 'Estadísticas detalladas por jugador y partido (puntos, rebotes, asistencias, robos, tapones y MVP).'],
  ],
  [2600, 6470]
));
C.push(gap());
C.push(body('Hay también un par de tablas legacy en desuso (competitions, matches y statistics) que en una refactorización posterior quedaron sustituidas por station_scores y player_match_stats, y que mantengo solo por compatibilidad histórica. El esquema detallado, con sus campos y el trigger asociado, está en el Anexo A.'));

C.push(h2('4.6. Diseño de seguridad y roles'));
C.push(body('El sistema define seis roles: administrador, entrenador, jugador, jugador premium, familiar y visitante. La seguridad se sostiene sobre dos pilares: la autenticación que gestiona Supabase Auth y las políticas de Row Level Security definidas directamente en PostgreSQL.'));
C.push(body('Cuando se registra un usuario nuevo, el trigger on_auth_user_created invoca la función handle_new_user(), que crea automáticamente su fila en la tabla users con el rol ' + q('visitante') + ' por defecto. A partir de ahí, un administrador puede promocionarlo. Las políticas de RLS, aplicadas fila a fila en cada tabla, hacen que cada usuario solo pueda leer o modificar lo que le corresponde según su rol: un jugador consulta las clasificaciones pero no crea competiciones, mientras que un administrador tiene acceso completo.'));
C.push(body('Este planteamiento mete la lógica de autorización en la propia base de datos, de manera que la seguridad no depende solo del cliente y se mantiene aunque alguien acceda directamente a la API.'));
C.push(body('La Row Level Security de PostgreSQL es, para mí, una de las piezas más valiosas de la arquitectura. Cada política es una expresión booleana que el motor evalúa para cada fila en cada operación, decidiendo si el usuario autenticado puede leerla o modificarla. Como esa comprobación vive en el servidor, ningún cliente, por muy trucado que esté, puede sortearla, lo que da una garantía muy superior a la de validar permisos solo en la aplicación. Supabase integra esto con su autenticación, así que las políticas pueden referirse directamente al identificador y a los atributos del usuario en sesión.'));
C.push(body('El diseño de los seis roles busca un punto medio entre granularidad y simplicidad. Cada rol agrupa un conjunto coherente de permisos acorde con lo que de verdad hace ese perfil en el campus, evitando tanto la rigidez de un único rol administrativo como la complejidad inmanejable de un esquema de permisos hiperdetallado. El rol ' + q('visitante') + ', el de por defecto, materializa el principio de mínimo privilegio: el recién llegado solo ve contenidos públicos hasta que un administrador, de forma deliberada, le da más capacidades.'));

C.push(h2('4.7. Diseño de interfaz con Material Design 3'));
C.push(body('La interfaz sigue Material Design 3 (Material You), el sistema de diseño de Google, que aporta una estética moderna, accesible y coherente. Usar los componentes de Material que Flutter trae integrados asegura una apariencia uniforme en Android, iOS y la web, además de cumplir buenas prácticas de accesibilidad en contraste, tamaños táctiles y jerarquía visual.'));
C.push(body('El diseño es responsive, de modo que las pantallas se adaptan tanto a la vertical de un móvil como a las pantallas anchas de un ordenador en la versión PWA. La paleta de colores, la tipografía y los iconos se definen de forma centralizada en un tema, lo que facilita mantener la coherencia y, llegado el caso, cambiar la marca.'));
C.push(body('El reto del responsive fue especialmente serio aquí por lo dispares que son los contextos de uso entre roles. Las pantallas con tablas densas (clasificaciones, estadísticas, listados de usuarios) hubo que cuidarlas para que se leyeran bien tanto en la estrechez de un móvil como en la amplitud de un monitor. Para eso usé los widgets adaptativos de Flutter, que reorganizan los elementos según el espacio disponible, de manera que ninguna funcionalidad quede inaccesible o ilegible en ninguna plataforma.'));
C.push(body('Elegir Material Design 3 no fue solo por estética. También por productividad y calidad. Apoyarme en un sistema de diseño consolidado y en los componentes nativos de Flutter reduce el esfuerzo de construir la interfaz, hereda buenas prácticas de accesibilidad y ofrece a la gente una experiencia familiar, alineada con lo que ya conocen de otras apps.'));
{
  const w = 16.0;
  C.push(...figure('despliegue.png', w, heightFor(1765, 1369, w),
    'Figura 4.4: Diagrama de despliegue.'));
}

// ===========================================================================
// CAPITULO 5 - IMPLEMENTACION
// ===========================================================================
C.push(chapter('5. Implementación'));

C.push(h2('5.1. Stack tecnológico'));
C.push(body('La implementación se apoya en el conjunto de tecnologías y librerías que recojo en la tabla, elegidas conforme a la justificación del Capítulo 2. Las dependencias se gestionan desde el fichero pubspec.yaml de Flutter, que fija las versiones de cada paquete y permite reproducir el entorno de compilación de forma determinista. Para escoger cada librería miré su madurez, su mantenimiento, su popularidad en la comunidad y, sobre todo, que encajara con la necesidad concreta, evitando arrastrar dependencias de más que luego hubiera que mantener.'));
C.push(dataTable(
  ['Tecnología / Librería', 'Versión', 'Función'],
  [
    ['Flutter / Dart', '3.x / ^3.11.1', 'Framework multiplataforma (Android, iOS, PWA).'],
    ['supabase_flutter', '^2.12.0', 'Backend: PostgreSQL, autenticación, tiempo real y RLS.'],
    ['firebase_messaging', '^16.2.0', 'Notificaciones push (Firebase Cloud Messaging).'],
    ['flutter_riverpod', '^3.3.1', 'Gestión de estado reactiva (AsyncNotifier).'],
    ['go_router', '^17.1.0', 'Navegación declarativa.'],
    ['pdf / printing', '^3.11.3 / ^5.14.2', 'Generación del PDF de las clasificaciones de siesta.'],
    ['excel', '^4.0.6', 'Exportación a Excel de la clasificación por estaciones.'],
    ['Cloudinary', '—', 'Almacenamiento y entrega optimizada de imágenes.'],
    ['google_fonts, cached_network_image, image_picker', '—', 'Tipografías, caché de imágenes y selección multimedia.'],
    ['carousel_slider, share_plus, path_provider', '—', 'Carruseles, compartición y acceso al sistema de archivos.'],
  ],
  [3100, 1900, 4070]
));
C.push(gap());

C.push(h2('5.2. Metodología y entorno de desarrollo'));
C.push(body('Desarrollé de forma iterativa e incremental, alrededor de los módulos identificados en el análisis. En cada iteración cogía un módulo, o un grupo de funcionalidades relacionadas, y cerraba su ciclo de diseño, implementación y prueba antes de meterme con el siguiente. Así tuve versiones funcionales desde fases tempranas y pude validar las decisiones de arquitectura sobre casos reales en lugar de sobre suposiciones.'));
C.push(body('El control de versiones lo llevé con Git, con el repositorio en GitHub. Eso me dio un historial completo de la evolución y la posibilidad de revertir o de trabajar en ramas para funcionalidades concretas. Los mensajes de commit documentan los hitos: desde la implementación del algoritmo táctico de generación de equipos equilibrados hasta la corrección de las notificaciones duplicadas o la incorporación de la clasificación, las veladas y las siestas.'));
C.push(body('El entorno de desarrollo se apoyó en las herramientas del ecosistema Flutter, en particular el hot reload, que acelera muchísimo el ciclo de prueba y error: refleja los cambios en cuestión de segundos sin perder el estado de la aplicación. La depuración multiplataforma la hice en emuladores y dispositivos físicos Android e iOS, y también en el navegador para la versión PWA, cubriendo así los distintos entornos de ejecución a lo largo de todo el desarrollo.'));

C.push(h2('5.3. Autenticación y roles'));
C.push(body('El módulo de autenticación se apoya en Supabase Auth para el registro y el inicio de sesión con correo y contraseña. El estado de la sesión se expone a la aplicación mediante un proveedor de Riverpod que escucha los cambios de autenticación de Supabase y avisa a la presentación, lo que permite a go_router redirigir según el estado. La sesión se mantiene persistente entre ejecuciones gracias al almacenamiento seguro del token.'));
C.push(body('La asignación inicial del rol se hace en el servidor, con el trigger handle_new_user(), de manera que ningún usuario se queda sin rol y el valor por defecto es siempre el más restrictivo (' + q('visitante') + '). La gestión posterior se concentra en el dashboard de administración, donde un repositorio específico actualiza el campo role de la tabla users. El control de acceso se aplica de forma combinada en las guardas de go_router y en las políticas de RLS.'));
C.push(body('Delegar la creación de la fila de usuario en un trigger de base de datos, en lugar de hacerlo desde el cliente, fue una decisión consciente de fiabilidad: la inicialización crítica se ejecuta de forma atómica e inviolable en el servidor, da igual desde qué plataforma se registre el usuario o que el cliente falle a media operación. Con esto evito el estado inconsistente clásico, ese en el que un usuario existe en el sistema de autenticación pero no en la tabla de perfiles del dominio.'));
C.push(body('El proveedor de autenticación expone, además del estado de sesión, los datos del perfil activo (rol incluido), así que la presentación adapta la interfaz al vuelo: oculta las opciones de administración a quien no tiene permisos, enseña el historial detallado solo a los jugadores premium o habilita la publicación de entrenamientos únicamente a los entrenadores. Esta adaptación al rol mejora la usabilidad y refuerza, en el cliente, lo que el backend ya impone por RLS.'));
C.push(...placeholder('Figura 5.1: Pantalla de bienvenida (Home) del campus.'));
C.push(...placeholder('Figura 5.2: Pantallas de inicio de sesión y registro.'));
C.push(...placeholder('Figura 5.3: Perfil de usuario.'));
C.push(...placeholder('Figura 5.7: Panel de administración de usuarios y roles.'));

C.push(h2('5.4. Gestión de equipos'));
C.push(body('Este módulo permite a administradores y entrenadores crear equipos y asignar jugadores. La capa de datos se apoya en un repositorio que opera sobre las tablas teams y team_members, y la lógica se expone con proveedores de Riverpod que mantienen el listado de equipos y sus miembros sincronizado con la base de datos.'));
C.push(body('La pantalla de detalle de un equipo muestra a sus jugadores junto con sus atributos relevantes (edad, posición y nivel), información que también aparece en el popup de selección de jugadores para facilitar las decisiones de composición. La edición del nivel de un jugador se integra en este flujo, porque ese atributo es determinante para el algoritmo de generación de equipos.'));
C.push(body('La relación entre equipos y jugadores se modela como una asociación de muchos a muchos a través de la tabla intermedia team_members, lo que permite, en principio, que un jugador pertenezca a varios equipos en contextos distintos. Las operaciones de asignación y retirada se ejecutan sobre esa tabla y los proveedores de Riverpod refrescan automáticamente las vistas afectadas, de modo que el cambio se ve al momento en la interfaz y la composición se mantiene siempre coherente entre la base de datos y todas las pantallas que la muestran.'));
C.push(...placeholder('Figura 5.6: Gestión de equipos.'));

C.push(h2('5.5. Generación automática de equipos'));
C.push(body('El generador automático de equipos es una de las aportaciones más relevantes del proyecto, y tiene un planteamiento táctico. El algoritmo, implementado en groups_repository.dart dentro del método autoGenerateBalancedTeams, parte de la lista de jugadores disponibles y de sus atributos de edad, nivel y posición. Lo primero que hace es repartir a los jugadores en tres bloques según su posición: bases y escoltas (guards), pívots y ala-pívots (centers), y aleros u otros sin definir (forwards).'));
C.push(body('A cada jugador le asigna una puntuación de fuerza con una fórmula sencilla: el nivel pesa diez veces más que la edad, es decir, nivel × 10 + edad. Con esa puntuación ordena cada bloque de más fuerte a más débil. Después distribuye bloque por bloque (primero los pívots, luego las bases y por último los aleros), y dentro de cada bloque va colocando a cada jugador en el equipo que en ese momento tenga menos fuerza acumulada. Es, en esencia, una asignación voraz (greedy) que va compensando los equipos a medida que reparte.'));
C.push(body('El problema de fondo es uno de partición equilibrada: repartir un conjunto heterogéneo en subconjuntos de modo que sus características agregadas queden lo más parecidas posible. Una asignación al azar daría con frecuencia equipos descompensados, y una optimización exhaustiva sería carísima de calcular. La heurística voraz por bloques de posición es eficiente y suficientemente buena para el tamaño de los grupos que se manejan en un campus, y se ejecuta en tiempo lineal.'));
C.push(body('Reparto primero por posición, y no únicamente por nivel, a propósito: un equipo formado entero por gente de la misma posición estaría descompensado en pista. Por eso el algoritmo coloca primero a los pívots (que suelen ser los más escasos), luego a las bases y por último a los aleros, equilibrando la fuerza en cada pasada. La edad entra ponderada en la puntuación porque también influye en la competitividad y en la convivencia, aunque pesa mucho menos que el nivel.'));
C.push(body('Una cosa que tuve clara desde el principio: el sistema propone, pero el responsable dispone. El resultado se presenta como una propuesta que el usuario puede revisar y retocar antes de guardarla, lo que deja margen para contemplar circunstancias que el algoritmo no puede conocer, como afinidades o incompatibilidades entre jugadores. Esa combinación de asistencia automática y supervisión humana me parece la adecuada en un contexto deportivo y formativo, donde hay matices difíciles de meter en una fórmula. Como la lógica vive en una clase de dominio independiente, además, es directamente verificable con pruebas unitarias.'));

C.push(h2('5.6. Competiciones por estaciones'));
C.push(body('Las competiciones por estaciones organizan la actividad en distintas estaciones (stations) repartidas a lo largo de varias jornadas (station_days). Cada jugador acumula puntuaciones por estación y día, que se guardan en la tabla station_scores. El módulo calcula la clasificación general agrupada por grupo, sumando las puntuaciones de cada participante.'));
C.push(body('La gestión se articula con repositorios y proveedores de Riverpod propios del dominio de estaciones. La clasificación resultante alimenta la pantalla de clasificación general, desde la que se puede exportar a Excel mediante el servicio ExportService, como detallo más adelante.'));
C.push(body('Este formato encaja muy bien con la dinámica de un campus, donde los participantes van rotando por distintas pruebas de habilidad a lo largo de la jornada. Cada estación puntúa de forma independiente y el sistema agrega los resultados para dar una clasificación global por grupo, lo que fomenta a la vez la competición individual y la cohesión de equipo. La granularidad de station_scores (puntuación por estación, jugador y día) permite reconstruir el detalle de cada jornada y, a la vez, calcular cómodamente los totales que se muestran en la clasificación.'));
C.push(...placeholder('Figura 5.4: Clasificación general de las competiciones por estaciones.'));
C.push(...placeholder('Figura 5.5: Pantalla para añadir puntuaciones.'));

C.push(h2('5.7. Competiciones de siesta y exportación a PDF'));
C.push(body('Las competiciones de siesta agrupan las actividades más lúdicas del campus (ping pong, billar, tiro a canasta y similares) y admiten tres formatos: liga/grupos con playoffs, individual con escalera diaria y tiros libres seguidos. La información se modela en las tablas siesta_competitions, siesta_participants, siesta_matches y siesta_daily_scores. Según el formato, el módulo calcula la clasificación por puntos de liga y partidos jugados, ganados y perdidos, y, cuando procede, el cuadro de eliminatorias.'));
C.push(body('Desde la pantalla de clasificación de una competición de siesta, administradores y entrenadores exportan un PDF mediante el servicio SiestaExportService (siesta_export_service.dart), que usa las librerías pdf (^3.11.3) y printing (^5.14.2). La generación se hace con Printing.layoutPdf, que es multiplataforma: en la web abre el diálogo del navegador para guardar como PDF, y en móvil abre la vista previa de impresión o el menú de compartir. El contenido se adapta al formato de la competición, como explico en la sección de exportaciones.'));
C.push(body('La variedad de formatos obligó a pensar con cuidado la lógica de clasificación, y cada formato tiene su propio método en el servicio. En liga o grupos con playoffs, el sistema cuenta partidos jugados, ganados y perdidos y reparte puntos de liga, ordenando la clasificación en consecuencia; al cerrar la fase regular, se generan las eliminatorias a partir de los mejores. En la escalera diaria, la clasificación se construye sumando las puntuaciones registradas en siesta_daily_scores. En los tiros libres seguidos, lo que cuenta es el número de tiros encestados de forma consecutiva, asociado a la fecha en que se logró la marca.'));
C.push(body('Quiero detenerme en un detalle que me dio bastantes problemas al principio. En las competiciones de liga con playoffs, el PDF mezclaba la fase de grupos y la fase eliminatoria, y al ordenar las rondas me salían primero las eliminatorias y después los grupos, justo al revés de lo que tiene sentido. Lo resolví con una función de comparación, _compareRounds, que detecta si una ronda es de eliminatoria (octavos, cuartos, semifinal, final) y, si lo es, la manda al final; las fases de grupo van siempre delante, y entre eliminatorias se ordenan por etapa. Una vez ajustado eso, el documento sale en el orden lógico: clasificación de los grupos arriba y el cuadro de eliminatorias debajo.'));
C.push(body('Esta diversidad de formatos lúdicos refleja la riqueza de las actividades de un campus y es uno de los rasgos que distinguen a la aplicación de las soluciones comerciales, que casi nunca contemplan competiciones tan específicas. El módulo esconde la complejidad de cada formato tras una interfaz común de gestión, de modo que el administrador opera igual sea cual sea el tipo de competición que esté configurando.'));
C.push(...placeholder('Figura 5.8: Listado de competiciones de siesta.'));
C.push(...placeholder('Figura 5.9: Clasificación y cuadro de eliminatorias de una competición de siesta.'));
C.push(...placeholder('Figura 5.10: Escalera diaria y tiros libres.'));

C.push(h2('5.8. Veladas'));
C.push(body('El módulo de veladas gestiona las actividades nocturnas del campus, organizadas en grupos con sus capitanes y sus ganadores. Se apoya en las tablas veladas, velada_groups y velada_group_members. Su función es complementar lo deportivo con actividades de cohesión y ocio, registrando los grupos participantes y los resultados de cada velada para consultarlos y reconocerlos después.'));
C.push(body('Aunque es un módulo de prioridad baja, las veladas son un elemento muy característico de la experiencia del campus y los participantes las valoran mucho. Modelarlas con grupos, capitanes y ganadores me permitió estructurar la competición nocturna de forma parecida a las deportivas, reutilizando patrones de diseño ya establecidos en el resto de la aplicación y manteniendo la coherencia de la experiencia.'));
C.push(...placeholder('Figura 5.13: Listado y detalle de veladas.'));

C.push(h2('5.9. Blog y tablón de anuncios'));
C.push(body('La comunicación se reparte en dos módulos: el blog, para contenidos más elaborados y duraderos, y el tablón de anuncios, para avisos breves y de actualidad. El blog opera sobre la tabla blog_posts y el tablón sobre tablon_posts. Los dos permiten publicar a los usuarios autorizados y consultar al resto, con las imágenes alojadas en Cloudinary para una entrega optimizada. Separarlos evita que los avisos puntuales entierren los contenidos de más valor.'));
C.push(body('Al principio dudé entre fusionar ambos canales en uno solo, con un campo que distinguiera ' + q('entrada de blog') + ' de ' + q('aviso') + '. Terminé separándolos porque el ritmo de publicación y la caducidad de cada cosa son muy distintos: un aviso (' + q('mañana la primera actividad empieza media hora antes') + ') nace y muere en un día, mientras que una crónica de la jornada o una galería de fotos tiene sentido conservarla. Tenerlos en tablas y pantallas independientes simplificó tanto las consultas como la interfaz, y dejó la puerta abierta a tratar cada uno de forma distinta más adelante, por ejemplo notificando solo los avisos del tablón.'));
C.push(...placeholder('Figura 5.14: Blog del campus.'));
C.push(...placeholder('Figura 5.15: Tablón de anuncios.'));

C.push(h2('5.10. Entrenamientos multimedia'));
C.push(body('Este módulo permite a los entrenadores publicar sesiones con contenido multimedia, almacenadas en la tabla trainings. Cada entrenamiento puede llevar texto descriptivo, imágenes (gestionadas con Cloudinary y cacheadas con cached_network_image) y enlaces a vídeos. Jugadores y familiares los consultan, lo que convierte a la aplicación en un repositorio centralizado del material formativo del campus.'));
C.push(body('La integración con Cloudinary aquí es importante: en vez de guardar las imágenes en la base de datos o en el almacenamiento de Supabase, las delego en un servicio especializado que las optimiza, las redimensiona según el dispositivo y las sirve a través de una CDN. Combinado con la caché en cliente de cached_network_image, esto reduce el consumo de datos y mejora bastante los tiempos de carga del contenido multimedia, algo que se agradece en una aplicación que se consulta sobre todo desde redes móviles.'));
C.push(...placeholder('Figura 5.16: Entrenamientos.'));

C.push(h2('5.11. Estadísticas, rankings y partidos en tiempo real'));
C.push(body('Las estadísticas se registran por jugador y partido en la tabla player_match_stats, que guarda puntos, rebotes, asistencias, robos, tapones y la condición de MVP. A partir de esos datos, el módulo de estadísticas calcula los rankings de anotador, reboteador y asistente, y designa al MVP.'));
C.push(body('El seguimiento de partidos en tiempo real se apoya en las suscripciones de Supabase Realtime, que usan WebSockets para propagar los cambios de la base de datos a todos los clientes suscritos. Cuando un entrenador registra un evento, la actualización se refleja al instante en los dispositivos de los demás sin recargar la pantalla, lo que da una experiencia dinámica durante los partidos.'));
C.push(body('Por dentro, el mecanismo de tiempo real de Supabase escucha el registro de replicación de PostgreSQL y lo retransmite a los clientes por un canal WebSocket. En la aplicación, esas suscripciones se integran con los proveedores de Riverpod, de manera que recibir un cambio actualiza el estado del proveedor correspondiente y, en cascada, todas las vistas que lo observan. Así la fuente de verdad sigue siendo la base de datos y la interfaz se limita a reflejar su estado más reciente, sin las inconsistencias que aparecerían si cada cliente guardara su propia copia desincronizada.'));
C.push(body('Un detalle del cálculo de la clasificación de siesta que me hizo darle alguna vuelta fue el desempate. Cuando dos o más participantes acaban con los mismos puntos de liga, no basta con dejarlos en cualquier orden: hay que aplicar criterios de desempate. Repliqué un esquema parecido al de la FIBA. Si el empate es entre dos, se mira primero el resultado del enfrentamiento directo y, si hace falta, la diferencia de puntos entre ellos; si el empate es a tres o más, se calcula una mini-clasificación con solo los partidos jugados entre los implicados. Tener esta lógica tanto en la pantalla de clasificación como en el servicio de exportación me obligó a centralizarla con cuidado para que el PDF y la app mostraran exactamente el mismo orden, porque al principio no coincidían y quedaba feo.'));

C.push(h2('5.12. Jugador premium, logros y gamificación'));
C.push(body('El módulo de jugador premium ofrece a este perfil un historial detallado de sus estadísticas por partido, para que pueda analizar su evolución a lo largo del campus. En paralelo, el sistema de logros y gamificación reparte reconocimientos según el desempeño deportivo (por alcanzar ciertos hitos de anotación o por ser nombrado MVP, por ejemplo), con la idea de subir la motivación y la implicación de los participantes.'));
C.push(body('La distinción entre el jugador estándar y el premium se articula como un rol diferenciado dentro del sistema de seguridad, así que el acceso al historial detallado queda protegido por las mismas políticas de RLS que rigen el resto. El historial premium se nutre directamente de player_match_stats y le presenta al jugador una visión cronológica y agregada de su rendimiento, más allá de los rankings públicos, lo que añade un componente de fidelización para los más comprometidos con su progresión.'));
C.push(body('La gamificación parte de una idea bastante asentada en el diseño de experiencias: reconocer el esfuerzo y la consecución de hitos refuerza la motivación. En un campus, donde lo formativo y lo lúdico pesan tanto como lo competitivo, los logros funcionan como un estímulo positivo que celebra la mejora individual y la participación, más allá del resultado de los partidos.'));

C.push(h2('5.13. Dashboard de administración'));
C.push(body('El dashboard de administración es el centro de control del campus para los administradores. Desde ahí se gestionan los usuarios y sus roles, se crean y configuran equipos y competiciones, y se obtiene una visión global del estado del sistema. Concentrar las tareas administrativas en un único punto de acceso agiliza el día a día de la organización.'));
C.push(body('La utilidad de un panel centralizado se nota sobre todo durante los días de campus, cuando el ritmo es alto y el administrador necesita ir rápido: promocionar a un usuario recién registrado, corregir la composición de un equipo o abrir una competición nueva. Al reunir esas acciones en una pantalla y apoyarse en los mismos repositorios y proveedores que el resto de módulos, el dashboard evita duplicar lógica y garantiza que cualquier cambio hecho desde él se propague de forma coherente al conjunto.'));
C.push(...placeholder('Figura 5.17: Dashboard de administración.'));

C.push(h2('5.14. Notificaciones push (FCM)'));
C.push(body('Las notificaciones push se gestionan con Firebase Cloud Messaging a través del servicio NotificationService (notification_service.dart), que registra los tokens de los dispositivos en las tablas fcm_tokens y device_tokens. El servicio pide los permisos al usuario, obtiene el token, lo guarda y atiende la recepción de mensajes tanto en primer plano como en segundo plano. El envío se hace contra la API V1 de FCM, autenticándose con una cuenta de servicio, y se dirige a topics: campus_general para todos y campus_staff para administradores y entrenadores.'));
C.push(body('Aquí me topé con dos cosas que conviene contar. La primera: en la web, el token FCM puede cambiar y no basta con guardarlo una vez. Acabé refrescándolo en Supabase en cada arranque, borrando antes los tokens web anteriores del usuario para que Chrome y la PWA instalada no acabaran generando duplicados. En nativo, en cambio, basta con suscribirse al topic la primera vez, y lo controlo con una bandera en SharedPreferences.'));
C.push(body('La segunda fue un problema de notificaciones duplicadas que apareció durante el desarrollo, originado por registrar manejadores de mensajes por partida doble. La solución pasó por consolidar el registro de los manejadores y por depurar los tokens obsoletos, de forma que cada usuario reciba una sola notificación por evento. Cuando un envío a un token web devuelve un error de tipo UNREGISTERED, ese token se borra de la tabla, lo que mantiene la lista limpia con el tiempo.'));
C.push(body('El comportamiento, además, cambia según el estado de la aplicación. En primer plano, la recepción se gestiona dentro de la propia aplicación, que decide cómo mostrar el mensaje; en segundo plano o cerrada, es el sistema operativo (o el Service Worker, en el caso de la PWA) quien muestra la notificación. Entender bien estos escenarios fue clave para acabar con las duplicidades y ofrecer una experiencia consistente en todas las plataformas.'));

C.push(h2('5.15. Funcionalidades de exportación'));
C.push(body('La aplicación tiene exactamente dos exportaciones, cada una con su servicio y sus librerías. No hay ninguna otra; en particular, no se exportan estadísticas individuales de jugador a PDF.'));
C.push(h3('5.15.1. Exportación a PDF de las competiciones de siesta'));
C.push(body('Desde la pantalla de clasificación de una competición de siesta, administradores y entrenadores exportan un PDF mediante SiestaExportService, que usa pdf (^3.11.3) y printing (^5.14.2). La generación se hace con Printing.layoutPdf, que es multiplataforma: en la web abre el diálogo del navegador para guardar como PDF y en móvil abre la vista previa de impresión o el menú de compartir. El contenido se adapta al formato:'));
C.push(bullet([run('Liga / grupos con playoffs: ', { bold: true }), run('el documento incluye la clasificación agrupada (con columnas de partidos jugados, ganados, perdidos y puntos) y el cuadro de eliminatorias; los grupos salen primero y las rondas eliminatorias (octavos, cuartos, semifinal y final) al final.')]));
C.push(bullet([run('Individual (escalera diaria): ', { bold: true }), run('un ranking de participantes ordenado por puntos.')]));
C.push(bullet([run('Tiros libres seguidos: ', { bold: true }), run('un ranking por número de tiros, junto con la fecha correspondiente.')]));
C.push(body('Adaptar el contenido a cada formato no fue trivial, porque los tres requieren una composición distinta del documento. SiestaExportService encapsula esa lógica, construyendo el árbol de elementos del PDF (tablas, encabezados y, si toca, el cuadro de eliminatorias) en función del tipo de competición. Elegir la librería printing, y en concreto su método Printing.layoutPdf, es lo que le da a la solución su carácter multiplataforma, al delegar en cada sistema el mecanismo nativo de guardado, impresión o compartición.'));
C.push(...placeholder('Figura 5.11: Documento PDF exportado de una competición de siesta.'));
C.push(h3('5.15.2. Exportación a Excel de la clasificación por estaciones'));
C.push(body('Desde la pantalla de clasificación general de las competiciones por estaciones, los administradores exportan un archivo Excel (.xlsx) mediante el servicio ExportService del módulo de competiciones (export_service.dart), que usa la librería excel (^4.0.6). El archivo lleva una hoja por cada grupo o equipo, con las puntuaciones de cada jugador por día y el total acumulado, lo que facilita el análisis posterior. En la web, la propia librería dispara la descarga al pasarle el nombre de fichero; en Android se guarda en la carpeta de Descargas, y en iOS se abre el menú de compartir para que el usuario elija dónde guardarlo.'));
C.push(body('Elegir Excel para esta segunda exportación responde a la naturaleza tabular y al uso previsto de los datos de las estaciones. A diferencia del PDF de siesta, pensado para consultar y difundir, el .xlsx está orientado al análisis: deja a los organizadores ordenar, filtrar, sumar o graficar las puntuaciones con las herramientas que ya manejan. La organización en una hoja por grupo facilita la lectura y mantiene separados los datos de cada conjunto de participantes, replicando la estructura con la que se ven en la propia aplicación.'));
C.push(body('Las dos exportaciones ilustran un principio que apliqué a lo largo del proyecto: usar la herramienta más adecuada para cada necesidad en vez de forzar una solución única. El PDF, por ser un documento final inalterable, encaja con la difusión de clasificaciones y cuadros; el Excel, por su flexibilidad, encaja con el análisis de datos. Que cada formato case con su propósito mejora la utilidad real de ambas funciones para la gente del campus.'));
C.push(...placeholder('Figura 5.12: Archivo Excel exportado con la clasificación por estaciones.'));

C.push(h2('5.16. Despliegue de la PWA en Firebase Hosting'));
C.push(body('El despliegue de la versión web consiste en compilar la aplicación con el comando de construcción web de Flutter y publicar los artefactos en Firebase Hosting mediante la CLI de Firebase. La compilación genera el Service Worker y el manifest.json que habilitan la instalación de la PWA y su funcionamiento parcial sin conexión.'));
C.push(body('Firebase Hosting sirve la aplicación a través de una CDN con HTTPS, lo que garantiza una entrega rápida y segura. La aplicación queda accesible públicamente en su dirección de producción, desde la que cualquiera puede instalarla. Los pasos concretos de configuración y despliegue están en el Anexo B.'));

// ===========================================================================
// CAPITULO 6 - PRUEBAS
// ===========================================================================
C.push(chapter('6. Pruebas'));

C.push(h2('6.1. Objetivos del plan de pruebas'));
C.push(body('El objetivo del plan de pruebas es dar una confianza razonable en que la aplicación cumple los requisitos funcionales y no funcionales del Capítulo 3 y se comporta de forma correcta y estable en las plataformas de destino. Dado que es una aplicación con muchos módulos, integración con servicios externos y despliegue multiplataforma, opté por una estrategia equilibrada: verificación automatizada de la lógica crítica y validación manual a fondo de la experiencia de usuario.'));
C.push(body('No perseguía cubrir cada línea de código. Es un objetivo poco realista en un proyecto de este alcance y de escaso valor en las capas más volátiles de la interfaz. Preferí concentrar el esfuerzo donde más riesgo y más valor hay: la lógica de negocio que sostiene los cálculos del dominio, la integración con el backend y los flujos de usuario más importantes, entre ellos las dos exportaciones.'));

C.push(h2('6.2. Estrategia de pruebas'));
C.push(body('Para asegurar la calidad definí una estrategia en tres niveles: pruebas unitarias, pruebas de integración y pruebas de aceptación manual en varias plataformas.'));
C.push(body('Las pruebas unitarias, con el framework flutter_test, se centraron en la lógica de negocio más crítica y aislable: el algoritmo de generación de equipos equilibrados y el cálculo de los rankings y las clasificaciones. Como esa lógica vive en clases de dominio desacopladas de la infraestructura, pude verificarla sustituyendo los repositorios reales por dobles de prueba.'));
C.push(body('Las pruebas de integración comprobaron la comunicación con Supabase y los servicios externos, verificando que las lecturas y escrituras, las suscripciones en tiempo real y la aplicación de las políticas de RLS se comportan como se espera en un entorno real de backend.'));
C.push(body('Y las pruebas de aceptación manual validaron la experiencia completa en las plataformas de destino (Android, iOS, Chrome y Safari), con atención especial a los flujos críticos y a las dos exportaciones, cuyo comportamiento difiere entre la web y el móvil. Buena parte de estas pruebas las hice contando con otros entrenadores del campus y con algunos jugadores de confianza, que probaron la aplicación con datos parecidos a los reales y me devolvieron impresiones sobre la experiencia de uso. La validación definitiva, en cualquier caso, llegará con la edición de julio.'));
C.push(body('Reconozco que el reparto del esfuerzo entre estos tres niveles no fue homogéneo. Las pruebas unitarias y la validación manual se llevaron la mayor parte del tiempo, mientras que las de integración fueron más puntuales, centradas en los puntos donde la interacción con Supabase era más delicada: la propagación de cambios en tiempo real y la aplicación de las políticas de RLS. Probar a fondo la integración con un backend gestionado es laborioso, porque montar y limpiar datos de prueba contra un proyecto real lleva su tiempo. Con perspectiva, habría merecido la pena preparar un proyecto de Supabase aparte, dedicado solo a pruebas, en lugar de reutilizar el de desarrollo.'));

C.push(h2('6.3. Casos de prueba destacados'));
C.push(dataTable(
  ['ID', 'Caso de prueba', 'Resultado esperado', 'Estado'],
  [
    ['CP-01', 'Registro de un nuevo usuario', 'Se crea el usuario con rol ' + q('visitante') + ' mediante el trigger.', 'Correcto'],
    ['CP-02', 'Generación automática de equipos', 'Los equipos resultan equilibrados en edad, nivel y posición.', 'Correcto'],
    ['CP-03', 'Actualización de marcador en tiempo real', 'El marcador se actualiza en todos los dispositivos al instante.', 'Correcto'],
    ['CP-04', 'Exportación a PDF de una competición de siesta', 'Se genera un PDF con la clasificación y el cuadro de eliminatorias.', 'Correcto'],
    ['CP-05', 'Exportación a Excel de la clasificación por estaciones', 'Se genera un .xlsx con una hoja por grupo y las puntuaciones por día.', 'Correcto'],
    ['CP-06', 'Recepción de notificación push', 'El usuario recibe la notificación sin duplicados.', 'Correcto'],
    ['CP-07', 'Instalación de la PWA', 'La aplicación se instala desde el navegador y funciona offline parcialmente.', 'Correcto'],
    ['CP-08', 'Asignación de rol por un administrador', 'El usuario adquiere los permisos de su nuevo rol según las políticas de RLS.', 'Correcto'],
  ],
  [1000, 2700, 3970, 1400]
));
C.push(gap());

C.push(h2('6.4. Pruebas de rendimiento y multiplataforma'));
C.push(body('Probé la aplicación en dispositivos Android e iOS y en navegadores de escritorio (Chrome y Safari) en su versión PWA. Las dos exportaciones se verificaron en todas las plataformas: el PDF de las competiciones de siesta, que en la web abre el diálogo de guardado del navegador y en móvil la vista previa de impresión o el menú de compartir; y el Excel de la clasificación por estaciones, cuyo archivo se descarga correctamente en todos los entornos.'));
C.push(body('En cuanto al rendimiento, comprobé que las pantallas principales se cargan en menos de dos segundos en condiciones normales de red, cumpliendo el RNF-02, y que las actualizaciones en tiempo real llegan a los clientes suscritos en menos de un segundo. La caché del Service Worker reduce bastante los tiempos de carga en las visitas siguientes a la PWA.'));
C.push(body('Las pruebas multiplataforma sacaron a la luz diferencias de comportamiento que hubo que tratar de forma específica, sobre todo en lo más sensible al entorno: las notificaciones push y las exportaciones. Printing.layoutPdf, por ejemplo, dispara experiencias distintas en cada plataforma (diálogo de guardado en la web, vista previa de impresión o menú de compartir en móvil), así que lo validé por separado en cada una. Comprobar que ambas exportaciones dan un resultado correcto y utilizable en todos los entornos fue uno de los focos prioritarios de la fase de aceptación.'));
C.push(body('El conjunto de los resultados confirma que la aplicación satisface los requisitos no funcionales y se comporta de forma estable en las cuatro plataformas de destino. Los casos de prueba destacados se superaron con resultado correcto, y las pruebas de aceptación manual no revelaron incidencias bloqueantes en los flujos críticos. Esto, junto con las pruebas unitarias de la lógica de dominio, da una confianza adecuada en la calidad de lo entregado, a la espera de la prueba real que supondrá la edición de julio.'));

// ===========================================================================
// CAPITULO 7 - RESULTADOS
// ===========================================================================
C.push(chapter('7. Resultados'));

C.push(h2('7.1. Aplicación desarrollada'));
C.push(body('El resultado es una aplicación completamente funcional, desplegada como PWA en Firebase Hosting y accesible públicamente en https://campus-baloncesto.web.app. Integra los quince módulos descritos y da soporte a los seis roles definidos, con una experiencia coherente en Android, iOS y la web. En su pantalla principal se presenta como ' + q('Campus Toledo') + '. La aplicación está lista y desplegada en producción; la primera edición del campus que funcionará íntegramente con ella será la de julio de 2026, del 1 al 11 de julio en Toledo. Si la lectura de este trabajo se produce pasado el campus, la aplicación ya habrá pasado su primera prueba de fuego real con cerca de un centenar de jugadores.'));

C.push(h2('7.2. Estado de los módulos'));
C.push(dataTable(
  ['Nº', 'Módulo', 'Estado'],
  [
    ['1', 'Autenticación y roles', 'Completado'],
    ['2', 'Gestión de equipos', 'Completado'],
    ['3', 'Generador automático de equipos', 'Completado'],
    ['4', 'Competiciones por estaciones', 'Completado'],
    ['5', 'Competiciones de siesta', 'Completado'],
    ['6', 'Veladas', 'Completado'],
    ['7', 'Partidos en tiempo real', 'Completado'],
    ['8', 'Estadísticas y rankings', 'Completado'],
    ['9', 'Jugador premium', 'Completado'],
    ['10', 'Logros y gamificación', 'Completado'],
    ['11', 'Blog y tablón', 'Completado'],
    ['12', 'Entrenamientos multimedia', 'Completado'],
    ['13', 'Notificaciones push (FCM)', 'Completado'],
    ['14', 'Exportaciones (PDF y Excel)', 'Completado'],
    ['15', 'Despliegue PWA', 'Completado'],
  ],
  [900, 6770, 1400]
));
C.push(gap());

C.push(h2('7.3. Cumplimiento de objetivos y valoración técnica'));
C.push(body('Se cumplieron todos los objetivos planteados al inicio. La aplicación gestiona de forma integral el campus, incorpora el algoritmo de generación automática de equipos, registra estadísticas detalladas, sincroniza los datos en tiempo real, envía notificaciones push y ofrece las dos exportaciones previstas: el PDF de las competiciones de siesta y el Excel de la clasificación por estaciones.'));
C.push(body('En lo técnico, la pareja Flutter + Supabase resultó muy productiva, y diría que fue la decisión más acertada del proyecto. Permite cubrir tres plataformas con una sola base de código y delega en el backend gestionado la complejidad de la persistencia, la autenticación, el tiempo real y la seguridad. La Clean Architecture y Riverpod dieron lugar a un código modular y mantenible, en el que cada módulo evoluciona por su cuenta. Y las políticas de RLS permitieron situar la autorización en la propia base de datos, reforzando la seguridad del conjunto.'));
C.push(body('El alcance funcional logrado es amplio: la aplicación cubre todo el ciclo de vida de un campus, desde la gestión de usuarios y equipos hasta la organización de competiciones de distinta naturaleza, el registro y la consulta de estadísticas, la comunicación y la difusión de contenidos, con sincronización en tiempo real y soporte multiplataforma. Las dos exportaciones, lejos de ser un añadido decorativo, responden a necesidades concretas y diferenciadas (difundir clasificaciones y cuadros en PDF, analizar datos en Excel) y demuestran que la solución se integra con los flujos de trabajo habituales de los organizadores.'));
C.push(body('Frente a las alternativas del estado del arte, el resultado se posiciona como una plataforma que reúne, en un único producto de código abierto y bajo coste, capacidades que las aplicaciones comerciales solo ofrecen de forma fragmentada o a precios altos. La generación automática de equipos equilibrados y el soporte de actividades tan propias del campus (estaciones, siestas y veladas) son rasgos diferenciales que ninguna solución del mercado ofrece junta.'));
C.push(dataTable(
  ['Métrica', 'Valor'],
  [
    ['Plataformas soportadas', 'Android, iOS y Web (PWA)'],
    ['Módulos funcionales', '15'],
    ['Roles de usuario', '6'],
    ['Tablas principales en base de datos', 'Más de 18 con RLS'],
    ['Funcionalidades de exportación', '2 (PDF de siesta y Excel de clasificación)'],
    ['Despliegue', 'Firebase Hosting (PWA)'],
  ],
  [3600, 5470]
));
C.push(gap());

// ===========================================================================
// CAPITULO 8 - CONCLUSIONES
// ===========================================================================
C.push(chapter('8. Conclusiones y Líneas Futuras'));

C.push(h2('8.1. Conclusiones'));
C.push(body('Desarrollar Campus Baloncesto App me ha servido para demostrar que se puede construir una aplicación multiplataforma completa y profesional desde una sola base de código. La combinación de Flutter y Supabase resultó especialmente acertada, al proporcionar un backend gestionado que reduce muchísimo la complejidad de la infraestructura. La Clean Architecture organizada por funcionalidades y la gestión de estado con Riverpod ayudaron a que el código quedara mantenible y fácil de ampliar.'));
C.push(body('El proyecto cumplió todos los objetivos y ofrece una solución que unifica la gestión del campus en una sola plataforma accesible desde cualquier dispositivo. Las dos exportaciones, ajustadas a las necesidades reales, y el algoritmo de generación automática de equipos son aportaciones de valor frente a lo que hay en el mercado.'));
C.push(body('En lo personal y formativo, ha supuesto aplicar de verdad conocimientos de ingeniería del software, diseño de bases de datos relacionales, seguridad, desarrollo multiplataforma y despliegue en la nube, todo integrado en un producto real y con un ciclo de vida completo, del análisis a la producción. No es lo mismo estudiar estas cosas por separado que verlas encajar en un sistema que de verdad funciona.'));
C.push(body('Por el camino afronté retos técnicos con cierta dificultad: la corrección de las notificaciones duplicadas, la adaptación de las exportaciones a las particularidades de cada plataforma o el diseño de un algoritmo de equilibrado de equipos que fuera eficaz y, a la vez, comprensible. Algunos resultaron más laboriosos de lo que esperaba (el del orden de las rondas en el PDF y el del token web en cada arranque me llevaron más tiempo del previsto), pero cada uno reforzó el aprendizaje y dejó criterios de diseño que me valdrán para futuros proyectos.'));
C.push(body('Campus Baloncesto App es, al final, una solución completa, funcional y desplegada en producción, que responde a una necesidad real y que muestra cómo una elección tecnológica adecuada, una arquitectura sólida y una metodología iterativa permiten a una sola persona construir un producto multiplataforma de calidad en un plazo acotado.'));
C.push(body('El verdadero examen, eso sí, será la edición del campus de julio de 2026, cuando la aplicación se use a pleno rendimiento durante los once días, con sus cerca de cien jugadores, sus entrenadores y sus familias. Tengo la expectativa de recoger entonces el feedback de todos ellos (qué les resulta cómodo, qué echan en falta, qué pequeños detalles fallan en el uso real) para seguir iterando sobre la aplicación a partir de esa experiencia. Esa será la mejor medida de si el trabajo ha cumplido su propósito.'));

C.push(h2('8.2. Líneas futuras'));
C.push(bullet('Incorporar analíticas avanzadas y paneles de visualización de estadísticas históricas y de evolución de los jugadores.'));
C.push(bullet('Ampliar las opciones de exportación a otros formatos y secciones, según lo que pidan los usuarios.'));
C.push(bullet('Integrar un sistema de inscripción y pago en línea para futuras ediciones del campus.'));
C.push(bullet('Desarrollar una versión para wearables que facilite registrar las estadísticas directamente en pista.'));
C.push(bullet('Incorporar soporte multilingüe para internacionalizar la aplicación.'));
C.push(bullet('Añadir un módulo de mensajería interna en tiempo real entre los distintos roles.'));
C.push(bullet('Automatizar las pruebas de extremo a extremo e integrarlas en una canalización de integración continua.'));

// ===========================================================================
// REFERENCIAS
// ===========================================================================
C.push(chapter('Referencias'));
const refs = [
  'Google. (2024). Flutter documentation. Recuperado de https://docs.flutter.dev',
  'Google. (2024). Dart programming language. Recuperado de https://dart.dev',
  'Supabase. (2024). Supabase documentation. Recuperado de https://supabase.com/docs',
  'Google. (2024). Firebase Cloud Messaging documentation. Recuperado de https://firebase.google.com/docs/cloud-messaging',
  'Google. (2024). Firebase Hosting documentation. Recuperado de https://firebase.google.com/docs/hosting',
  'Riverpod. (2024). Riverpod: State management for Flutter. Recuperado de https://riverpod.dev',
  'Flutter. (2024). go_router package. Recuperado de https://pub.dev/packages/go_router',
  'Cloudinary. (2024). Cloudinary documentation. Recuperado de https://cloudinary.com/documentation',
  'Flutter. (2024). pdf package. Recuperado de https://pub.dev/packages/pdf',
  'Flutter. (2024). printing package. Recuperado de https://pub.dev/packages/printing',
  'Flutter. (2024). excel package. Recuperado de https://pub.dev/packages/excel',
  'Google. (2024). Material Design 3. Recuperado de https://m3.material.io',
  'web.dev. (2024). Progressive Web Apps. Recuperado de https://web.dev/explore/progressive-web-apps',
  'Martin, R. C. (2017). Clean Architecture: A Craftsman’s Guide to Software Structure and Design. Prentice Hall.',
  'Windmill, E. (2019). Flutter in Action. Manning Publications.',
  'Biessek, A. (2019). Flutter for Beginners. Packt Publishing.',
];
refs.forEach(r => C.push(new Paragraph({
  alignment: AlignmentType.JUSTIFIED,
  spacing: { line: LINE_15, after: 120 },
  indent: { left: 567, hanging: 567 },
  children: [new TextRun({ text: r, font: FONT, size: SZ_BODY })],
})));

// ===========================================================================
// ANEXO A
// ===========================================================================
C.push(chapter('Anexo A. Esquema de la Base de Datos'));
C.push(body('A continuación describo el esquema de la base de datos PostgreSQL gestionada por Supabase, con sus tablas, sus campos principales y el trigger que crea los usuarios automáticamente. Todas las tablas están protegidas mediante políticas de Row Level Security.'));
C.push(dataTable(
  ['Tabla', 'Campos principales', 'Descripción'],
  [
    ['users', 'id, role, nombre, apellidos, foto_url, posicion, estatura, edad, nivel', 'Usuarios del sistema y sus atributos.'],
    ['teams', 'id, nombre', 'Equipos del campus.'],
    ['team_members', 'team_id, user_id', 'Relación entre equipos y jugadores.'],
    ['trainings', 'id, titulo, contenido, multimedia', 'Entrenamientos multimedia.'],
    ['blog_posts', 'id, titulo, contenido', 'Entradas del blog.'],
    ['tablon_posts', 'id, contenido', 'Avisos del tablón de anuncios.'],
    ['fcm_tokens / device_tokens', 'user_id, token, platform', 'Tokens para notificaciones push.'],
    ['stations / station_days', 'id, nombre, fecha', 'Estaciones y jornadas de las competiciones por estaciones.'],
    ['station_scores', 'station_id, user_id, dia, puntos', 'Puntuaciones por estación, jugador y día.'],
    ['siesta_competitions', 'id, nombre, juego, formato, estado', 'Competiciones de siesta.'],
    ['siesta_participants', 'puntos_liga, partidos_jugados, partidos_ganados, partidos_perdidos, grupo', 'Participantes en competiciones de siesta.'],
    ['siesta_matches', 'participant1_id, participant2_id, score1, score2, ronda, estado', 'Partidos de las competiciones de siesta.'],
    ['siesta_daily_scores', 'user_id, fecha, puntos', 'Puntuaciones diarias (escalera).'],
    ['veladas / velada_groups / velada_group_members', 'id, grupo, capitan, ganador', 'Veladas, grupos, capitanes y ganadores.'],
    ['player_match_stats', 'points, rebounds, assists, steals, blocks, is_mvp', 'Estadísticas detalladas por jugador y partido.'],
  ],
  [2500, 3570, 3000]
));
C.push(gap());
C.push(body('Las tablas legacy competitions, matches y statistics están en desuso, ya que fueron reemplazadas por station_scores y player_match_stats.'));
C.push(body('El trigger on_auth_user_created se ejecuta tras insertar un nuevo usuario en el sistema de autenticación e invoca la función handle_new_user(), encargada de crear el registro del usuario en la tabla users con el rol ' + q('visitante') + ' por defecto. Una descripción simplificada del trigger y la función sería:'));
{
  const codeLines = [
    'create function handle_new_user() returns trigger as $$',
    'begin',
    "  insert into public.users (id, role) values (new.id, 'visitante');",
    '  return new;',
    'end; $$ language plpgsql security definer;',
    '',
    'create trigger on_auth_user_created',
    'after insert on auth.users',
    'for each row execute function handle_new_user();',
  ];
  C.push(new Paragraph({
    shading: { type: ShadingType.CLEAR, fill: 'F2F2F2', color: 'auto' },
    spacing: { before: 120, after: 200, line: 276 },
    border: {
      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 4 },
      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 4 },
      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 6 },
      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 6 },
    },
    children: codeLines.flatMap((l, i) =>
      i === 0
        ? [new TextRun({ text: l, font: 'Consolas', size: 20 })]
        : [new TextRun({ text: l, font: 'Consolas', size: 20, break: 1 })]
    ),
  }));
}

// ===========================================================================
// ANEXO B
// ===========================================================================
C.push(chapter('Anexo B. Guía de Instalación y Despliegue'));

C.push(h2('B.1. Requisitos previos'));
C.push(bullet('Flutter SDK (canal estable) y Dart instalados y configurados en el PATH.'));
C.push(bullet('Una cuenta de Supabase con un proyecto creado.'));
C.push(bullet('Una cuenta de Firebase con un proyecto creado y la Firebase CLI instalada.'));
C.push(bullet('Una cuenta de Cloudinary para el almacenamiento de imágenes.'));
C.push(bullet('Android Studio y/o Xcode para compilar las versiones móviles.'));

C.push(h2('B.2. Configuración de Supabase'));
C.push(bullet('Crear el proyecto en Supabase y obtener la URL del proyecto y la clave anónima (anon key).'));
C.push(bullet('Ejecutar el esquema de la base de datos (tablas del Anexo A) y crear el trigger on_auth_user_created y la función handle_new_user().'));
C.push(bullet('Definir las políticas de Row Level Security para cada tabla según el rol del usuario.'));
C.push(bullet('Configurar la URL y la clave anónima en la inicialización de supabase_flutter dentro de la aplicación.'));

C.push(h2('B.3. Configuración de Firebase'));
C.push(bullet('Registrar las aplicaciones Android, iOS y Web en el proyecto de Firebase.'));
C.push(bullet('Descargar los ficheros de configuración (google-services.json, GoogleService-Info.plist) y la configuración web.'));
C.push(bullet('Habilitar Firebase Cloud Messaging para las notificaciones push.'));
C.push(bullet('Habilitar Firebase Hosting para el despliegue de la PWA.'));

C.push(h2('B.4. Compilación y despliegue'));
C.push(body('Una vez configurados los servicios, la compilación y el despliegue se hacen con estos comandos:'));
{
  const cmdLines = [
    'flutter pub get',
    'flutter build apk      # Android',
    'flutter build ios      # iOS',
    'flutter build web      # PWA',
    'firebase deploy --only hosting',
  ];
  C.push(new Paragraph({
    shading: { type: ShadingType.CLEAR, fill: 'F2F2F2', color: 'auto' },
    spacing: { before: 120, after: 200, line: 276 },
    border: {
      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 4 },
      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 4 },
      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 6 },
      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER, space: 6 },
    },
    children: cmdLines.flatMap((l, i) =>
      i === 0
        ? [new TextRun({ text: l, font: 'Consolas', size: 20 })]
        : [new TextRun({ text: l, font: 'Consolas', size: 20, break: 1 })]
    ),
  }));
}
C.push(body('Tras ejecutar firebase deploy, la PWA queda publicada y accesible públicamente en la dirección de Firebase Hosting del proyecto, lista para instalarse desde el navegador.'));
C.push(body('Vale la pena anotar algunas recomendaciones que aprendí a base de tropezar. Antes de compilar la versión web conviene ejecutar flutter clean para eliminar artefactos de compilaciones anteriores que pueden interferir con la caché del Service Worker; me ahorró más de un despliegue raro. Las credenciales sensibles (URL y clave de Supabase, configuración de Firebase y de Cloudinary) deben gestionarse con variables de entorno o ficheros excluidos del control de versiones, para que no acaben expuestas en el repositorio público. Y, tras cada despliegue, conviene abrir un navegador en modo incógnito y comprobar que se sirve la versión nueva y que el Service Worker no se ha quedado con una versión obsoleta en caché.'));
C.push(body('Para las versiones móviles, generar los paquetes de Android (APK o App Bundle) e iOS sigue el procedimiento estándar de Flutter, con la configuración previa de las firmas correspondientes y, en iOS, de los perfiles de aprovisionamiento de Apple. La distribución por las tiendas, eso sí, queda fuera del alcance del proyecto, cuya vía principal de difusión es la PWA por las ventajas operativas que he ido comentando.'));

// ===========================================================================
// CONSTRUCCION DEL DOCUMENTO
// ===========================================================================
buildDocument();

function buildDocument() {
  const sectionMargins = {
    top: convertMillimetersToTwip(25),
    right: convertMillimetersToTwip(25),
    bottom: convertMillimetersToTwip(25),
    left: convertMillimetersToTwip(25),
  };

  // Encabezado con el titulo del trabajo; pie con numero de pagina centrado.
  const headerDefault = new Header({
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: 'BFBFBF', space: 2 } },
      children: [new TextRun({ text: 'Campus Baloncesto App', font: FONT, size: 18, color: '595959' })],
    })],
  });
  const footerDefault = new Footer({
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 20 })],
    })],
  });
  const emptyHeaderFooter = new Header({ children: [new Paragraph({ children: [] })] });
  const emptyFooter = new Footer({ children: [new Paragraph({ children: [] })] });

  // Estilos de encabezado para que el TOC y el outline funcionen.
  const doc = new Document({
    creator: 'Alberto Rodríguez González',
    title: 'Campus Baloncesto App — Memoria TFG',
    description: 'Memoria del Trabajo de Fin de Grado',
    features: { updateFields: true },
    styles: {
      default: {
        document: { run: { font: FONT, size: SZ_BODY } },
      },
      paragraphStyles: [
        {
          id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { font: FONT, size: SZ_H1, bold: true, color: '000000' },
          paragraph: { spacing: { before: 0, after: 240, line: LINE_15 }, outlineLevel: 0 },
        },
        {
          id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { font: FONT, size: SZ_H2, bold: true, color: '000000' },
          paragraph: { spacing: { before: 240, after: 120, line: LINE_15 }, outlineLevel: 1 },
        },
        {
          id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { font: FONT, size: SZ_H2, bold: true, color: '000000' },
          paragraph: { spacing: { before: 200, after: 100, line: LINE_15 }, outlineLevel: 2 },
        },
      ],
    },
    sections: [
      // Seccion 1: portada (sin numero de pagina, sin encabezado).
      {
        properties: {
          page: { size: { width: 11906, height: 16838 }, margin: sectionMargins },
          titlePage: true,
        },
        headers: { default: emptyHeaderFooter, first: emptyHeaderFooter },
        footers: { default: emptyFooter, first: emptyFooter },
        children: coverChildren,
      },
      // Seccion 2: resto del documento con numeracion y encabezado.
      {
        properties: {
          page: {
            size: { width: 11906, height: 16838 },
            margin: sectionMargins,
            pageNumbers: { start: 1 },
          },
        },
        headers: { default: headerDefault },
        footers: { default: footerDefault },
        children: content,
      },
    ],
  });

  writeDoc(doc);
}

// ---------------------------------------------------------------------------
// Empaquetado y escritura del .docx (con fallback si esta bloqueado por Word)
// ---------------------------------------------------------------------------
function writeDoc(doc) {
  const primary = path.join(DIR, 'memoria_tfg_campus_baloncesto.docx');
  const fallback = path.join(DIR, 'memoria_tfg_campus_baloncesto_v2.docx');

  Packer.toBuffer(doc).then((buffer) => {
    let outPath = primary;
    let usedFallback = false;
    try {
      fs.writeFileSync(primary, buffer);
    } catch (e) {
      if (e.code === 'EBUSY' || e.code === 'EPERM' || e.code === 'EACCES') {
        fs.writeFileSync(fallback, buffer);
        outPath = fallback;
        usedFallback = true;
      } else {
        throw e;
      }
    }
    const kb = (fs.statSync(outPath).size / 1024).toFixed(1);
    console.log('---------------------------------------------');
    console.log('Documento generado correctamente.');
    if (usedFallback) {
      console.log('AVISO: el fichero principal estaba bloqueado (Word abierto).');
      console.log('Se ha escrito en el fichero alternativo: memoria_tfg_campus_baloncesto_v2.docx');
    }
    console.log('Ruta:      ' + outPath);
    console.log('Tamaño:    ' + kb + ' KB');
    console.log('Imágenes:  ' + global.__imgCount + ' figuras incrustadas');
    console.log('Huecos:    ' + global.__phCount + ' espacios reservados para capturas');
    console.log('---------------------------------------------');
  }).catch((err) => {
    console.error('ERROR al generar el documento:', err);
    process.exit(1);
  });
}
