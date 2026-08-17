import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/play_data.dart';

/// Estilos de flecha que admiten curvarse (punto de control).
bool curvableStyle(String s) =>
    s == '' ||
    s == 'solid' ||
    s == 'dashed' ||
    s == 'defense' ||
    s == 'snake' ||
    s == 'screen' ||
    s == 'screen2';

/// Ruta del asset de la pista según el tipo.
String courtAsset(String court) => court == 'full'
    ? 'assets/images/pista_entera.jpg'
    : 'assets/images/media_pista.png';

/// Muestra una jugada (media pista o pista entera) a cualquier tamaño, usando
/// la imagen de pista de fondo.
class PlayView extends StatelessWidget {
  final Play play;
  const PlayView({super.key, required this.play});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: play.aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(courtAsset(play.court), fit: BoxFit.fill),
            CustomPaint(painter: PlayPainter(play), size: Size.infinite),
          ],
        ),
      ),
    );
  }
}

/// Como [PlayView] pero, si la jugada tiene varios fotogramas, muestra un
/// botón ▶ para reproducir la animación.
class AnimatedPlayView extends StatefulWidget {
  final Play play;
  const AnimatedPlayView({super.key, required this.play});

  @override
  State<AnimatedPlayView> createState() => _AnimatedPlayViewState();
}

