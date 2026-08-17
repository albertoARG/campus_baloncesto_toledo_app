import 'dart:math' as math;

/// Un elemento de una jugada. Coordenadas NORMALIZADAS (0..1) respecto a la
/// pista, para poder dibujarlo a cualquier tamaño (app y PDF).
class PlayItem {
  final String kind; // 'player' | 'cone' | 'arrow' | 'zone' | 'dot'
  final double x; // player/cono/dot
  final double y;
  final bool hasBall;
  final String team; // 'off' (atacante, O) | 'def' (defensor, X)
  final String label; // número del jugador (1-5)
  final double scale; // tamaño propio del elemento
  final bool flip; // voltear (defensor ∩/∪, gancho a un lado u otro)
  final double rot; // rotación en grados (defensor: orientación 360º)
  final List<List<double>> pts; // arrow: polilínea [[x,y],...] ; zone: 2 esquinas
  final String arrowStyle; // 'solid'(corte)|'dashed'(pase)|'snake'(bote)|'screen'(pantalla)|'screen2'(ciega)
  final List<double> ctrl; // arrow: punto de control (curva); vacío = recta
  final String id; // identidad estable del elemento entre fotogramas (animación)
  final String owner; // arrow: id del jugador que recorre esta flecha
  final int order; // arrow: orden/paso del recorrido (0 = sin asignar)
  final double lead; // arrow: solapamiento de este paso con el anterior (0..0.9)
  final String target; // pase/entrega: id del jugador que recibe el balón
  final bool fake; // entrega: finta (no se entrega el balón realmente)
  final double spd; // recorrido/pase: velocidad (1 = normal, >1 llega antes)
  final bool sharp; // flecha con control: 'pico' (ángulo) en vez de curva suave
  final int balls; // jugador: nº de balones (0 usa hasBall; 2 = dos balones)

  const PlayItem({
    required this.kind,
    this.x = 0,
    this.y = 0,
    this.hasBall = false,
    this.team = 'def',
    this.label = '',
    this.scale = 1.0,
    this.flip = false,
    this.rot = 0,
    this.pts = const [],
    this.arrowStyle = '',
    this.ctrl = const [],
    this.id = '',
    this.owner = '',
    this.order = 0,
    this.lead = 0,
    this.target = '',
    this.fake = false,
    this.spd = 1.0,
    this.sharp = false,
    this.balls = 0,
  });

  // Nº efectivo de balones que lleva un jugador.
  int get ballCount => balls > 0 ? balls : (hasBall ? 1 : 0);

  PlayItem copyWith(
          {double? x,
          double? y,
          bool? hasBall,
          double? scale,
          bool? flip,
          double? rot,
          List<List<double>>? pts,
          List<double>? ctrl,
          String? id,
          String? owner,
          int? order,
          double? lead,
          String? target,
          bool? fake,
          double? spd,
          bool? sharp,
          int? balls}) =>
      PlayItem(
        kind: kind,
        x: x ?? this.x,
        y: y ?? this.y,
        hasBall: hasBall ?? this.hasBall,
        team: team,
        label: label,
        scale: scale ?? this.scale,
        flip: flip ?? this.flip,
        rot: rot ?? this.rot,
        pts: pts ?? this.pts,
        arrowStyle: arrowStyle,
        ctrl: ctrl ?? this.ctrl,
        id: id ?? this.id,
        owner: owner ?? this.owner,
        order: order ?? this.order,
        lead: lead ?? this.lead,
        target: target ?? this.target,
        fake: fake ?? this.fake,
        spd: spd ?? this.spd,
        sharp: sharp ?? this.sharp,
        balls: balls ?? this.balls,
      );

  Map<String, dynamic> toJson() => {
        'k': kind,
        'x': x,
        'y': y,
        'b': hasBall,
        'tm': team,
        'l': label,
        'sc': scale,
        'fl': flip,
        'rt': rot,
        'p': pts,
        's': arrowStyle,
        if (ctrl.isNotEmpty) 'c': ctrl,
        if (id.isNotEmpty) 'id': id,
        if (owner.isNotEmpty) 'ow': owner,
        if (order > 0) 'or': order,
        if (lead > 0) 'ld': lead,
        if (target.isNotEmpty) 'tg': target,
        if (fake) 'fk': true,
        if (spd != 1.0) 'sp': spd,
        if (sharp) 'sh': true,
        if (balls > 0) 'nb': balls,
      };

