# Traspaso de sesión — Campus Baloncesto

App Flutter Web (Firebase Hosting + Supabase + Cloudinary).
Deploy: `flutter build web --release && firebase deploy --only hosting`
URL: https://campus-baloncesto.web.app

## ⚠️ Pendiente IMPORTANTE
- **NADA de esta sesión está subido a GitHub.** Hacer commit como `abeto`
  (rama distinta a main si toca) con Co-Authored-By Claude.
- Botón "Importar Excel" antiguo se arregló cambiando file_picker→input nativo.

## Hecho esta sesión (resumen)
- **Offline**: cola de sincronización (`lib/core/sync/sync_queue.dart`) para
  estaciones + siesta (puntos/tiros). Banner + "✓ Todo sincronizado".
- **Recuperar contraseña**: flujo implícito (main.dart authOptions), pantalla
  reset_password_screen, flag `passwordRecoveryPending` en app_router.
  (Requiere en Supabase: Site URL + Redirect `https://campus-baloncesto.web.app/**`.)
- **Modo oscuro** (theme_mode_provider + AppTheme.darkTheme), toggle en drawer.
- **Buscadores** (core/widgets/search_field.dart) en usuarios, jugadores,
  y autocompletado de jugadores en puntuar/siesta.
- **Gestión de jugadores** (crear/eliminar/importar Excel) — necesita SQL:
  quitar FK users→auth.users, default gen_random_uuid(), función is_staff(),
  policies insert/delete. Selector de archivos: `core/utils/file_upload*.dart`.
- **Skeletons** (core/widgets/skeleton.dart) + **deshacer** (borrado diferido).
- **Layout** centrado max 720 en escritorio (main.dart builder).
- **Aviso "nueva versión"** (web/index.html, service worker).
- **Siesta**: generar partidos todos-contra-todos por grupo, y **playoffs**
  (semis/cuartos/octavos, mejores terceros, desempate por enfrentamiento
  directo, avance automático de ronda) — siesta_repository.
- **Veladas**: varios ganadores (toggle chip), añadir jugador con buscador
  excluyendo ya asignados, borrar desde lista (3 puntos), refrescar dentro.
- **Confeti + animaciones** al entrar en Clasificación (standings_screen).
- **Cronómetro** dual (adelante/atrás) — core/widgets/dual_timer.dart, y
  botones rápidos +1/+3/+5 (core/widgets/quick_number_field.dart).
- **Entrenamientos**: carpetas por grupo, ficha de sesión rellenable
  (training_plan_data.dart, guardada como JSON en `descripcion`), PDF con logo
  (training_template_service.dart).

## Pizarra táctica (foco actual) — features/trainings/presentation/views/
- `play_editor_screen.dart` (editor), `play_view.dart` (render app),
  `data/models/play_data.dart` (modelo), PDF en training_template_service.dart.
- Fondos = imágenes reales: `assets/images/media_pista.png` (1.384),
  `pista_entera.jpg` (1.515).
- Gestos: 1 dedo dibuja/coloca, 2 dedos zoom/mover (onScale unificado).
- Herramientas: Ninguno, Mover (selecciona→barra inferior: tamaño/balón/
  voltear/quitar), Atacante(O+nº), Defensor(∩ arco+nº, volteable), Entrega(●),
  Cono, Desp.atac(→), Desp.def(gancho, volteable), Pase(discontinua),
  Bote(serpiente), Tiro(=>), Bloqueo(┤), Ciega(╢), Bloq.+cont(2 tramos:
  arrastra, suelta, arrastra), Pase def.(chevrones), Zona, Texto, Borrar.
- PlayItem: kind, x/y, team, label(nº), scale(tamaño propio), flip, pts, arrowStyle.
- NO incluido a propósito: "rodar". Letras (E/P/R, orden, parada) → herramienta Texto.

## Convenciones del proyecto
- Español en la UI. Riverpod 3.2 (NotifierProvider, no ChangeNotifierProvider).
- file_picker override win32 en pubspec (solo web). Confeti/pdf/printing ya deps.