class _AnimatedPlayViewState extends State<AnimatedPlayView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _playing = false;
  bool _atEnd = false; // tras reproducir, se queda en el último fotograma

  List<List<PlayItem>> get _frames => widget.play.framesOrSingle;
  bool get _canAnimate => playHasAnimation(widget.play);
  double get _beats => animTotalBeats(_frames, widget.play.overlap);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() {
        if (_playing) setState(() {});
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _playing) {
          setState(() {
            _playing = false;
            _atEnd = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_canAnimate) return;
    if (_playing) {
      setState(() {
        _playing = false;
        _anim.stop();
      });
      return;
    }
    setState(() {
      _playing = true;
      _atEnd = false;
      final spd = widget.play.speed <= 0 ? 1.0 : widget.play.speed;
      _anim.duration = Duration(
          milliseconds: (1500 * (_beats < 0.5 ? 0.5 : _beats) / spd).round());
      _anim.forward(from: 0); // una pasada de inicio a fin
    });
  }

  int _curFrameIdx() {
    final n = _frames.length;
    if (n < 2) return 0;
    if (_playing) return (_anim.value * (n - 1)).round().clamp(0, n - 1);
    return _atEnd ? n - 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final items = _playing
        ? animatedFrames(_frames, _anim.value,
            overlap: widget.play.overlap, court: widget.play.court)
        : (_atEnd
            ? animatedFrames(_frames, 1.0,
                overlap: widget.play.overlap, court: widget.play.court)
            : widget.play.items);
    final frameTitle = widget.play.frameTitleAt(_curFrameIdx());
    return AspectRatio(
      aspectRatio: widget.play.aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(courtAsset(widget.play.court), fit: BoxFit.fill),
            CustomPaint(
              painter: PlayPainter(Play(
                  court: widget.play.court,
                  items: items,
                  itemScale: widget.play.itemScale)),
              size: Size.infinite,
            ),
            if (_canAnimate)
              Positioned(
                right: 6,
                bottom: 6,
                child: Material(
                  color: (_playing ? Colors.red : Colors.green).withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggle,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(_playing ? Icons.stop : Icons.play_arrow,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            if (_canAnimate && !_playing)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${_frames.length} pasos',
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
            if (frameTitle.isNotEmpty)
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(frameTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pinta solo los elementos de la jugada (la pista es una imagen de fondo).
class PlayPainter extends CustomPainter {
  final Play play;
  final List<PlayItem>? extra; // elementos en curso (editor)
  final int? selected; // índice resaltado (editor)
  final Set<int>? selectedSet; // varios resaltados (selección múltiple)
  final Rect? marquee; // marco de selección en curso (coords normalizadas)
  PlayPainter(this.play,
      {this.extra, this.selected, this.selectedSet, this.marquee});

  @override
  void paint(Canvas canvas, Size size) {
    // En pista entera los símbolos se reducen (la pista abarca más campo).
    final courtK = play.itemScale * (play.court == 'full' ? 0.52 : 1.0);
    paintPlayItems(canvas, size, play.items, courtK);
    if (extra != null) paintPlayItems(canvas, size, extra!, courtK);
    if (selectedSet != null) {
      for (final i in selectedSet!) {
        if (i >= 0 && i < play.items.length) {
          _highlight(canvas, size, play.items[i]);
        }
      }
    }
    if (selected != null &&
        selected! >= 0 &&
        selected! < play.items.length) {
      _highlight(canvas, size, play.items[selected!]);
    }
    if (marquee != null) {
      final r = Rect.fromLTRB(marquee!.left * size.width,
          marquee!.top * size.height, marquee!.right * size.width,
          marquee!.bottom * size.height);
      canvas.drawRect(r, Paint()..color = const Color(0x2200BCD4));
      canvas.drawRect(
          r,
          Paint()
            ..color = const Color(0xFF00BCD4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant PlayPainter old) => true;
}

void _highlight(Canvas c, Size s, PlayItem it) {
  final p = Paint()
    ..color = const Color(0xFF00BCD4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  if ((it.kind == 'arrow' || it.kind == 'zone') && it.pts.isNotEmpty) {
    final xs = it.pts.map((e) => e[0] * s.width);
    final ys = it.pts.map((e) => e[1] * s.height);
    final rect = Rect.fromLTRB(
      xs.reduce(math.min) - 8,
      ys.reduce(math.min) - 8,
      xs.reduce(math.max) + 8,
      ys.reduce(math.max) + 8,
    );
    c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), p);
    // Tiradores de extremos (naranja): cola y punta, para cambiar dirección.
    if (it.pts.length >= 2) {
      _handleDot(c, Offset(it.pts.first[0] * s.width, it.pts.first[1] * s.height),
          const Color(0xFFFF9800));
      _handleDot(c, Offset(it.pts.last[0] * s.width, it.pts.last[1] * s.height),
          const Color(0xFFFF9800));
    }
    // Tirador de curva (azul): punto de control o punto medio (solo 2 puntos).
    if (it.kind == 'arrow' &&
        curvableStyle(it.arrowStyle) &&
        it.pts.length <= 2) {
      final h = it.ctrl.length >= 2
          ? Offset(it.ctrl[0] * s.width, it.ctrl[1] * s.height)
          : Offset((it.pts.first[0] + it.pts.last[0]) / 2 * s.width,
              (it.pts.first[1] + it.pts.last[1]) / 2 * s.height);
      _handleDot(c, h, const Color(0xFF00BCD4));
    }
    // Bloqueo+continuación: dos tiradores de curva (uno por tramo).
    if (it.kind == 'arrow' &&
        it.arrowStyle == 'screencont' &&
        it.pts.length >= 3) {
      Offset midp(List<double> a, List<double> b) => Offset(
          (a[0] + b[0]) / 2 * s.width, (a[1] + b[1]) / 2 * s.height);
      final h1 = it.ctrl.length >= 2
          ? Offset(it.ctrl[0] * s.width, it.ctrl[1] * s.height)
          : midp(it.pts[0], it.pts[1]);
      final h2 = it.ctrl.length >= 4
          ? Offset(it.ctrl[2] * s.width, it.ctrl[3] * s.height)
          : midp(it.pts[1], it.pts[2]);
      _handleDot(c, h1, const Color(0xFF00BCD4));
      _handleDot(c, h2, const Color(0xFF00BCD4));
    }
  } else {
    c.drawCircle(Offset(it.x * s.width, it.y * s.height),
        s.width * 0.055 * it.scale + 6, p);
  }
}

void _handleDot(Canvas c, Offset o, Color color) {
  c.drawCircle(o, 6, Paint()..color = color);
  c.drawCircle(
      o,
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
}

void paintCourt(Canvas c, Size s, String court) {
  final p = Paint()
    ..color = Colors.grey.shade500
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, s.width * 0.006);
  final w = s.width, h = s.height;
  final m = w * 0.02;
  c.drawRect(Rect.fromLTWH(m, m, w - 2 * m, h - 2 * m), p);

  if (court == 'full') {
    c.drawLine(Offset(w / 2, m), Offset(w / 2, h - m), p);
    c.drawCircle(Offset(w / 2, h / 2), h * 0.12, p);
    final keyW = w * 0.13, keyH = h * 0.44;
    c.drawRect(Rect.fromLTWH(m, (h - keyH) / 2, keyW, keyH), p);
    c.drawRect(Rect.fromLTWH(w - m - keyW, (h - keyH) / 2, keyW, keyH), p);
    c.drawCircle(Offset(m + keyW, h / 2), keyH * 0.22, p);
    c.drawCircle(Offset(w - m - keyW, h / 2), keyH * 0.22, p);
    c.drawCircle(Offset(m + w * 0.025, h / 2), w * 0.01, p);
    c.drawCircle(Offset(w - m - w * 0.025, h / 2), w * 0.01, p);
  } else {
    // media pista, aro arriba
    final keyW = w * 0.32, keyH = h * 0.38;
    c.drawRect(Rect.fromLTWH((w - keyW) / 2, m, keyW, keyH), p);
    c.drawCircle(Offset(w / 2, m + keyH), keyW / 2, p);
    c.drawCircle(Offset(w / 2, m + h * 0.025), w * 0.02, p);
    // línea de 3 puntos
    c.drawArc(
      Rect.fromCircle(center: Offset(w / 2, m), radius: w * 0.45),
      math.pi * 0.12,
      math.pi * 0.76,
      false,
      p,
    );
  }
}

void paintPlayItems(Canvas c, Size s, List<PlayItem> items, double scale) {
  final k = scale;
  final sw = math.max(2.0, s.width * 0.012);
  final off = Paint()
    ..color = const Color(0xFF1565C0) // atacante (O) azul
    ..strokeWidth = sw
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final def = Paint()
    ..color = const Color(0xFF212121) // defensor (X) negro
    ..strokeWidth = sw
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final arrow = Paint()
    ..color = const Color(0xFFD32F2F)
    ..strokeWidth = sw
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final cone = Paint()
    ..color = const Color(0xFFF9A825)
    ..style = PaintingStyle.fill;
  final ballP = Paint()
    ..color = const Color(0xFFEF6C00) // balón naranja
    ..style = PaintingStyle.fill;

  // Zonas primero (van de fondo).
  for (final it in items) {
    if (it.kind == 'zone' && it.pts.length >= 2) {
      final a = Offset(it.pts[0][0] * s.width, it.pts[0][1] * s.height);
      final b = Offset(it.pts[1][0] * s.width, it.pts[1][1] * s.height);
      final rect = Rect.fromPoints(a, b);
      c.drawRect(rect, Paint()..color = const Color(0x33FFC107));
      c.drawRect(
          rect,
          Paint()
            ..color = const Color(0xAAFFA000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  final crossP = Paint()
    ..color = const Color(0xFF6A1B9A) // cambio de mano morado
    ..strokeWidth = sw
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  for (final it in items) {
    final es = k * it.scale; // tamaño efectivo del elemento
    if (it.kind == 'player') {
      final o = Offset(it.x * s.width, it.y * s.height);
      final r = s.width * 0.032 * es;
      final color =
          it.team == 'off' ? const Color(0xFF1565C0) : const Color(0xFF212121);
      // Rotación efectiva (grados→rad). El antiguo "voltear" del defensor = 180º.
      final rot =
          (it.rot + (it.team == 'def' && it.flip ? 180 : 0)) * math.pi / 180;
      if (it.team == 'off') {
        c.drawCircle(o, r, off);
        if (it.label.isNotEmpty) {
          _numberLabel(c, o, it.label, color, s.width * 0.04 * es);
        }
      } else {
        // Defensor: arco (∩) orientable en 360º.
        final start = math.pi + rot;
        c.drawArc(Rect.fromCircle(center: o, radius: r), start, math.pi, false,
            def);
        if (it.label.isNotEmpty) {
          // Número en el lado abierto del arco (donde está el atacante).
          final openDir = start - math.pi / 2;
          final lo = o +
              Offset(math.cos(openDir), math.sin(openDir)) * (r * 0.55);
          _numberLabel(c, lo, it.label, color, s.width * 0.032 * es);
        }
      }
      final nballs = it.ballCount;
      if (nballs > 0) {
        // Los balones acompañan la orientación. Con 2, van a ambos lados
        // (ejercicio de bote con dos balones).
        final base = it.team == 'off' ? -math.pi / 4 : 0.0;
        for (var bi = 0; bi < nballs; bi++) {
          final ang =
              base + rot + (nballs == 1 ? 0.0 : (bi - (nballs - 1) / 2) * 0.9);
          c.drawCircle(o + Offset(math.cos(ang), math.sin(ang)) * (r * 1.5),
              r * 0.5, ballP);
        }
      }
    } else if (it.kind == 'cone') {
      _drawCone(c, Offset(it.x * s.width, it.y * s.height), cone,
          s.width * 0.05 * es);
    } else if (it.kind == 'dot') {
      // Entrega mano a mano: barra (entre las dos líneas) + el balón.
      final o = Offset(it.x * s.width, it.y * s.height);
      final r = s.width * 0.022 * es;
      final rot = it.rot * math.pi / 180;
      final dir = Offset(math.cos(rot), math.sin(rot));
      final barP = Paint()
        ..color = const Color(0xFF212121)
        ..strokeWidth = math.max(2.0, s.width * 0.011 * es)
        ..strokeCap = StrokeCap.round;
      c.drawLine(o - dir * r * 1.7, o + dir * r * 1.7, barP);
      c.drawCircle(o, r * 0.7, ballP);
      c.drawCircle(
          o,
          r * 0.7,
          Paint()
            ..color = const Color(0xFF7A3B00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.8, r * 0.1));
      if (it.order > 0) {
        _orderBadge(c, o + Offset(r * 1.6, -r * 1.6), it.order,
            math.max(7.0, s.width * 0.015 * es));
      }
    } else if (it.kind == 'ball') {
      // Balón suelto (independiente del jugador).
      final o = Offset(it.x * s.width, it.y * s.height);
      final r = s.width * 0.02 * es;
      c.drawCircle(o, r, ballP);
      final line = Paint()
        ..color = const Color(0xFF7A3B00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.12);
      c.drawCircle(o, r, line);
      c.drawLine(o + Offset(-r, 0), o + Offset(r, 0), line);
      c.drawLine(o + Offset(0, -r), o + Offset(0, r), line);
    } else if (it.kind == 'cross') {
      _drawX(c, Offset(it.x * s.width, it.y * s.height), crossP,
          s.width * 0.022 * es);
    } else if (it.kind == 'text' && it.label.isNotEmpty) {
      _textLabel(c, Offset(it.x * s.width, it.y * s.height), it.label,
          s.width * 0.036 * es);
    } else if (it.kind == 'arrow' && it.pts.length >= 2) {
      _drawArrow(c, it, s, arrow, es);
    }
  }
}

void _textLabel(Canvas c, Offset o, String text, double size) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            color: const Color(0xFF212121),
            fontSize: size,
            fontWeight: FontWeight.w600)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: 200);
  tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
}

void _numberLabel(Canvas c, Offset o, String label, Color color, double size) {
  final tp = TextPainter(
    text: TextSpan(
        text: label,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
}

void _drawX(Canvas c, Offset o, Paint p, double r) {
  c.drawLine(o + Offset(-r, -r), o + Offset(r, r), p);
  c.drawLine(o + Offset(-r, r), o + Offset(r, -r), p);
}

void _drawCone(Canvas c, Offset o, Paint p, double r) {
  final path = Path()
    ..moveTo(o.dx, o.dy - r)
    ..lineTo(o.dx - r * 0.85, o.dy + r * 0.8)
    ..lineTo(o.dx + r * 0.85, o.dy + r * 0.8)
    ..close();
  c.drawPath(path, p);
}

void _drawArrow(Canvas c, PlayItem it, Size s, Paint p, double k) {
  final pl = it.pts.map((e) => Offset(e[0] * s.width, e[1] * s.height)).toList();
  final a = pl.first, b = pl.last;
  final headLen = math.max(10.0, s.width * 0.03 * k);
  p.strokeWidth = math.max(1.0, s.width * 0.01 * k);

  // Trazado del cuerpo de la flecha: recto, curvo, en pico o a mano alzada.
  List<Offset> shaft() {
    if (it.pts.length > 2 && it.ctrl.isEmpty) return pl; // mano alzada (bote)
    if (it.ctrl.length >= 2) {
      final c = Offset(it.ctrl[0] * s.width, it.ctrl[1] * s.height);
      if (it.sharp) return [a, c, b]; // pico (vértice)
      return quadBezier(a.dx, a.dy, c.dx, c.dy, b.dx, b.dy)
          .map((e) => Offset(e[0], e[1]))
          .toList();
    }
    return [a, b];
  }

  if (it.arrowStyle == 'shot') {
    // Tiro (=>): la doble línea (=) más fina que la flecha (>).
    final full = p.strokeWidth;
    final thin = math.max(0.8, full * 0.5);
    final dir = (b - a).direction;
    final u = Offset(math.cos(dir), math.sin(dir));
    final perp = Offset(-u.dy, u.dx) * (full * 0.8 + 0.7);
    final shaftEnd = b - u * (headLen * 0.7);
    p.strokeWidth = thin;
    c.drawLine(a + perp, shaftEnd + perp, p);
    c.drawLine(a - perp, shaftEnd - perp, p);
    p.strokeWidth = full;
    _head(c, a, b, p, headLen);
    p.strokeWidth = full;
    return;
  }
  if (it.arrowStyle == 'dashed') {
    final sh = shaft();
    _dashedPoly(c, sh, p);
    _head(c, sh[sh.length - 2], b, p, headLen);
  } else if (it.arrowStyle == 'snake') {
    // Bote (serpiente): línea más fina que termina en la punta de la flecha.
    // Puede ser recta o curva (sigue el trazado del punto de control).
    p.strokeWidth = math.max(1.0, s.width * 0.007 * k);
    final sh = shaft();
    final wave = waveAlongPolyline(
        sh.map((o) => [o.dx, o.dy]).toList(), s.width * 0.02 * k);
    final path = Path()..moveTo(wave.first[0], wave.first[1]);
    for (var i = 1; i < wave.length; i++) {
      path.lineTo(wave[i][0], wave[i][1]);
    }
    path.lineTo(b.dx, b.dy); // acabar exactamente en la punta
    c.drawPath(path, p);
    _head(c, sh[sh.length - 2], b, p, headLen); // punta según la tangente final
  } else if (it.arrowStyle == 'screen') {
    final sh = shaft();
    _poly(c, sh, p);
    _bar(c, sh[sh.length - 2], b, p, headLen, doubleBar: false);
  } else if (it.arrowStyle == 'screen2') {
    final sh = shaft();
    _poly(c, sh, p);
    _bar(c, sh[sh.length - 2], b, p, headLen, doubleBar: true);
  } else if (it.arrowStyle == 'defense') {
    final sh = shaft();
    _poly(c, sh, p);
    _hook(c, b, (b - sh[sh.length - 2]).direction, p, headLen, it.flip);
  } else if (it.arrowStyle == 'screencont') {
    // Bloqueo y continuación: dos tramos (cada uno con su curva) + barra.
    final line =
        arrowLine(it).map((e) => Offset(e[0] * s.width, e[1] * s.height)).toList();
    _poly(c, line, p);
    if (pl.length >= 2) _bar(c, pl[0], pl[1], p, headLen * 0.8);
    if (line.length >= 2) _head(c, line[line.length - 2], line.last, p, headLen);
  } else if (it.arrowStyle == 'chevrons') {
    _chevrons(c, a, b, p, headLen);
  } else {
    // Corte / desplazamiento (recto o curvo).
    final sh = shaft();
    _poly(c, sh, p);
    _head(c, sh[sh.length - 2], b, p, headLen);
  }
  // Badge con el número de paso del recorrido asignado.
  if (it.order > 0 && pl.isNotEmpty) {
    _orderBadge(c, pl.first, it.order, math.max(7.0, s.width * 0.016 * k));
  }
}

void _orderBadge(Canvas c, Offset o, int n, double r) {
  c.drawCircle(o, r, Paint()..color = const Color(0xFFD32F2F));
  c.drawCircle(
      o,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
  final tp = TextPainter(
    text: TextSpan(
        text: '$n',
        style: TextStyle(
            color: Colors.white,
            fontSize: r * 1.2,
            fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
}

void _poly(Canvas c, List<Offset> pts, Paint p) {
  if (pts.length < 2) return;
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx, pts[i].dy);
  }
  c.drawPath(path, p);
}

void _dashedPoly(Canvas c, List<Offset> pts, Paint p) {
  if (pts.length < 2) return;
  // Longitud total para dimensionar el guion.
  double total = 0;
  for (var i = 0; i + 1 < pts.length; i++) {
    total += (pts[i + 1] - pts[i]).distance;
  }
  final dash = math.max(7.0, total * 0.04), gap = dash * 0.7;
  bool draw = true;
  double rem = dash;
  var prev = pts.first;
  for (var i = 1; i < pts.length; i++) {
    var seg = pts[i] - prev;
    var segLen = seg.distance;
    while (segLen > 0) {
      final step = math.min(rem, segLen);
      final dir = seg / seg.distance;
      final next = prev + dir * step;
      if (draw) c.drawLine(prev, next, p);
      prev = next;
      seg = pts[i] - prev;
      segLen -= step;
      rem -= step;
      if (rem <= 0.0001) {
        draw = !draw;
        rem = draw ? dash : gap;
      }
    }
    prev = pts[i];
  }
}

void _hook(Canvas c, Offset tip, double dir, Paint p, double len, bool flip) {
  final r = len * 0.55;
  final sd = flip ? -1.0 : 1.0;
  final center = tip +
      Offset(math.cos(dir + sd * math.pi / 2), math.sin(dir + sd * math.pi / 2)) *
          r;
  c.drawArc(Rect.fromCircle(center: center, radius: r), dir - sd * math.pi / 2,
      sd * math.pi, false, p);
}

void _chevrons(Canvas c, Offset a, Offset b, Paint p, double len) {
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a).direction;
  final u = Offset(math.cos(dir), math.sin(dir));
  final n = math.max(3, (total / (len * 1.3)).floor());
  final step = total / n;
  for (var i = 1; i <= n; i++) {
    final tip = a + u * (step * i);
    _head(c, a, tip, p, len * 0.7);
  }
}

void _bar(Canvas c, Offset from, Offset to, Paint p, double len,
    {bool doubleBar = false}) {
  final dir = (to - from).direction;
  final perp = dir + math.pi / 2;
  final d = Offset(math.cos(perp) * len, math.sin(perp) * len);
  c.drawLine(to - d, to + d, p);
  if (doubleBar) {
    final back = Offset(math.cos(dir), math.sin(dir)) * (len * 0.6);
    c.drawLine((to - back) - d, (to - back) + d, p);
  }
}

void _head(Canvas c, Offset from, Offset to, Paint p, double len) {
  final angle = (to - from).direction;
  const spread = 0.5;
  c.drawLine(
      to,
      to -
          Offset(math.cos(angle - spread) * len,
              math.sin(angle - spread) * len),
      p);
  c.drawLine(
      to,
      to -
          Offset(math.cos(angle + spread) * len,
              math.sin(angle + spread) * len),
      p);
}