  factory PlayItem.fromJson(Map j) => PlayItem(
        kind: (j['k'] ?? 'player').toString(),
        x: (j['x'] ?? 0).toDouble(),
        y: (j['y'] ?? 0).toDouble(),
        hasBall: j['b'] ?? false,
        team: (j['tm'] ?? 'def').toString(),
        label: (j['l'] ?? '').toString(),
        scale: (j['sc'] ?? 1.0).toDouble(),
        flip: j['fl'] ?? false,
        rot: (j['rt'] ?? 0).toDouble(),
        pts: ((j['p'] as List?) ?? [])
            .map((e) =>
                (e as List).map((n) => (n as num).toDouble()).toList())
            .toList(),
        arrowStyle: (j['s'] ?? '').toString(),
        ctrl: ((j['c'] as List?) ?? [])
            .map((n) => (n as num).toDouble())
            .toList(),
        id: (j['id'] ?? '').toString(),
        owner: (j['ow'] ?? '').toString(),
        order: (j['or'] ?? 0) is num ? (j['or'] ?? 0).toInt() : 0,
        lead: (j['ld'] ?? 0).toDouble(),
        target: (j['tg'] ?? '').toString(),
        fake: j['fk'] ?? false,
        spd: (j['sp'] ?? 1.0).toDouble(),
        sharp: j['sh'] ?? false,
        balls: (j['nb'] ?? 0) is num ? (j['nb'] ?? 0).toInt() : 0,
      );
}

/// Una jugada: tipo de pista (media/entera) + elementos.
///
/// Puede tener varios FOTOGRAMAS (para animar la jugada). Por compatibilidad,
/// [items] es siempre el primer fotograma; [frames] guarda todos (>=1). El
/// JSON solo escribe 'frames' cuando hay más de uno.
class Play {
  final String court; // 'half' | 'full'
  final List<PlayItem> items;
  final double itemScale; // tamaño de los símbolos (0.5–1.5)
  final List<List<PlayItem>> frames;
  final double speed; // velocidad de la animación (1 = normal)
  final String title; // título de la jugada
  final List<String> frameTitles; // título por fotograma (paralelo a frames)
  final double overlap; // solapamiento entre pasos (0 = seguidos, >0 se solapan)

  const Play({
    this.court = 'half',
    this.items = const [],
    this.itemScale = 1.0,
    this.frames = const [],
    this.speed = 1.0,
    this.title = '',
    this.frameTitles = const [],
    this.overlap = 0,
  });

  // Proporción (ancho/alto) de las imágenes de pista usadas de fondo.
  double get aspect => court == 'full' ? 1.515 : 1.384;

  // Lista de fotogramas asegurando al menos uno.
  List<List<PlayItem>> get framesOrSingle =>
      frames.isNotEmpty ? frames : [items];

  // Título del fotograma [i] (o cadena vacía).
  String frameTitleAt(int i) =>
      (i >= 0 && i < frameTitles.length) ? frameTitles[i] : '';

  Map<String, dynamic> toJson() {
    final fr = frames.isNotEmpty ? frames : [items];
    return {
      'court': court,
      'scale': itemScale,
      'items': fr.first.map((e) => e.toJson()).toList(),
      if (fr.length > 1)
        'frames':
            fr.map((f) => f.map((e) => e.toJson()).toList()).toList(),
      if (speed != 1.0) 'spd': speed,
      if (title.isNotEmpty) 'ti': title,
      if (frameTitles.any((t) => t.isNotEmpty)) 'ft': frameTitles,
      if (overlap > 0) 'ovl': overlap,
    };
  }

