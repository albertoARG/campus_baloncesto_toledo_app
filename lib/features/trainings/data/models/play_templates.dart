import 'play_data.dart';

/// Una plantilla de jugada con nombre, para partir de una base.
class PlayTemplate {
  final String name;
  final Play play;
  const PlayTemplate(this.name, this.play);
}

/// Plantillas predefinidas (media pista, aro arriba). Coordenadas normalizadas
/// (0..1): y pequeña = cerca del aro, y grande = fondo/exterior.
List<PlayTemplate> playTemplates() => const [
      PlayTemplate(
        'Bloqueo directo (pick & roll)',
        Play(court: 'half', title: 'Bloqueo directo', items: [
          PlayItem(
              kind: 'player',
              team: 'off',
              label: '1',
              x: 0.55,
              y: 0.78,
              hasBall: true),
          PlayItem(kind: 'player', team: 'off', label: '2', x: 0.42, y: 0.60),
          // Pantalla del 2 sobre el defensor del 1.
          PlayItem(kind: 'arrow', arrowStyle: 'screen', pts: [
            [0.42, 0.60],
            [0.50, 0.70]
          ]),
          // El 1 bota saliendo del bloqueo.
          PlayItem(kind: 'arrow', arrowStyle: 'snake', pts: [
            [0.55, 0.75],
            [0.68, 0.52]
          ]),
          // El 2 continúa hacia el aro.
          PlayItem(kind: 'arrow', arrowStyle: 'solid', pts: [
            [0.42, 0.58],
            [0.50, 0.28]
          ]),
        ]),
      ),
      PlayTemplate(
        'Pasar y cortar (give & go)',
        Play(court: 'half', title: 'Pasar y cortar', items: [
          PlayItem(
              kind: 'player',
              team: 'off',
              label: '1',
              x: 0.25,
              y: 0.72,
              hasBall: true),
          PlayItem(kind: 'player', team: 'off', label: '2', x: 0.72, y: 0.55),
          // Pase del 1 al 2.
          PlayItem(kind: 'arrow', arrowStyle: 'dashed', pts: [
            [0.29, 0.70],
            [0.68, 0.56]
          ]),
          // Corte del 1 hacia el aro.
          PlayItem(kind: 'arrow', arrowStyle: 'solid', pts: [
            [0.25, 0.72],
            [0.48, 0.24]
          ]),
        ]),
      ),
      PlayTemplate(
        'Ataque 1-3-1',
        Play(court: 'half', title: 'Ataque 1-3-1', items: [
          PlayItem(
              kind: 'player',
              team: 'off',
              label: '1',
              x: 0.50,
              y: 0.80,
              hasBall: true),
          PlayItem(kind: 'player', team: 'off', label: '2', x: 0.18, y: 0.55),
          PlayItem(kind: 'player', team: 'off', label: '3', x: 0.50, y: 0.50),
          PlayItem(kind: 'player', team: 'off', label: '4', x: 0.82, y: 0.55),
          PlayItem(kind: 'player', team: 'off', label: '5', x: 0.50, y: 0.26),
        ]),
      ),
      PlayTemplate(
        'Defensa en zona 2-3',
        Play(court: 'half', title: 'Zona 2-3', items: [
          PlayItem(kind: 'player', team: 'def', label: '1', x: 0.36, y: 0.46),
          PlayItem(kind: 'player', team: 'def', label: '2', x: 0.64, y: 0.46),
          PlayItem(kind: 'player', team: 'def', label: '3', x: 0.20, y: 0.24),
          PlayItem(kind: 'player', team: 'def', label: '4', x: 0.50, y: 0.17),
          PlayItem(kind: 'player', team: 'def', label: '5', x: 0.80, y: 0.24),
        ]),
      ),
    ];