  factory Play.fromJson(Map j) {
    final items = ((j['items'] as List?) ?? [])
        .map((e) => PlayItem.fromJson(e as Map))
        .toList();
    final framesJson = (j['frames'] as List?) ?? [];
    final frames = framesJson
        .map<List<PlayItem>>((f) =>
            (f as List).map((e) => PlayItem.fromJson(e as Map)).toList())
        .toList();
    final fr = frames.isNotEmpty ? frames : [items];
    return Play(
      court: (j['court'] ?? 'half').toString(),
      itemScale: (j['scale'] ?? 1.0).toDouble(),
      items: fr.first,
      frames: fr,
      speed: (j['spd'] ?? 1.0).toDouble(),
      title: (j['ti'] ?? '').toString(),
      frameTitles:
          ((j['ft'] as List?) ?? []).map((e) => e.toString()).toList(),
      overlap: (j['ovl'] ?? 0).toDouble(),
    );
  }
}

/// Interpola un elemento entre dos fotogramas (fracción [f] en 0..1).
PlayItem lerpPlayItem(PlayItem a, PlayItem b, double f) {
  double lp(double x, double y) => x + (y - x) * f;
  if (a.kind == 'arrow' || a.kind == 'zone') {
    if (a.pts.length == b.pts.length && a.pts.isNotEmpty) {
      return a.copyWith(
        pts: [
          for (var i = 0; i < a.pts.length; i++)
            [lp(a.pts[i][0], b.pts[i][0]), lp(a.pts[i][1], b.pts[i][1])]
        ],
        ctrl: (a.ctrl.length >= 2 && b.ctrl.length >= 2)
            ? [lp(a.ctrl[0], b.ctrl[0]), lp(a.ctrl[1], b.ctrl[1])]
            : a.ctrl,
      );
    }
    return a;
  }
  return a.copyWith(
      x: lp(a.x, b.x),
      y: lp(a.y, b.y),
      scale: lp(a.scale, b.scale),
      rot: lp(a.rot, b.rot));
}

/// Estilos de flecha que representan el MOVIMIENTO de un jugador (puede seguirse
/// en la animación de recorridos).
bool isMovementStyle(String s) =>
    s == '' ||
    s == 'solid' ||
    s == 'snake' ||
    s == 'defense' ||
    s == 'screen' ||
    s == 'screen2' ||
    s == 'screencont';

/// Posición (normalizada) de la canasta según el tipo de pista. En pista
/// entera hay dos: se elige la más cercana al punto [towards] (a donde apunta).
List<double> basketPos(String court, List<double> towards) {
  if (court == 'full') {
    const left = [0.12, 0.5];
    const right = [0.88, 0.5];
    return (towards[0] - left[0]).abs() <= (towards[0] - right[0]).abs()
        ? [left[0], left[1]]
        : [right[0], right[1]];
  }
  return [0.5, 0.165]; // media pista: el aro (circulito), bajo el tablero
}

/// Polilínea (normalizada) del cuerpo de una flecha: recta, curva o en pico, y
/// para el bloqueo+continuación con dos tramos (cada uno con su curva).
List<List<double>> arrowLine(PlayItem a) {
  List<List<double>> seg(List<double> p0, List<double> p1, List<double>? c) {
    if (c == null || c.length < 2) return [p0, p1];
    return a.sharp
        ? [p0, c, p1]
        : quadBezier(p0[0], p0[1], c[0], c[1], p1[0], p1[1], 20);
  }

  if (a.arrowStyle == 'screencont' && a.pts.length >= 3) {
    final c1 = a.ctrl.length >= 2 ? [a.ctrl[0], a.ctrl[1]] : null;
    final c2 = a.ctrl.length >= 4 ? [a.ctrl[2], a.ctrl[3]] : null;
    final out = <List<double>>[];
    out.addAll(seg(a.pts[0], a.pts[1], c1));
    out.addAll(seg(a.pts[1], a.pts[2], c2).skip(1));
    return out;
  }
  if (a.ctrl.length >= 2) {
    return seg(a.pts.first, a.pts.last, [a.ctrl[0], a.ctrl[1]]);
  }
  return a.pts.isNotEmpty ? a.pts : [];
}

/// Punto (normalizado) a la fracción [f] (0..1) del recorrido de una flecha,
/// siguiendo su curva si la tiene, repartido por longitud de arco.
List<double> pointAlongArrow(PlayItem a, double f) {
  if (a.pts.length < 2) {
    return a.pts.isNotEmpty ? a.pts.first : [a.x, a.y];
  }
  final line = arrowLine(a);
  final cum = <double>[0];
  double total = 0;
  for (var i = 0; i + 1 < line.length; i++) {
    final dx = line[i + 1][0] - line[i][0], dy = line[i + 1][1] - line[i][1];
    total += math.sqrt(dx * dx + dy * dy);
    cum.add(total);
  }
  if (total == 0) return List<double>.from(line.first);
  final d = f.clamp(0.0, 1.0) * total;
  var s = 0;
  while (s + 2 < line.length && cum[s + 1] < d) {
    s++;
  }
  final segLen = cum[s + 1] - cum[s];
  final lt = segLen == 0 ? 0.0 : (d - cum[s]) / segLen;
  return [
    line[s][0] + (line[s + 1][0] - line[s][0]) * lt,
    line[s][1] + (line[s + 1][1] - line[s][1]) * lt,
  ];
}

/// ¿La jugada tiene recorridos (flechas o entregas con paso asignado)?
bool hasPaths(List<PlayItem> items) => items
    .any((it) => (it.kind == 'arrow' || it.kind == 'dot') && it.order > 0);

/// Nº de pasos de la animación de recorridos (mayor orden asignado).
int pathSteps(List<PlayItem> items) {
  var maxO = 0;
  for (final it in items) {
    if ((it.kind == 'arrow' || it.kind == 'dot') && it.order > maxO) {
      maxO = it.order;
    }
  }
  return maxO;
}

/// Id del jugador más cercano a un punto normalizado (o null).
String? _nearestPlayerId(List<PlayItem> items, List<double> p) {
  String? id;
  double best = 1e9;
  for (final it in items) {
    if (it.kind != 'player') continue;
    final dx = it.x - p[0], dy = it.y - p[1];
    final d = dx * dx + dy * dy;
    if (d < best) {
      best = d;
      id = it.id;
    }
  }
  return id;
}

/// Inicios de ventana de cada paso y duración total (en "beats"). Cada paso
/// puede solaparse con el anterior según su propio [lead]; si no, usa [overlap].
(Map<int, double>, double) _pathTiming(List<PlayItem> items, double overlap) {
  final orders = <int>{};
  for (final it in items) {
    if ((it.kind == 'arrow' || it.kind == 'dot') && it.order > 0) {
      orders.add(it.order);
    }
  }
  if (orders.isEmpty) return (<int, double>{}, 0.0);
  final sorted = orders.toList()..sort();
  double leadOf(int o) {
    double m = 0;
    var any = false;
    for (final it in items) {
      if (it.kind == 'arrow' && it.order == o && it.lead > 0) {
        m = math.max(m, it.lead);
        any = true;
      }
    }
    return any ? m.clamp(0.0, 0.9) : overlap.clamp(0.0, 0.85);
  }

  final winStart = <int, double>{};
  int? prev;
  for (final o in sorted) {
    winStart[o] = prev == null ? 0.0 : winStart[prev]! + (1 - leadOf(o));
    prev = o;
  }
  return (winStart, winStart[sorted.last]! + 1);
}

/// Un balón durante la animación: portador inicial (o posición suelta) y la
/// cadena de eventos (pases/tiros/entregas) que le afectan, en orden.
class _Ball {
  final String? initHolder;
  final List<double>? initRest;
  String? holder; // portador "en curso" mientras se asignan los eventos
  final List<PlayItem> events = [];
  _Ball(this.initHolder, this.initRest) : holder = initHolder;
}

/// Anima la jugada por recorridos para [t] en [0,1]. Cada paso puede solaparse
/// con el anterior (por su lead) o de forma global con [overlap].
/// - Flechas con dueño (owner) → ese jugador las recorre en su paso.
/// - Flechas de pase (dashed con paso) → el BALÓN vuela por ellas en ese paso.
/// El balón acompaña a su portador el resto del tiempo.
List<PlayItem> interpolatePaths(List<PlayItem> items, double t,
    {double overlap = 0, String court = 'half'}) {
  final timing = _pathTiming(items, overlap);
  final winStartMap = timing.$1;
  if (winStartMap.isEmpty) return items;
  final totalBeats = timing.$2;
  final tau = t.clamp(0.0, 1.0) * totalBeats;
  double winStart(int order) => winStartMap[order] ?? 0;

  final movement = items
      .where((it) =>
          it.kind == 'arrow' &&
          it.owner.isNotEmpty &&
          isMovementStyle(it.arrowStyle) &&
          it.order > 0)
      .toList();
  // Eventos de balón por orden: pases (dashed), tiros (shot) y entregas (dot).
  final ballEvents = items
      .where((it) =>
          it.order > 0 &&
          ((it.kind == 'arrow' &&
                  (it.arrowStyle == 'dashed' || it.arrowStyle == 'shot')) ||
              it.kind == 'dot'))
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  // Posición de un jugador en un instante [atTau] (según sus flechas).
  List<double> posAt(PlayItem player, double atTau) {
    double nx = player.x, ny = player.y;
    final mine = movement.where((a) => a.owner == player.id).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final a in mine) {
      if (atTau >= winStart(a.order) + 1) {
        nx = a.pts.last[0];
        ny = a.pts.last[1];
      }
    }
    for (final a in mine) {
      final ws = winStart(a.order);
      if (atTau >= ws && atTau < ws + 1) {
        final s = a.spd <= 0 ? 1.0 : a.spd;
        final p = pointAlongArrow(a, ((atTau - ws) * s).clamp(0.0, 1.0));
        nx = p[0];
        ny = p[1];
      }
    }
    return [nx, ny];
  }

  // 1) Posición de cada jugador en el instante actual.
  final playerPos = <String, List<double>>{};
  for (final it in items) {
    if (it.kind == 'player') playerPos[it.id] = posAt(it, tau);
  }

  // Receptor de un pase: explícito (target) o el jugador más cercano al final
  // EN EL INSTANTE EN QUE LLEGA EL BALÓN (así queda fijo aunque luego se mueva).
  String? receiverOf(PlayItem pass) {
    if (pass.target.isNotEmpty) return pass.target;
    final passer = pass.owner.isNotEmpty
        ? pass.owner
        : _nearestPlayerId(items, pass.pts.first);
    final ex = pass.pts.last[0], ey = pass.pts.last[1];
    final atTau = winStart(pass.order) + 1; // llegada del balón
    String? id;
    double best = 0.14;
    for (final it in items) {
      if (it.kind != 'player' || it.id == passer) continue;
      final pos = posAt(it, atTau);
      final dx = pos[0] - ex, dy = pos[1] - ey;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < best) {
        best = d;
        id = it.id;
      }
    }
    return id;
  }

  // Quién ejecuta un evento (pasador/tirador/entregador).
  String? actorOf(PlayItem ev) => ev.owner.isNotEmpty
      ? ev.owner
      : (ev.kind == 'arrow'
          ? _nearestPlayerId(items, ev.pts.first)
          : _nearestPlayerId(items, [ev.x, ev.y]));

  // 2) Balones: uno por cada balón del jugador (hasBall/2 balones) y por cada
  //    'ball' suelto.
  final balls = <_Ball>[];
  for (final it in items) {
    if (it.kind == 'player') {
      for (var i = 0; i < it.ballCount; i++) {
        balls.add(_Ball(it.id, null));
      }
    }
  }
  for (final it in items) {
    if (it.kind == 'ball') balls.add(_Ball(null, [it.x, it.y]));
  }
  if (balls.isEmpty && ballEvents.isNotEmpty) {
    balls.add(_Ball(actorOf(ballEvents.first), null));
  }

  // Asigna cada evento al balón cuyo portador actual lo ejecuta.
  for (final ev in ballEvents) {
    final actor = actorOf(ev);
    _Ball? ball;
    for (final b in balls) {
      if (actor != null && b.holder == actor) {
        ball = b;
        break;
      }
    }
    ball ??= balls.isNotEmpty ? balls.first : null;
    if (ball == null) continue;
    ball.events.add(ev);
    if (ev.kind == 'dot') {
      ball.holder = ev.fake
          ? (ev.owner.isNotEmpty ? ev.owner : ball.holder)
          : (ev.target.isNotEmpty ? ev.target : ball.holder);
    } else if (ev.arrowStyle == 'shot') {
      ball.holder = null;
    } else {
      ball.holder =
          ev.target.isNotEmpty ? ev.target : (receiverOf(ev) ?? ball.holder);
    }
  }

  // Posición de un balón en el instante actual.
  List<double>? ballPosOf(_Ball ball) {
    String? holder = ball.initHolder;
    List<double>? rest = ball.initRest;
    PlayItem? activeEvent;
    for (final ev in ball.events) {
      final ws = winStart(ev.order);
      if (tau >= ws + 1) {
        if (ev.kind == 'dot') {
          holder = ev.fake
              ? (ev.owner.isNotEmpty ? ev.owner : holder)
              : (ev.target.isNotEmpty ? ev.target : holder);
          rest = [ev.x, ev.y];
        } else if (ev.arrowStyle == 'shot') {
          holder = null;
          rest = basketPos(court, ev.pts.last);
        } else {
          holder = receiverOf(ev) ?? holder;
          rest = [ev.pts.last[0], ev.pts.last[1]];
        }
      } else if (tau >= ws && tau < ws + 1) {
        activeEvent = ev;
      }
    }
    if (activeEvent != null) {
      if (activeEvent.kind == 'dot') return [activeEvent.x, activeEvent.y];
      final s = activeEvent.spd <= 0 ? 1.0 : activeEvent.spd;
      final f = ((tau - winStart(activeEvent.order)) * s).clamp(0.0, 1.0);
      if (activeEvent.arrowStyle == 'shot') {
        final start = activeEvent.pts.first;
        final basket = basketPos(court, activeEvent.pts.last);
        return [
          start[0] + (basket[0] - start[0]) * f,
          start[1] + (basket[1] - start[1]) * f
        ];
      }
      return pointAlongArrow(activeEvent, f);
    }
    if (holder != null && playerPos.containsKey(holder)) {
      return playerPos[holder];
    }
    if (holder != null) {
      final p = items.firstWhere((it) => it.id == holder,
          orElse: () => const PlayItem(kind: 'player'));
      return [p.x, p.y];
    }
    return rest;
  }

  // 3) Salida: jugadores movidos (sin su balón), balones aparte. La entrega
  //    (mano a mano) desaparece durante la animación.
  final out = <PlayItem>[];
  for (final it in items) {
    if (it.kind == 'player') {
      final pos = playerPos[it.id] ?? [it.x, it.y];
      // Sin balones "de foto": los balones se dibujan animados aparte.
      out.add(it.copyWith(x: pos[0], y: pos[1], hasBall: false, balls: 0));
    } else if (it.kind == 'ball' || it.kind == 'dot') {
      // los balones se dibujan aparte; la entrega no se muestra al animar
    } else {
      out.add(it);
    }
  }
  final ballPositions = <List<double>>[];
  for (final ball in balls) {
    final pos = ballPosOf(ball);
    if (pos != null) ballPositions.add([pos[0], pos[1]]);
  }
  // Separar balones que caen en el mismo punto (p. ej. 2 balones de un jugador).
  for (var i = 0; i < ballPositions.length; i++) {
    var shift = 0;
    for (var j = 0; j < i; j++) {
      if ((ballPositions[i][0] - ballPositions[j][0]).abs() < 0.02 &&
          (ballPositions[i][1] - ballPositions[j][1]).abs() < 0.02) {
        shift++;
      }
    }
    if (shift > 0) {
      ballPositions[i][0] =
          (ballPositions[i][0] + 0.035 * shift).clamp(0.0, 1.0);
    }
  }
  for (final pos in ballPositions) {
    out.add(PlayItem(kind: 'ball', x: pos[0], y: pos[1]));
  }
  return out;
}

/// Nº total de pasos de la animación de una jugada: suma de los recorridos de
/// cada fotograma; si ninguno tiene recorridos pero hay varios, sus transiciones.
int animTotalSteps(List<List<PlayItem>> frames) {
  var total = 0;
  for (final f in frames) {
    total += pathSteps(f);
  }
  if (total == 0 && frames.length > 1) return frames.length - 1;
  return total;
}

/// Duración (en "beats") del recorrido de un fotograma, teniendo en cuenta el
/// solapamiento (por paso o global).
double frameBeats(List<PlayItem> f, double overlap) => _pathTiming(f, overlap).$2;

/// Duración total (en "beats") de la animación de una jugada.
double animTotalBeats(List<List<PlayItem>> frames, double overlap) {
  double total = 0;
  for (final f in frames) {
    total += frameBeats(f, overlap);
  }
  if (total == 0 && frames.length > 1) return (frames.length - 1).toDouble();
  return total;
}

/// Elementos animados encadenando los recorridos de cada fotograma (y, si no
/// hay recorridos, la interpolación entre fotogramas), para [t] en [0,1].
List<PlayItem> animatedFrames(List<List<PlayItem>> frames, double t,
    {double overlap = 0, String court = 'half'}) {
  if (frames.isEmpty) return const [];
  double total = 0;
  for (final f in frames) {
    total += frameBeats(f, overlap);
  }
  if (total == 0) {
    if (frames.length > 1) {
      return interpolateFrames(frames, t * (frames.length - 1));
    }
    return frames.first;
  }
  final tau = t.clamp(0.0, 1.0) * total;
  var acc = 0.0;
  for (final f in frames) {
    final b = frameBeats(f, overlap);
    if (b == 0) continue;
    if (tau < acc + b) {
      return interpolatePaths(f, ((tau - acc) / b).clamp(0.0, 1.0),
          overlap: overlap, court: court);
    }
    acc += b;
  }
  for (var i = frames.length - 1; i >= 0; i--) {
    if (pathSteps(frames[i]) > 0) {
      return interpolatePaths(frames[i], 1.0, overlap: overlap, court: court);
    }
  }
  return frames.last;
}

List<PlayItem> animatedItems(Play play, double t) => animatedFrames(
    play.framesOrSingle, t,
    overlap: play.overlap, court: play.court);

/// ¿La jugada se puede animar (recorridos o varios fotogramas)?
bool playHasAnimation(Play play) =>
    animTotalSteps(play.framesOrSingle) > 0;

/// Devuelve los elementos interpolados de una lista de fotogramas para un
/// instante [t] en [0, nFrames-1]. Empareja por [id] cuando existe (robusto
/// ante añadir/borrar/reordenar elementos); si no, cae al emparejado por índice.
List<PlayItem> interpolateFrames(List<List<PlayItem>> frames, double t) {
  final n = frames.length;
  if (n < 2) return frames.isEmpty ? const [] : frames[0];
  final tt = t.clamp(0.0, (n - 1).toDouble());
  final seg = tt.floor().clamp(0, n - 2);
  final f = tt - seg;
  final a = frames[seg], b = frames[seg + 1];

  final aIds = a.every((it) => it.id.isNotEmpty);
  final bIds = b.every((it) => it.id.isNotEmpty);
  if (aIds && bIds) {
    final bById = {for (final it in b) it.id: it};
    final aIdSet = a.map((it) => it.id).toSet();
    final out = <PlayItem>[];
    for (final ia in a) {
      final ib = bById[ia.id];
      if (ib != null) {
        out.add(lerpPlayItem(ia, ib, f));
      } else if (f < 0.5) {
        out.add(ia); // se borra: visible solo en la 1ª mitad del tramo
      }
    }
    for (final ib in b) {
      // aparece en el siguiente fotograma: visible en la 2ª mitad del tramo
      if (!aIdSet.contains(ib.id) && f >= 0.5) out.add(ib);
    }
    return out;
  }

  // Fallback por índice (jugadas sin id).
  final count = math.min(a.length, b.length);
  final out = <PlayItem>[];
  for (var i = 0; i < count; i++) {
    out.add(lerpPlayItem(a[i], b[i], f));
  }
  for (var i = count; i < a.length; i++) {
    out.add(a[i]);
  }
  return out;
}

/// Muestrea una curva de Bézier cuadrática a→ctrl→b en [segs] tramos, en
/// pixeles. Usada por app y PDF para las flechas curvas.
List<List<double>> quadBezier(double ax, double ay, double cx, double cy,
    double bx, double by,
    [int segs = 20]) {
  final res = <List<double>>[];
  for (var i = 0; i <= segs; i++) {
    final t = i / segs;
    final mt = 1 - t;
    final x = mt * mt * ax + 2 * mt * t * cx + t * t * bx;
    final y = mt * mt * ay + 2 * mt * t * cy + t * t * by;
    res.add([x, y]);
  }
  return res;
}

/// Genera una polilínea ondulada (serpiente/dribbling) a lo largo de una
/// polilínea base (recta o curva), con amplitud [amp]. Usada por app y PDF.
List<List<double>> waveAlongPolyline(List<List<double>> path, double amp) {
  if (path.length < 2) return path;
  // Longitud acumulada.
  final cum = <double>[0];
  double total = 0;
  for (var i = 0; i + 1 < path.length; i++) {
    final dx = path[i + 1][0] - path[i][0], dy = path[i + 1][1] - path[i][1];
    total += math.sqrt(dx * dx + dy * dy);
    cum.add(total);
  }
  if (total == 0) return path;
  const segs = 64;
  final waves = (total / 24).clamp(3, 14);
  final res = <List<double>>[];
  var s = 0;
  for (var i = 0; i <= segs; i++) {
    final t = i / segs;
    final d = t * total;
    while (s + 2 < path.length && cum[s + 1] < d) {
      s++;
    }
    final segLen = cum[s + 1] - cum[s];
    final lt = segLen == 0 ? 0.0 : (d - cum[s]) / segLen;
    final ax = path[s][0], ay = path[s][1];
    final bx = path[s + 1][0], by = path[s + 1][1];
    final x = ax + (bx - ax) * lt, y = ay + (by - ay) * lt;
    var tx = bx - ax, ty = by - ay;
    final tl = math.sqrt(tx * tx + ty * ty);
    if (tl > 0) {
      tx /= tl;
      ty /= tl;
    }
    final px = -ty, py = tx; // perpendicular a la tangente
    final taper = (t < 0.06 || t > 0.94) ? 0.25 : 1.0;
    final off = math.sin(t * waves * math.pi * 2) * amp * taper;
    res.add([x + px * off, y + py * off]);
  }
  return res;
}

/// Genera una polilínea ondulada (serpiente/dribbling) entre dos puntos en
/// pixeles, con amplitud [amp]. Usada por la app y por el PDF.
List<List<double>> wavePolyline(
    double ax, double ay, double bx, double by, double amp) {
  final dx = bx - ax, dy = by - ay;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len == 0) {
    return [
      [ax, ay],
      [bx, by]
    ];
  }
  final ux = dx / len, uy = dy / len; // unidad
  final px = -uy, py = ux; // perpendicular
  const segs = 48;
  final waves = (len / 24).clamp(3, 14);
  final res = <List<double>>[];
  for (var i = 0; i <= segs; i++) {
    final t = i / segs;
    final bxp = ax + dx * t, byp = ay + dy * t;
    // atenuar en los extremos para que salga limpio
    final taper = (t < 0.06 || t > 0.94) ? 0.25 : 1.0;
    final off = math.sin(t * waves * math.pi * 2) * amp * taper;
    res.add([bxp + px * off, byp + py * off]);
  }
  return res;
}
