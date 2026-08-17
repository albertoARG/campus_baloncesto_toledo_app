import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../../../../core/globals.dart';
import '../../../../core/utils/file_upload.dart';
import '../../data/models/play_data.dart';
import '../../data/models/play_templates.dart';
import 'play_view.dart';

enum _Tool {
  ninguno,
  mover,
  seleccion,
  atacante,
  defensor,
  entrega,
  balon,
  cono,
  corte,
  despDef,
  pase,
  bote,
  tiro,
  pantalla,
  ciega,
  bloqueoCont,
  paseDef,
  zona,
  texto,
  borrar,
}

/// Un balón al "hornear" el siguiente fotograma: portador o posición suelta.
class _BakedBall {
  String? holder;
  List<double>? rest;
  _BakedBall(this.holder, this.rest);
}

/// Pizarra táctica con convenciones de baloncesto y zoom (1 dedo dibuja, 2
/// dedos hacen zoom/mover). Devuelve un [Play] (datos, no imagen).
class PlayEditorScreen extends StatefulWidget {
  final Play? initial;
  const PlayEditorScreen({super.key, this.initial});

  @override
  State<PlayEditorScreen> createState() => _PlayEditorScreenState();
}

class _PlayEditorScreenState extends State<PlayEditorScreen>
    with SingleTickerProviderStateMixin {
  String _court = 'half';
  _Tool _tool = _Tool.ninguno;
  bool _numbered = true; // colocar jugadores con número
  double _itemScale = 1.0; // tamaño de los símbolos

  // Fotogramas de la jugada (animación). _items apunta al fotograma actual.
  List<List<PlayItem>> _frames = [[]];
  int _frameIdx = 0;
  List<PlayItem> get _items => _frames[_frameIdx];

  // Reproducción de la animación.
  late final AnimationController _anim;
  bool _playing = false;
  bool _atEnd = false; // tras reproducir, se queda en el estado final
  double _speed = 1.0; // velocidad de la animación (0.5 lenta … 2 rápida)
  double _overlap = 0; // solapamiento entre pasos (0 seguidos … 0.6 mucho)
  double? _gifProgress; // progreso de la generación de GIF (0..1) o null

  // Títulos: de la jugada y por fotograma (paralelo a _frames).
  final _titleC = TextEditingController();
  final _frameTitleC = TextEditingController();
  List<String> _frameTitles = [''];

  // Identidad estable de cada elemento (para animar bien entre fotogramas).
  int _idSeq = 0;
  String _newId() => 'i${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}';

  // Historial para deshacer/rehacer (borrados, mover, tamaño, etc.).
  final List<List<List<PlayItem>>> _history = [];
  final List<List<List<PlayItem>>> _redo = [];
  bool _pushedThisGesture = false;

  List<List<PlayItem>> _snapshot() =>
      _frames.map((f) => List<PlayItem>.from(f)).toList();

  void _pushHistory() {
    _history.add(_snapshot());
    if (_history.length > 60) _history.removeAt(0);
    _redo.clear(); // una acción nueva invalida el rehacer
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _redo.add(_snapshot());
      _frames = _history.removeLast();
      if (_frameIdx >= _frames.length) _frameIdx = _frames.length - 1;
      _selected = null;
      _multiSel = {};
      _atEnd = false;
      _syncFrameTitle();
    });
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    setState(() {
      _history.add(_snapshot());
      _frames = _redo.removeLast();
      if (_frameIdx >= _frames.length) _frameIdx = _frames.length - 1;
      _selected = null;
      _multiSel = {};
      _atEnd = false;
      _syncFrameTitle();
    });
  }

  Future<void> _openTemplates() async {
    final tpl = await showDialog<PlayTemplate>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Plantillas de jugada'),
        children: [
          for (final t in playTemplates())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.name),
              ),
            ),
        ],
      ),
    );
    if (tpl == null || !mounted) return;
    if (_items.isNotEmpty || _frames.length > 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Cargar plantilla'),
          content: const Text(
              '¿Reemplazar la jugada actual por la plantilla? Se perderá lo dibujado.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Reemplazar')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _loadTemplate(tpl.play);
  }

  void _loadTemplate(Play p) {
    _pushHistory();
    setState(() {
      _court = p.court;
      _itemScale = p.itemScale;
      _speed = p.speed;
      _frames =
          p.framesOrSingle.map((f) => List<PlayItem>.from(f)).toList();
      _frameTitles = List<String>.from(p.frameTitles);
      _titleC.text = p.title;
      _frameIdx = 0;
      _selected = null;
      _multiSel = {};
      _ensureIds();
      _syncFrameTitle();
    });
  }

  // Genera una imagen PNG del fotograma actual y la descarga (web).
  Future<void> _sharePng() async {
    try {
      const w = 1200.0;
      final h = w / (_court == 'full' ? 1.515 : 1.384);
      final data = await rootBundle.load(courtAsset(_court));
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final court = (await codec.getNextFrame()).image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
      canvas.drawImageRect(
          court,
          Rect.fromLTWH(
              0, 0, court.width.toDouble(), court.height.toDouble()),
          Rect.fromLTWH(0, 0, w, h),
          Paint());
      final courtK = _itemScale * (_court == 'full' ? 0.52 : 1.0);
      paintPlayItems(canvas, Size(w, h), _items, courtK);
      final img = await recorder.endRecording().toImage(w.round(), h.round());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      downloadBytes('jugada.png', bytes.buffer.asUint8List(),
          mime: 'image/png');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Imagen descargada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al generar la imagen: $e')));
      }
    }
  }

  // Dibuja unos elementos sobre la pista y devuelve la imagen resultante.
  ui.Image _renderFrame(ui.Image court, List<PlayItem> items, double w,
      double h, double courtK) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
    canvas.drawImageRect(
        court,
        Rect.fromLTWH(0, 0, court.width.toDouble(), court.height.toDouble()),
        Rect.fromLTWH(0, 0, w, h),
        Paint());
    paintPlayItems(canvas, Size(w, h), items, courtK);
    return recorder.endRecording().toImageSync(w.round(), h.round());
  }

  // Genera un GIF animado de la jugada y lo descarga (web).
  Future<void> _shareGif() async {
    if (!_canPlay) {
      await _sharePng();
      return;
    }
    setState(() => _gifProgress = 0);
    try {
      const w = 520.0;
      final h = w / (_court == 'full' ? 1.515 : 1.384);
      final data = await rootBundle.load(courtAsset(_court));
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final court = (await codec.getNextFrame()).image;
      final courtK = _itemScale * (_court == 'full' ? 0.52 : 1.0);

      // Más pasos por tramo = más FPS (más fluido). ~18 fps.
      const stepsPerSeg = 26;
      final segs = math.max(1, _animSteps);
      final totalSteps = segs * stepsPerSeg;
      final totalMs = 1500 * math.max(0.5, _animBeats) / _speed;
      final perFrameCs = math.max(3, (totalMs / totalSteps / 10).round());

      // Dibuja y codifica un fotograma por iteración, cediendo el control entre
      // cada uno: así el trabajo se reparte y la app no pega el tirón.
      final enc = img.GifEncoder(repeat: 0);
      for (var s = 0; s <= totalSteps; s++) {
        // Lineal (sin frenar en cada paso) para que sea continuo, como el ▶.
        final t01 = s / totalSteps;
        final items = _animItems(t01);
        final uiImg = _renderFrame(court, items, w, h, courtK);
        final bd = await uiImg.toByteData(format: ui.ImageByteFormat.rawRgba);
        uiImg.dispose();
        if (bd != null) {
          final frame = img.Image.fromBytes(
              width: w.round(),
              height: h.round(),
              bytes: bd.buffer,
              numChannels: 4,
              order: img.ChannelOrder.rgba);
          enc.addFrame(frame, duration: perFrameCs);
        }
        if (mounted) setState(() => _gifProgress = s / totalSteps);
        await Future<void>.delayed(Duration.zero); // dejar respirar a la UI
      }
      final gif = enc.finish();
      if (gif != null) {
        downloadBytes('jugada.gif', gif, mime: 'image/gif');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GIF descargado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al generar el GIF: $e')));
      }
    } finally {
      if (mounted) setState(() => _gifProgress = null);
    }
  }

  // Mover / seleccionar elementos.
  int? _moveIdx;
  int? _selected;
  String? _dragHandle; // 'tip' | 'tail' | 'ctrl' de la flecha/zona seleccionada
  Offset _moveLast = Offset.zero;

  // Selección múltiple (herramienta «Seleccionar»).
  Set<int> _multiSel = {};
  List<double>? _marqStart; // marco de selección (coords normalizadas)
  List<double>? _marqEnd;

  // Transformación (zoom/desplazamiento).
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _view = const Size(1, 1);

  // Estado del gesto.
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;
  bool _multi = false;
  bool _moved = false;
  Offset _tapAt = Offset.zero;
  List<double>? _dragStart;
  List<double>? _dragEnd;

  // Bloqueo y continuación: puntos del 1er tramo, a la espera del 2º.
  List<List<double>>? _contPts;

  // Bote a mano alzada: puntos del trazado (varias curvas en una flecha).
  List<List<double>>? _freePath;

  @override
  void initState() {
    super.initState();
    // La pizarra se abre a pantalla completa (sin el límite de 720px) y, en
    // móvil, se intenta poner en horizontal (best-effort en web).
    fullBleedRoutes.value++;
    setLandscape(true);
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() {
        if (_playing) setState(() {});
      })
      ..addStatusListener((s) {
        // Al terminar, se detiene y se queda en el estado FINAL de la jugada.
        if (s == AnimationStatus.completed && _playing) {
          setState(() {
            _playing = false;
            _atEnd = true;
            _frameIdx = _frames.length - 1;
          });
        }
      });
    if (widget.initial != null) {
      _court = widget.initial!.court;
      _itemScale = widget.initial!.itemScale;
      _speed = widget.initial!.speed;
      _overlap = widget.initial!.overlap;
      _frames = widget.initial!.framesOrSingle
          .map((f) => List<PlayItem>.from(f))
          .toList();
      if (_frames.isEmpty) _frames = [[]];
      _titleC.text = widget.initial!.title;
      _frameTitles = List<String>.from(widget.initial!.frameTitles);
      _ensureIds();
    }
    _syncFrameTitle();
  }

  // Mantiene _frameTitles con la misma longitud que _frames y refresca el campo.
  void _syncFrameTitle() {
    while (_frameTitles.length < _frames.length) {
      _frameTitles.add('');
    }
    if (_frameTitles.length > _frames.length) {
      _frameTitles = _frameTitles.sublist(0, _frames.length);
    }
    _frameTitleC.text =
        (_frameIdx < _frameTitles.length) ? _frameTitles[_frameIdx] : '';
  }

  void _moveFrame(int dir) {
    final j = _frameIdx + dir;
    if (j < 0 || j >= _frames.length) return;
    setState(() {
      final tmp = _frames[_frameIdx];
      _frames[_frameIdx] = _frames[j];
      _frames[j] = tmp;
      final tt = _frameTitles[_frameIdx];
      _frameTitles[_frameIdx] = _frameTitles[j];
      _frameTitles[j] = tt;
      _frameIdx = j;
      _selected = null;
      _multiSel = {};
      _atEnd = false;
      _syncFrameTitle();
    });
  }

  void _cycleSpeed() {
    const speeds = [0.5, 1.0, 1.5, 2.0];
    final i = speeds.indexWhere((s) => (s - _speed).abs() < 0.01);
    setState(() => _speed = speeds[(i + 1) % speeds.length]);
  }

  String get _speedLabel {
    if (_speed <= 0.5) return 'Lenta';
    if (_speed >= 2.0) return 'Muy rápida';
    if (_speed >= 1.5) return 'Rápida';
    return 'Normal';
  }

  void _cycleOverlap() {
    const ovs = [0.0, 0.3, 0.5, 0.7];
    final i = ovs.indexWhere((o) => (o - _overlap).abs() < 0.01);
    setState(() => _overlap = ovs[(i + 1) % ovs.length]);
  }

  String get _overlapLabel {
    if (_overlap <= 0) return 'Seguidos';
    if (_overlap >= 0.7) return 'Muy solapados';
    if (_overlap >= 0.5) return 'Solapados';
    return 'Algo solapados';
  }

  // Da ids estables a los elementos que no los tengan (jugadas antiguas),
  // reutilizando por índice el id del primer fotograma para conservar identidad.
  void _ensureIds() {
    final baseIds = <String>[];
    for (var fi = 0; fi < _frames.length; fi++) {
      final frame = _frames[fi];
      for (var i = 0; i < frame.length; i++) {
        if (frame[i].id.isEmpty) {
          final id = (fi > 0 && i < baseIds.length) ? baseIds[i] : _newId();
          frame[i] = frame[i].copyWith(id: id);
        }
        if (fi == 0) baseIds.add(frame[i].id);
      }
    }
  }

  @override
  void dispose() {
    fullBleedRoutes.value--;
    setLandscape(false);
    _anim.dispose();
    _titleC.dispose();
    _frameTitleC.dispose();
    super.dispose();
  }

  // ── Fotogramas (animación) ─────────────────────────────────────────────────
  // Nuevo fotograma partiendo del actual: jugadores/balón ya en su destino
  // (final de sus flechas) y sin líneas, listo para el siguiente movimiento.
  List<PlayItem> _bakedNextFrame() {
    final src = _items;
    if (!hasPaths(src)) return List<PlayItem>.from(src);
    // Movimiento de jugador = flecha con dueño y estilo de movimiento (NO el
    // pase, que aunque tenga dueño solo mueve el balón).
    final movement = src
        .where((it) =>
            it.kind == 'arrow' &&
            it.order > 0 &&
            it.owner.isNotEmpty &&
            isMovementStyle(it.arrowStyle))
        .toList();
    // Eventos de balón por orden: pases (dashed), tiros (shot) y entregas (dot).
    final events = src
        .where((it) =>
            it.order > 0 &&
            ((it.kind == 'arrow' &&
                    (it.arrowStyle == 'dashed' || it.arrowStyle == 'shot')) ||
                it.kind == 'dot'))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final endPos = <String, List<double>>{};
    for (final it in src) {
      if (it.kind != 'player') continue;
      var pos = [it.x, it.y];
      final mine = movement.where((a) => a.owner == it.id).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      if (mine.isNotEmpty) {
        final e = mine.last.pts.last;
        pos = [e[0], e[1]];
      }
      endPos[it.id] = pos;
    }
    String? nearest(List<double> p, {String? exclude}) {
      String? id;
      double best = 1e9;
      endPos.forEach((k, v) {
        if (k == exclude) return;
        final dx = v[0] - p[0], dy = v[1] - p[1];
        final d = dx * dx + dy * dy;
        if (d < best) {
          best = d;
          id = k;
        }
      });
      return id;
    }

    // Jugador que ejecuta un evento (por posición original).
    String? actorOf(PlayItem ev) {
      if (ev.owner.isNotEmpty) return ev.owner;
      final p = ev.kind == 'arrow' ? ev.pts.first : [ev.x, ev.y];
      String? id;
      double best = 1e9;
      for (final it in src) {
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

    // Balones: uno por cada balón del jugador y por cada 'ball' suelto.
    final balls = <_BakedBall>[];
    for (final it in src) {
      if (it.kind == 'player') {
        for (var i = 0; i < it.ballCount; i++) {
          balls.add(_BakedBall(it.id, null));
        }
      }
    }
    for (final it in src) {
      if (it.kind == 'ball') balls.add(_BakedBall(null, [it.x, it.y]));
    }
    if (balls.isEmpty && events.isNotEmpty) {
      balls.add(_BakedBall(actorOf(events.first), null));
    }
    for (final ev in events) {
      final actor = actorOf(ev);
      _BakedBall? ball;
      for (final b in balls) {
        if (actor != null && b.holder == actor) {
          ball = b;
          break;
        }
      }
      ball ??= balls.isNotEmpty ? balls.first : null;
      if (ball == null) continue;
      if (ev.kind == 'dot') {
        ball.holder = ev.fake
            ? (ev.owner.isNotEmpty ? ev.owner : ball.holder)
            : (ev.target.isNotEmpty ? ev.target : ball.holder);
        ball.rest = null;
      } else if (ev.arrowStyle == 'shot') {
        ball.holder = null;
        ball.rest = basketPos(_court, ev.pts.last);
      } else {
        final passer =
            ev.owner.isNotEmpty ? ev.owner : nearest(ev.pts.first);
        ball.holder = ev.target.isNotEmpty
            ? ev.target
            : (nearest(ev.pts.last, exclude: passer) ?? ball.holder);
        ball.rest = null;
      }
    }
    final holderCount = <String, int>{};
    for (final b in balls) {
      if (b.holder != null) {
        holderCount[b.holder!] = (holderCount[b.holder!] ?? 0) + 1;
      }
    }

    final out = <PlayItem>[];
    for (final it in src) {
      // Eliminar líneas (flechas) y entregas (mano a mano).
      if (it.kind == 'arrow' || it.kind == 'dot') continue;
      if (it.kind == 'player') {
        final pos = endPos[it.id] ?? [it.x, it.y];
        final n = holderCount[it.id] ?? 0;
        out.add(it.copyWith(
            x: pos[0], y: pos[1], hasBall: n > 0, balls: n >= 2 ? n : 0));
      } else if (it.kind == 'ball') {
        // los balones sueltos se recolocan abajo; no duplicar aquí
      } else {
        out.add(it);
      }
    }
    // Balones que no lleva nadie (tiro a canasta, sueltos): en su posición.
    for (final b in balls) {
      if (b.holder == null && b.rest != null) {
        out.add(PlayItem(
            kind: 'ball', x: b.rest![0], y: b.rest![1], id: _newId()));
      }
    }
    return out;
  }

  void _addFrame() {
    _pushHistory();
    setState(() {
      _frames.insert(_frameIdx + 1, _bakedNextFrame());
      _frameTitles.insert(_frameIdx + 1, '');
      _frameIdx++;
      _selected = null;
      _multiSel = {};
      _atEnd = false;
      _syncFrameTitle();
    });
  }

  void _deleteFrame() {
    if (_frames.length <= 1) return;
    _pushHistory();
    setState(() {
      _frames.removeAt(_frameIdx);
      if (_frameIdx < _frameTitles.length) _frameTitles.removeAt(_frameIdx);
      if (_frameIdx >= _frames.length) _frameIdx = _frames.length - 1;
      _selected = null;
      _multiSel = {};
      _atEnd = false;
      _syncFrameTitle();
    });
  }

  void _gotoFrame(int i) {
    if (i < 0 || i >= _frames.length) return;
    setState(() {
      _frameIdx = i;
      _selected = null;
      _multiSel = {};
      _atEnd = false;
      _syncFrameTitle();
    });
  }

  void _togglePlay() {
    if (!_canPlay) return;
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
      _selected = null;
      _multiSel = {};
      _scale = 1;
      _offset = Offset.zero;
      _anim.duration = Duration(
          milliseconds:
              (1500 * math.max(0.5, _animBeats) / _speed).round());
      // Una sola pasada de inicio a fin; al terminar se detiene.
      _anim.forward(from: 0);
    });
  }

  // ¿Se puede reproducir? (recorridos de flechas o varios fotogramas)
  bool get _canPlay => animTotalSteps(_frames) > 0;
  int get _animSteps => animTotalSteps(_frames);
  double get _animBeats => animTotalBeats(_frames, _overlap);

  // Elementos animados encadenando los recorridos de todos los fotogramas.
  List<PlayItem> _animItems(double v) =>
      animatedFrames(_frames, v, overlap: _overlap, court: _court);

  // Índice del jugador cercano a un punto normalizado (o null).
  int? _playerNearNorm(List<double> n) {
    int? idx;
    double best = 30;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].kind != 'player') continue;
      final d = (Offset(_items[i].x * _view.width, _items[i].y * _view.height) -
              Offset(n[0] * _view.width, n[1] * _view.height))
          .distance;
      if (d < best) {
        best = d;
        idx = i;
      }
    }
    return idx;
  }

  int _nextOrder() {
    var m = 0;
    for (final it in _items) {
      if (it.order > m) m = it.order;
    }
    return m + 1;
  }

  String _labelOf(String id) => _items
      .firstWhere((it) => it.id == id,
          orElse: () => const PlayItem(kind: 'player'))
      .label;

  Iterable<PlayItem> get _movementArrows => _items.where((it) =>
      it.kind == 'arrow' &&
      it.owner.isNotEmpty &&
      isMovementStyle(it.arrowStyle));

  // Receptor en (nx,ny): el dueño de una flecha (movimiento/bloqueo/continuación)
  // cuyo INICIO o FINAL cae ahí (recibe donde empieza o donde va), o si no, el
  // jugador más cercano.
  String _autoReceiver(double nx, double ny, {String exclude = ''}) {
    double best = 0.14;
    String owner = '';
    for (final a in _movementArrows) {
      if (a.owner == exclude || a.pts.isEmpty) continue;
      for (final pt in [a.pts.first, a.pts.last]) {
        final d =
            math.sqrt((pt[0] - nx) * (pt[0] - nx) + (pt[1] - ny) * (pt[1] - ny));
        if (d < best) {
          best = d;
          owner = a.owner;
        }
      }
    }
    if (owner.isNotEmpty) return owner;
    double bp = 30;
    String pid = '';
    for (final it in _items) {
      if (it.kind != 'player' || it.id == exclude) continue;
      final d = (Offset(it.x * _view.width, it.y * _view.height) -
              Offset(nx * _view.width, ny * _view.height))
          .distance;
      if (d < bp) {
        bp = d;
        pid = it.id;
      }
    }
    return pid;
  }

  // Dueño de una flecha de movimiento cuyo inicio (o final) cae en (nx,ny).
  String _ownerOfArrowNear(double nx, double ny,
      {required bool useEnd, String exclude = ''}) {
    double best = 0.14;
    String owner = '';
    for (final a in _movementArrows) {
      if (a.owner == exclude || a.pts.isEmpty) continue;
      final pt = useEnd ? a.pts.last : a.pts.first;
      final d =
          math.sqrt((pt[0] - nx) * (pt[0] - nx) + (pt[1] - ny) * (pt[1] - ny));
      if (d < best) {
        best = d;
        owner = a.owner;
      }
    }
    return owner;
  }

  // Entrega mano a mano en (nx,ny): SOLO por flechas (no por posición estática,
  // porque el jugador que estaba ahí ya no estará). De = flecha que TERMINA ahí
  // (trae el balón). A (receptor) = el que LLEGA a recibir (otra flecha que
  // TERMINA ahí), y si no, quien SALE de ahí (flecha que empieza).
  (String, String, int) _autoHandoff(double nx, double ny) {
    final from = _ownerOfArrowNear(nx, ny, useEnd: true);
    var to = _ownerOfArrowNear(nx, ny, useEnd: true, exclude: from);
    if (to.isEmpty) to = _ownerOfArrowNear(nx, ny, useEnd: false, exclude: from);
    final order = (from.isNotEmpty || to.isNotEmpty) ? _nextOrder() : 0;
    return (from, to, order);
  }

  // Dueño para una flecha que empieza en [a]: el jugador cercano al inicio o,
  // si arranca donde termina otra flecha de recorrido, el mismo jugador (encadena).
  String? _ownerForStart(List<double> a) {
    final pIdx = _playerNearNorm(a);
    if (pIdx != null) return _items[pIdx].id;
    final start = Offset(a[0] * _view.width, a[1] * _view.height);
    double best = 30;
    String? owner;
    for (final it in _items) {
      if (it.kind == 'arrow' && it.owner.isNotEmpty && it.pts.length >= 2) {
        final end = it.pts.last;
        final d = (Offset(end[0] * _view.width, end[1] * _view.height) - start)
            .distance;
        if (d < best) {
          best = d;
          owner = it.owner;
        }
      }
    }
    return owner;
  }

  bool get _isArrow =>
      _tool == _Tool.corte ||
      _tool == _Tool.despDef ||
      _tool == _Tool.pase ||
      _tool == _Tool.bote ||
      _tool == _Tool.tiro ||
      _tool == _Tool.pantalla ||
      _tool == _Tool.ciega ||
      _tool == _Tool.bloqueoCont ||
      _tool == _Tool.paseDef;

  String get _arrowStyle {
    switch (_tool) {
      case _Tool.pase:
        return 'dashed';
      case _Tool.bote:
        return 'snake';
      case _Tool.tiro:
        return 'shot';
      case _Tool.pantalla:
        return 'screen';
      case _Tool.ciega:
        return 'screen2';
      case _Tool.despDef:
        return 'defense';
      case _Tool.bloqueoCont:
        return 'screencont';
      case _Tool.paseDef:
        return 'chevrons';
      default:
        return 'solid';
    }
  }

  // Al colocar con zoom, el nuevo elemento se adapta al nivel de zoom para
  // verse del tamaño adecuado (más pequeño cuanto más acercado estés). La
  // reducción es suave: como mucho a la mitad en el zoom máximo.
  double get _placeScale => (0.4 + 0.6 / _scale).clamp(0.5, 1.0);

  Offset _content(Offset p) => (p - _offset) / _scale;
  List<double> _norm(Offset content) => [
        (content.dx / _view.width).clamp(0.0, 1.0),
        (content.dy / _view.height).clamp(0.0, 1.0),
      ];

  // ── Gestos ────────────────────────────────────────────────────────────────
  void _scaleStart(ScaleStartDetails d) {
    _lastFocal = d.localFocalPoint;
    _lastScale = 1;
    _multi = d.pointerCount >= 2;
    _moved = false;
    _pushedThisGesture = false;
    _atEnd = false;
    _tapAt = d.localFocalPoint;
    _moveIdx = null;
    _freePath = null;
    if (!_multi && (_isArrow || _tool == _Tool.zona)) {
      if (_tool == _Tool.bote) {
        // Bote a mano alzada: se captura todo el recorrido.
        _freePath = [_norm(_content(d.localFocalPoint))];
        _dragStart = _freePath!.first;
        _dragEnd = _dragStart;
      } else if (_tool == _Tool.bloqueoCont && _contPts != null) {
        // Segundo tramo: arranca en el final del primero.
        _dragStart = List<double>.from(_contPts!.last);
        _dragEnd = _norm(_content(d.localFocalPoint));
      } else {
        _dragStart = _norm(_content(d.localFocalPoint));
        _dragEnd = _dragStart;
      }
    } else {
      _dragStart = null;
      _dragEnd = null;
      _dragHandle = null;
      _marqStart = null;
      _marqEnd = null;
      if (!_multi && _tool == _Tool.seleccion) {
        _marqStart = _norm(_content(d.localFocalPoint));
        _marqEnd = _marqStart;
      } else if (!_multi && _tool == _Tool.mover) {
        _moveLast = _content(d.localFocalPoint);
        // ¿Se agarra un tirador (punta/cola/curva) de la flecha seleccionada?
        final h = _grabHandle(_moveLast);
        if (h != null) {
          _dragHandle = h;
          _moveIdx = _selected;
        } else {
          _moveIdx = _findItemAt(_moveLast);
          // Tocar un elemento fuera del grupo deshace la selección múltiple.
          if (_moveIdx != null && !_multiSel.contains(_moveIdx)) {
            _multiSel = {};
          }
        }
      }
    }
  }

  // Índices de los elementos dentro del marco [a]-[b] (coords normalizadas).
  Set<int> _itemsInRect(List<double> a, List<double> b) {
    final r = Rect.fromPoints(Offset(a[0], a[1]), Offset(b[0], b[1]));
    final sel = <int>{};
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      final inside = (it.kind == 'arrow' || it.kind == 'zone')
          ? it.pts.any((e) => r.contains(Offset(e[0], e[1])))
          : r.contains(Offset(it.x, it.y));
      if (inside) sel.add(i);
    }
    return sel;
  }

  // ¿Qué tirador de la flecha/zona seleccionada se agarra en [pos] (px de
  // contenido)? 'tip' (punta), 'tail' (cola) o 'ctrl' (curva). null si ninguno.
  String? _grabHandle(Offset pos) {
    if (_selected == null || _selected! >= _items.length) return null;
    final it = _items[_selected!];
    if ((it.kind != 'arrow' && it.kind != 'zone') || it.pts.length < 2) {
      return null;
    }
    Offset vp(List<double> p) =>
        Offset(p[0] * _view.width, p[1] * _view.height);
    final tip = vp(it.pts.last);
    final tail = vp(it.pts.first);
    const r = 26.0;
    if ((tip - pos).distance < r) return 'tip';
    if ((tail - pos).distance < r) return 'tail';
    if (it.kind == 'arrow' && _curvable(it.arrowStyle) && it.pts.length <= 2) {
      final handle = it.ctrl.length >= 2
          ? vp(it.ctrl)
          : Offset((it.pts.first[0] + it.pts.last[0]) / 2 * _view.width,
              (it.pts.first[1] + it.pts.last[1]) / 2 * _view.height);
      if ((handle - pos).distance < r) return 'ctrl';
    }
    // Bloqueo+continuación: dos tiradores de curva (uno por tramo).
    if (it.kind == 'arrow' &&
        it.arrowStyle == 'screencont' &&
        it.pts.length >= 3) {
      Offset midp(List<double> a, List<double> b) => Offset(
          (a[0] + b[0]) / 2 * _view.width, (a[1] + b[1]) / 2 * _view.height);
      final h1 = it.ctrl.length >= 2
          ? vp([it.ctrl[0], it.ctrl[1]])
          : midp(it.pts[0], it.pts[1]);
      final h2 = it.ctrl.length >= 4
          ? vp([it.ctrl[2], it.ctrl[3]])
          : midp(it.pts[1], it.pts[2]);
      if ((h1 - pos).distance < r) return 'ctrl';
      if ((h2 - pos).distance < r) return 'ctrl2';
    }
    return null;
  }

  List<double> _ensureScreencontCtrl(PlayItem it) {
    if (it.ctrl.length >= 4) return List<double>.from(it.ctrl);
    return [
      (it.pts[0][0] + it.pts[1][0]) / 2,
      (it.pts[0][1] + it.pts[1][1]) / 2,
      (it.pts[1][0] + it.pts[2][0]) / 2,
      (it.pts[1][1] + it.pts[2][1]) / 2,
    ];
  }

  bool _curvable(String style) =>
      style == '' ||
      style == 'solid' ||
      style == 'dashed' ||
      style == 'defense' ||
      style == 'snake' ||
      style == 'screen' ||
      style == 'screen2';

  void _scaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      if (!_multi) {
        _multi = true;
        _dragStart = null;
        _dragEnd = null;
      }
      final scaleDelta = d.scale / _lastScale;
      _lastScale = d.scale;
      final newScale = (_scale * scaleDelta).clamp(1.0, 5.0);
      final actualDelta = newScale / _scale;
      final focal = d.localFocalPoint;
      setState(() {
        _offset += focal - _lastFocal; // desplazar
        _offset = focal - (focal - _offset) * actualDelta; // zoom sobre el foco
        _scale = newScale;
        if (_scale <= 1.001) _offset = Offset.zero;
      });
      _lastFocal = focal;
      return;
    }
    if (_multi) return;

    if ((d.localFocalPoint - _tapAt).distance > 6) _moved = true;

    if (_tool == _Tool.bote && _freePath != null) {
      final n = _norm(_content(d.localFocalPoint));
      final last = _freePath!.last;
      if ((Offset(n[0], n[1]) - Offset(last[0], last[1])).distance > 0.008) {
        _freePath!.add(n);
      }
      setState(() => _dragEnd = n);
    } else if ((_isArrow || _tool == _Tool.zona) && _dragStart != null) {
      setState(() => _dragEnd = _norm(_content(d.localFocalPoint)));
    } else if (_tool == _Tool.seleccion && _marqStart != null) {
      setState(() => _marqEnd = _norm(_content(d.localFocalPoint)));
    } else if (_tool == _Tool.mover && _dragHandle != null && _selected != null) {
      // Arrastrar un tirador de la flecha/zona: punta, cola o curva.
      if (!_pushedThisGesture) {
        _pushHistory();
        _pushedThisGesture = true;
      }
      final n = _norm(_content(d.localFocalPoint));
      setState(() {
        final it = _items[_selected!];
        if (_dragHandle == 'ctrl' || _dragHandle == 'ctrl2') {
          if (it.arrowStyle == 'screencont' && it.pts.length >= 3) {
            final ctrl = _ensureScreencontCtrl(it);
            if (_dragHandle == 'ctrl') {
              ctrl[0] = n[0];
              ctrl[1] = n[1];
            } else {
              ctrl[2] = n[0];
              ctrl[3] = n[1];
            }
            _items[_selected!] = it.copyWith(ctrl: ctrl);
          } else {
            _items[_selected!] = it.copyWith(ctrl: n);
          }
        } else {
          final pts = it.pts.map((e) => List<double>.from(e)).toList();
          if (_dragHandle == 'tip') {
            pts[pts.length - 1] = n;
          } else {
            pts[0] = n;
          }
          _items[_selected!] = it.copyWith(pts: pts);
        }
      });
    } else if (_tool == _Tool.mover && _moveIdx != null) {
      if (!_pushedThisGesture) {
        _pushHistory();
        _pushedThisGesture = true;
      }
      final cur = _content(d.localFocalPoint);
      final dnx = (cur.dx - _moveLast.dx) / _view.width;
      final dny = (cur.dy - _moveLast.dy) / _view.height;
      setState(() {
        if (_multiSel.length > 1 && _multiSel.contains(_moveIdx)) {
          // Mover todo el grupo a la vez.
          for (final i in _multiSel) {
            _items[i] = _translate(_items[i], dnx, dny);
          }
        } else {
          _items[_moveIdx!] = _translate(_items[_moveIdx!], dnx, dny);
          _selected = _moveIdx;
        }
      });
      _moveLast = cur;
    } else {
      // 1 dedo con herramienta de colocar (o mover en vacío) → mover el lienzo.
      setState(() {
        _offset += d.localFocalPoint - _lastFocal;
        if (_scale <= 1.001) _offset = Offset.zero;
      });
      _lastFocal = d.localFocalPoint;
    }
  }

  void _scaleEnd(ScaleEndDetails d) {
    if (!_multi) {
      if (_tool == _Tool.bloqueoCont && _contPts != null) {
        // Segundo tramo del bloqueo y continuación: rediriges la continuación.
        final cEnd = _dragEnd ?? _norm(_content(_tapAt));
        final b = _contPts!.last;
        if ((Offset(b[0], b[1]) - Offset(cEnd[0], cEnd[1])).distance > 0.02) {
          _pushHistory();
          // Si el bloqueo empieza sobre un jugador (o al final de otra flecha
          // suya), se le asigna como recorrido.
          final owForBlock = _ownerForStart(_contPts!.first);
          String owner = '';
          int order = 0;
          if (owForBlock != null) {
            owner = owForBlock;
            order = _nextOrder();
          }
          _items.add(PlayItem(
              kind: 'arrow',
              pts: [..._contPts!, cEnd],
              arrowStyle: 'screencont',
              scale: _placeScale,
              id: _newId(),
              owner: owner,
              order: order));
          _selected = _items.length - 1;
          _tool = _Tool.mover;
          if (owner.isNotEmpty) {
            final lbl = _items
                .firstWhere((it) => it.id == owner,
                    orElse: () => const PlayItem(kind: 'player'))
                .label;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(seconds: 2),
                content: Text(
                    'Recorrido del jugador ${lbl.isEmpty ? '' : lbl} (paso $order)')));
          }
        }
        _contPts = null;
      } else if (_tool == _Tool.seleccion) {
        // Fin del marco de selección múltiple.
        if (_moved && _marqStart != null && _marqEnd != null) {
          final sel = _itemsInRect(_marqStart!, _marqEnd!);
          setState(() {
            _multiSel = sel;
            _selected = sel.length == 1 ? sel.first : null;
          });
        } else {
          setState(() {
            _multiSel = {};
            _selected = null;
          });
        }
      } else if (!_moved) {
        if (_tool == _Tool.mover) {
          if (_moveIdx == null) {
            setState(() {
              _selected = null;
              _multiSel = {};
            });
          } else if (_selected == _moveIdx &&
              _items[_moveIdx!].kind == 'player') {
            _tapToggle(_moveIdx!);
          } else {
            setState(() {
              _selected = _moveIdx;
              _multiSel = {};
            });
          }
        } else {
          _placeAt(_norm(_content(_tapAt)));
        }
      } else if (_tool == _Tool.bote && _freePath != null) {
        // Bote a mano alzada (varias curvas en una sola flecha).
        if (_freePath!.length >= 2) {
          _pushHistory();
          final ow = _ownerForStart(_freePath!.first);
          final owner = ow ?? '';
          final order = owner.isNotEmpty ? _nextOrder() : 0;
          _items.add(PlayItem(
              kind: 'arrow',
              pts: List<List<double>>.from(_freePath!),
              arrowStyle: 'snake',
              scale: _placeScale,
              id: _newId(),
              owner: owner,
              order: order));
          _selected = _items.length - 1;
          _tool = _Tool.mover;
        }
      } else if (_dragStart != null && _dragEnd != null) {
        final a = _dragStart!, b = _dragEnd!;
        final dist = (Offset(a[0], a[1]) - Offset(b[0], b[1])).distance;
        if (dist > 0.02) {
          if (_tool == _Tool.zona) {
            _pushHistory();
            _items.add(PlayItem(kind: 'zone', pts: [a, b], id: _newId()));
            _selected = _items.length - 1;
            _tool = _Tool.mover;
          } else if (_tool == _Tool.bloqueoCont) {
            // Primer tramo: queda pendiente del segundo.
            _contPts = [a, b];
          } else if (_isArrow) {
            _pushHistory();
            // Recorridos: la flecha de movimiento que empieza sobre un jugador
            // se le asigna (la recorre); el pase (discontinua) mueve el balón.
            String owner = '';
            String target = '';
            int order = 0;
            String msg = '';
            if (_arrowStyle == 'dashed') {
              order = _nextOrder();
              final fromIdx = _playerNearNorm(a);
              if (fromIdx != null) owner = _items[fromIdx].id;
              // Receptor: jugador al final, o dueño de la flecha que empieza ahí.
              target = _autoReceiver(b[0], b[1], exclude: owner);
              msg = target.isEmpty
                  ? 'Pase (paso $order)'
                  : 'Pase a ${_labelOf(target)} (paso $order)';
            } else if (_arrowStyle == 'shot') {
              // Tiro: el balón va a la canasta en su paso.
              order = _nextOrder();
              final shooterIdx = _playerNearNorm(a);
              if (shooterIdx != null) owner = _items[shooterIdx].id;
              msg = 'Tiro (paso $order)';
            } else if (isMovementStyle(_arrowStyle)) {
              final ow = _ownerForStart(a);
              if (ow != null) {
                owner = ow;
                order = _nextOrder();
                final lbl = _items
                    .firstWhere((it) => it.id == ow,
                        orElse: () => const PlayItem(kind: 'player'))
                    .label;
                msg =
                    'Recorrido del jugador ${lbl.isEmpty ? '' : lbl} (paso $order)';
              }
            }
            _items.add(PlayItem(
                kind: 'arrow',
                pts: [a, b],
                arrowStyle: _arrowStyle,
                scale: _placeScale,
                id: _newId(),
                owner: owner,
                target: target,
                order: order));
            _selected = _items.length - 1;
            _tool = _Tool.mover;
            if (msg.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  duration: const Duration(seconds: 2), content: Text(msg)));
            }
          }
        }
      }
    }
    setState(() {
      _dragStart = null;
      _dragEnd = null;
      _multi = false;
      _moveIdx = null;
      _dragHandle = null;
      _marqStart = null;
      _marqEnd = null;
      _freePath = null;
    });
  }

  // ── Acciones sobre la selección múltiple ────────────────────────────────────
  void _deleteMulti() {
    if (_multiSel.isEmpty) return;
    _pushHistory();
    final idxs = _multiSel.toList()..sort((a, b) => b.compareTo(a));
    setState(() {
      for (final i in idxs) {
        _items.removeAt(i);
      }
      _multiSel = {};
      _selected = null;
    });
  }

  void _duplicateMulti() {
    if (_multiSel.isEmpty) return;
    _pushHistory();
    double cl(double v) => v.clamp(0.0, 1.0);
    const dx = 0.04, dy = 0.04;
    final newSel = <int>{};
    setState(() {
      for (final i in _multiSel.toList()..sort()) {
        final it = _items[i];
        final PlayItem copy;
        if (it.kind == 'arrow' || it.kind == 'zone') {
          copy = it.copyWith(
            pts: it.pts.map((e) => [cl(e[0] + dx), cl(e[1] + dy)]).toList(),
            ctrl: it.ctrl.length >= 2
                ? [cl(it.ctrl[0] + dx), cl(it.ctrl[1] + dy)]
                : it.ctrl,
            id: _newId(),
          );
        } else {
          copy = it.copyWith(x: cl(it.x + dx), y: cl(it.y + dy), id: _newId());
        }
        _items.add(copy);
        newSel.add(_items.length - 1);
      }
      _multiSel = newSel;
      _selected = null;
    });
  }

  void _resizeMulti(double factor) {
    if (_multiSel.isEmpty) return;
    _pushHistory();
    setState(() {
      for (final i in _multiSel) {
        _items[i] =
            _items[i].copyWith(scale: (_items[i].scale * factor).clamp(0.4, 3.0));
      }
    });
  }

  void _placeAt(List<double> n) {
    final nx = n[0], ny = n[1];
    if (_tool == _Tool.atacante || _tool == _Tool.defensor) {
      final team = _tool == _Tool.atacante ? 'off' : 'def';
      final i = _items.indexWhere((it) =>
          it.kind == 'player' &&
          (Offset(it.x * _view.width, it.y * _view.height) -
                      _content(_tapAt))
                  .distance <
              20);
      if (i >= 0) {
        final it = _items[i];
        // Solo alternar el balón, conservando tamaño/rotación/etiqueta.
        _pushHistory();
        setState(() {
          _items[i] = it.copyWith(hasBall: !it.hasBall);
          _selected = i;
          _tool = _Tool.mover;
        });
      } else {
        final num = _items
                .where((it) => it.kind == 'player' && it.team == team)
                .length +
            1;
        _pushHistory();
        setState(() {
          _items.add(PlayItem(
              kind: 'player',
              x: nx,
              y: ny,
              team: team,
              scale: _placeScale,
              id: _newId(),
              label: _numbered && num <= 9 ? '$num' : ''));
          _selected = _items.length - 1;
          _tool = _Tool.mover;
        });
      }
    } else if (_tool == _Tool.entrega) {
      _pushHistory();
      // Detecta de quién a quién es la entrega según las líneas cercanas:
      // el final de una línea = quien trae el balón; el inicio de otra = quien
      // lo recibe. Le asigna también su paso en la secuencia.
      final ho = _autoHandoff(nx, ny);
      setState(() {
        _items.add(PlayItem(
            kind: 'dot',
            x: nx,
            y: ny,
            scale: _placeScale,
            id: _newId(),
            owner: ho.$1,
            target: ho.$2,
            order: ho.$3));
        _selected = _items.length - 1;
        _tool = _Tool.mover;
      });
      if (ho.$3 > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
                'Entrega${ho.$2.isEmpty ? '' : ' a ${_labelOf(ho.$2)}'} (paso ${ho.$3})')));
      }
    } else if (_tool == _Tool.balon) {
      _pushHistory();
      setState(() {
        _items.add(PlayItem(
            kind: 'ball', x: nx, y: ny, scale: _placeScale, id: _newId()));
        _selected = _items.length - 1;
        _tool = _Tool.mover;
      });
    } else if (_tool == _Tool.texto) {
      final i = _items.indexWhere((it) =>
          it.kind == 'text' &&
          (Offset(it.x * _view.width, it.y * _view.height) - _content(_tapAt))
                  .distance <
              26);
      _promptText(nx, ny, editIdx: i >= 0 ? i : null);
    } else if (_tool == _Tool.cono) {
      _pushHistory();
      setState(() {
        _items.add(PlayItem(
            kind: 'cone', x: nx, y: ny, scale: _placeScale, id: _newId()));
        _selected = _items.length - 1;
        _tool = _Tool.mover;
      });
    } else if (_tool == _Tool.borrar) {
      _eraseNear(_content(_tapAt));
    }
  }

  // Distancia (px de contenido) de [pos] a un elemento. Para flechas usa toda
  // la línea (recta o curva); para zonas, el borde o 0 si está dentro.
  double _distToItem(PlayItem it, Offset pos) {
    Offset vp(List<double> e) =>
        Offset(e[0] * _view.width, e[1] * _view.height);
    if (it.kind == 'arrow' && it.pts.length >= 2) {
      final line = arrowLine(it).map(vp).toList();
      double best = double.infinity;
      for (var i = 0; i + 1 < line.length; i++) {
        best = math.min(best, _distToSegment(pos, line[i], line[i + 1]));
      }
      return best;
    }
    if (it.kind == 'zone' && it.pts.length >= 2) {
      final rect = Rect.fromPoints(vp(it.pts.first), vp(it.pts.last));
      if (rect.contains(pos)) return 0;
      return [
        _distToSegment(pos, rect.topLeft, rect.topRight),
        _distToSegment(pos, rect.topRight, rect.bottomRight),
        _distToSegment(pos, rect.bottomRight, rect.bottomLeft),
        _distToSegment(pos, rect.bottomLeft, rect.topLeft),
      ].reduce(math.min);
    }
    return (Offset(it.x * _view.width, it.y * _view.height) - pos).distance;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final l2 = ab.distanceSquared;
    final t = l2 == 0
        ? 0.0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  int? _findItemAt(Offset pos) {
    int? idx;
    double best = 28;
    for (var i = 0; i < _items.length; i++) {
      final d = _distToItem(_items[i], pos);
      if (d < best) {
        best = d;
        idx = i;
      }
    }
    return idx;
  }

  PlayItem _translate(PlayItem it, double dnx, double dny) {
    double cl(double v) => v.clamp(0.0, 1.0);
    if (it.kind == 'arrow' || it.kind == 'zone') {
      return it.copyWith(
        pts: it.pts.map((e) => [cl(e[0] + dnx), cl(e[1] + dny)]).toList(),
        ctrl: it.ctrl.length >= 2
            ? [cl(it.ctrl[0] + dnx), cl(it.ctrl[1] + dny)]
            : it.ctrl,
      );
    }
    return it.copyWith(x: cl(it.x + dnx), y: cl(it.y + dny));
  }

  void _duplicateSelected() {
    if (_selected == null || _selected! >= _items.length) return;
    _pushHistory();
    final it = _items[_selected!];
    double cl(double v) => v.clamp(0.0, 1.0);
    const dx = 0.04, dy = 0.04;
    final PlayItem copy;
    if (it.kind == 'arrow' || it.kind == 'zone') {
      copy = it.copyWith(
        pts: it.pts.map((e) => [cl(e[0] + dx), cl(e[1] + dy)]).toList(),
        ctrl: it.ctrl.length >= 2
            ? [cl(it.ctrl[0] + dx), cl(it.ctrl[1] + dy)]
            : it.ctrl,
        id: _newId(),
      );
    } else {
      copy = it.copyWith(x: cl(it.x + dx), y: cl(it.y + dy), id: _newId());
    }
    setState(() {
      _items.add(copy);
      _selected = _items.length - 1;
    });
  }

  void _tapToggle(int idx) {
    final it = _items[idx];
    if (it.kind == 'player') {
      setState(() => _items[idx] = it.copyWith(hasBall: !it.hasBall));
    }
  }

  // Cicla el nº de balones de un jugador: 0 → 1 → 2 → 0.
  void _cycleBall(int idx) {
    final it = _items[idx];
    if (it.kind != 'player') return;
    final n = it.ballCount;
    final next = n >= 2 ? 0 : n + 1;
    _pushHistory();
    setState(() => _items[idx] =
        it.copyWith(hasBall: next > 0, balls: next >= 2 ? next : 0));
  }

  // Asigna la flecha seleccionada al jugador sobre el que empieza (recorrido).
  void _assignPathToSelected() {
    if (_selected == null || _selected! >= _items.length) return;
    final it = _items[_selected!];
    if (it.kind != 'arrow' || it.pts.isEmpty) return;
    // Pase: mueve el balón; no necesita dueño.
    if (it.arrowStyle == 'dashed') {
      _pushHistory();
      final rec = _autoReceiver(it.pts.last[0], it.pts.last[1]);
      setState(() => _items[_selected!] =
          it.copyWith(owner: '', target: rec, order: _nextOrder()));
      return;
    }
    // Tiro: el balón va a la canasta. Dueño = tirador (inicio).
    if (it.arrowStyle == 'shot') {
      _pushHistory();
      final s = _playerNearNorm(it.pts.first);
      setState(() => _items[_selected!] = it.copyWith(
          owner: s != null ? _items[s].id : '',
          order: it.order > 0 ? it.order : _nextOrder()));
      return;
    }
    final ow = _ownerForStart(it.pts.first);
    if (ow == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
              'La flecha debe empezar sobre un jugador o al final de otra flecha suya')));
      return;
    }
    _pushHistory();
    setState(() => _items[_selected!] = it.copyWith(
        owner: ow, order: it.order > 0 ? it.order : _nextOrder()));
  }

  void _changeOrder(int delta) {
    if (_selected == null || _selected! >= _items.length) return;
    final it = _items[_selected!];
    _pushHistory();
    setState(() => _items[_selected!] =
        it.copyWith(order: (it.order + delta).clamp(1, 99)));
  }

  void _cycleLead() {
    if (_selected == null || _selected! >= _items.length) return;
    final it = _items[_selected!];
    const leads = [0.0, 0.3, 0.5, 0.7];
    final i = leads.indexWhere((l) => (l - it.lead).abs() < 0.01);
    _pushHistory();
    setState(() =>
        _items[_selected!] = it.copyWith(lead: leads[(i + 1) % leads.length]));
  }

  String _leadLabel(double l) {
    if (l <= 0) return 'Solapa: no';
    if (l >= 0.7) return 'Solapa: mucho';
    if (l >= 0.5) return 'Solapa: medio';
    return 'Solapa: poco';
  }

  void _cycleArrowSpeed() {
    if (_selected == null || _selected! >= _items.length) return;
    final it = _items[_selected!];
    const speeds = [1.0, 1.5, 2.0, 3.0];
    final i = speeds.indexWhere((s) => (s - it.spd).abs() < 0.01);
    _pushHistory();
    setState(() =>
        _items[_selected!] = it.copyWith(spd: speeds[(i + 1) % speeds.length]));
  }

  String _spdLabel(double s) =>
      s == s.roundToDouble() ? s.toInt().toString() : s.toString();

  void _toggleSharp() {
    if (_selected == null || _selected! >= _items.length) return;
    final it = _items[_selected!];
    _pushHistory();
    setState(() => _items[_selected!] = it.copyWith(sharp: !it.sharp));
  }

  void _setOwner(String v) {
    if (_selected == null || _selected! >= _items.length) return;
    _pushHistory();
    setState(() => _items[_selected!] = _items[_selected!].copyWith(owner: v));
  }

  void _setTarget(String v) {
    if (_selected == null || _selected! >= _items.length) return;
    _pushHistory();
    setState(() => _items[_selected!] = _items[_selected!].copyWith(target: v));
  }

  void _setFake(bool v) {
    if (_selected == null || _selected! >= _items.length) return;
    _pushHistory();
    setState(() => _items[_selected!] = _items[_selected!].copyWith(fake: v));
  }

  String _playerName(PlayItem p) =>
      p.label.isEmpty ? (p.team == 'off' ? 'At' : 'Def') : p.label;

  Widget _playerDropdown(String current, void Function(String) onSet) {
    final players = _items.where((it) => it.kind == 'player').toList();
    final valid = players.any((p) => p.id == current) ? current : '';
    return DropdownButton<String>(
      value: valid,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: [
        const DropdownMenuItem(
            value: '', child: Text('—', style: TextStyle(fontSize: 12))),
        for (final p in players)
          DropdownMenuItem(
              value: p.id,
              child:
                  Text(_playerName(p), style: const TextStyle(fontSize: 12))),
      ],
      onChanged: (v) => onSet(v ?? ''),
    );
  }

  void _clearPath() {
    if (_selected == null || _selected! >= _items.length) return;
    _pushHistory();
    setState(() =>
        _items[_selected!] = _items[_selected!].copyWith(owner: '', order: 0));
  }

  void _resizeSelected(double factor) {
    if (_selected == null || _selected! >= _items.length) return;
    _pushHistory();
    final it = _items[_selected!];
    setState(() => _items[_selected!] =
        it.copyWith(scale: (it.scale * factor).clamp(0.4, 3.0)));
  }

  Future<void> _promptText(double nx, double ny, {int? editIdx}) async {
    final controller = TextEditingController(
        text: editIdx != null ? _items[editIdx].label : '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Texto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Escribe…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Aceptar')),
        ],
      ),
    );
    if (text == null) return;
    _pushHistory();
    setState(() {
      if (editIdx != null) {
        if (text.isEmpty) {
          _items.removeAt(editIdx);
        } else {
          final it = _items[editIdx];
          _items[editIdx] = PlayItem(
              kind: 'text',
              x: it.x,
              y: it.y,
              label: text,
              scale: it.scale,
              id: it.id.isEmpty ? _newId() : it.id);
        }
      } else if (text.isNotEmpty) {
        _items.add(PlayItem(
            kind: 'text',
            x: nx,
            y: ny,
            label: text,
            scale: _placeScale,
            id: _newId()));
        _selected = _items.length - 1;
        _tool = _Tool.mover;
      }
    });
  }

  void _eraseNear(Offset pos) {
    int? idx;
    double best = 26;
    for (var i = 0; i < _items.length; i++) {
      final d = _distToItem(_items[i], pos);
      if (d < best) {
        best = d;
        idx = i;
      }
    }
    if (idx != null) {
      _pushHistory();
      setState(() => _items.removeAt(idx!));
    }
  }

  void _zoomBtn(double factor) {
    final center = Offset(_view.width / 2, _view.height / 2);
    final newScale = (_scale * factor).clamp(1.0, 5.0);
    final actualDelta = newScale / _scale;
    setState(() {
      _offset = center - (center - _offset) * actualDelta;
      _scale = newScale;
      if (_scale <= 1.001) _offset = Offset.zero;
    });
  }

  List<PlayItem>? get _liveExtra {
    if (_tool == _Tool.bote && _freePath != null && _freePath!.length >= 2) {
      return [
        PlayItem(kind: 'arrow', pts: _freePath!, arrowStyle: 'snake')
      ];
    }
    if (_tool == _Tool.bloqueoCont && _contPts != null) {
      final pts = _dragEnd != null ? [..._contPts!, _dragEnd!] : _contPts!;
      return [PlayItem(kind: 'arrow', pts: pts, arrowStyle: 'screencont')];
    }
    if (_dragStart == null || _dragEnd == null) return null;
    if (_tool == _Tool.zona) {
      return [PlayItem(kind: 'zone', pts: [_dragStart!, _dragEnd!])];
    }
    return [
      PlayItem(kind: 'arrow', pts: [_dragStart!, _dragEnd!], arrowStyle: _arrowStyle)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pizarra de jugadas'),
        actions: [
          IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Deshacer',
              onPressed: _history.isEmpty ? null : _undo),
          IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Rehacer',
              onPressed: _redo.isEmpty ? null : _redoAction),
          IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Guardar jugada',
              onPressed: () => Navigator.pop(
                  context,
                  Play(
                      court: _court,
                      items: List.from(_frames.first),
                      itemScale: _itemScale,
                      speed: _speed,
                      overlap: _overlap,
                      title: _titleC.text.trim(),
                      frameTitles: List<String>.from(_frameTitles),
                      frames: _frames
                          .map((f) => List<PlayItem>.from(f))
                          .toList()))),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Más',
            onSelected: (v) {
              switch (v) {
                case 'rotate':
                  enterFullscreenLandscape();
                  break;
                case 'templates':
                  _openTemplates();
                  break;
                case 'png':
                  _sharePng();
                  break;
                case 'gif':
                  _shareGif();
                  break;
                case 'clear':
                  if (_items.isEmpty) return;
                  _pushHistory();
                  setState(_items.clear);
                  break;
              }
            },
            itemBuilder: (_) => [
              if (MediaQuery.sizeOf(context).width < 680)
                const PopupMenuItem(
                    value: 'rotate',
                    child: ListTile(
                        leading: Icon(Icons.screen_rotation),
                        title: Text('Pantalla horizontal'))),
              const PopupMenuItem(
                  value: 'templates',
                  child: ListTile(
                      leading: Icon(Icons.library_books_outlined),
                      title: Text('Plantillas'))),
              const PopupMenuItem(
                  value: 'png',
                  child: ListTile(
                      leading: Icon(Icons.image_outlined),
                      title: Text('Imagen (PNG)'))),
              PopupMenuItem(
                  value: 'gif',
                  enabled: _canPlay,
                  child: const ListTile(
                      leading: Icon(Icons.gif_box_outlined),
                      title: Text('GIF animado'))),
              const PopupMenuItem(
                  value: 'clear',
                  child: ListTile(
                      leading: Icon(Icons.delete_sweep),
                      title: Text('Borrar todo'))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _editorBody(),
          if (_gifProgress != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(value: _gifProgress),
                      const SizedBox(height: 12),
                      Text(
                        'Generando GIF… ${((_gifProgress ?? 0) * 100).round()}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Layout tipo «Paint»: en ancho, barra lateral con todo + lienzo grande;
  // en móvil, apilado compacto para maximizar el lienzo.
  Widget _editorBody() {
    return LayoutBuilder(
      builder: (context, cons) {
        final wide = cons.maxWidth >= 680;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: cons.maxWidth >= 900 ? 250 : 210,
                child: Material(
                  elevation: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _courtSelector(),
                        _titleFields(),
                        _toolbar(),
                        const Divider(height: 12),
                        _frameBar(),
                        const Divider(height: 12),
                        _bottomBar(),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: _canvas()),
            ],
          );
        }
        return Column(
          children: [
            _courtSelector(),
            _titleFields(),
            _toolbar(),
            _frameBar(),
            Expanded(child: _canvas()),
            _bottomBar(),
          ],
        );
      },
    );
  }

  Widget _courtSelector() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
                value: 'half',
                label: Text('Media'),
                icon: Icon(Icons.crop_landscape)),
            ButtonSegment(
                value: 'full',
                label: Text('Entera'),
                icon: Icon(Icons.crop_16_9)),
          ],
          selected: {_court},
          onSelectionChanged: (s) => setState(() => _court = s.first),
        ),
      );

  Widget _titleFields() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Column(
          children: [
            TextField(
              controller: _titleC,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: 'Título de la jugada',
                prefixIcon: Icon(Icons.title, size: 20),
              ),
            ),
            if (_frames.length > 1) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _frameTitleC,
                onChanged: (v) => _frameTitles[_frameIdx] = v,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: 'Título del paso ${_frameIdx + 1}',
                  prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _canvas() => Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: _court == 'full' ? 1.515 : 1.384,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _view = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onScaleStart: _playing ? null : _scaleStart,
                  onScaleUpdate: _playing ? null : _scaleUpdate,
                  onScaleEnd: _playing ? null : _scaleEnd,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRect(
                      child: Transform(
                        transform: Matrix4.identity()
                          ..translate(_offset.dx, _offset.dy)
                          ..scale(_scale),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(courtAsset(_court), fit: BoxFit.fill),
                            CustomPaint(
                              painter: PlayPainter(
                                Play(
                                    court: _court,
                                    items: _playing
                                        ? _animItems(_anim.value)
                                        : (_atEnd ? _animItems(1.0) : _items),
                                    itemScale: _itemScale),
                                extra: _playing ? null : _liveExtra,
                                selected: _playing ? null : _selected,
                                selectedSet: _playing ? null : _multiSel,
                                marquee: (_tool == _Tool.seleccion &&
                                        _marqStart != null &&
                                        _marqEnd != null)
                                    ? Rect.fromPoints(
                                        Offset(_marqStart![0], _marqStart![1]),
                                        Offset(_marqEnd![0], _marqEnd![1]))
                                    : null,
                              ),
                              size: Size.infinite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

  Widget _frameBar() {
    final n = _frames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Wrap(
        spacing: 0,
        runSpacing: -8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.movie_outlined, size: 18, color: Colors.grey),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Fotograma anterior',
            visualDensity: VisualDensity.compact,
            onPressed:
                (_playing || _frameIdx == 0) ? null : () => _gotoFrame(_frameIdx - 1),
          ),
          Text('${_frameIdx + 1}/$n', style: const TextStyle(fontSize: 12)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Fotograma siguiente',
            visualDensity: VisualDensity.compact,
            onPressed: (_playing || _frameIdx >= n - 1)
                ? null
                : () => _gotoFrame(_frameIdx + 1),
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Añadir fotograma (copia del actual)',
            visualDensity: VisualDensity.compact,
            onPressed: _playing ? null : _addFrame,
          ),
          if (n > 1) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'Mover este paso antes',
              visualDensity: VisualDensity.compact,
              onPressed:
                  (_playing || _frameIdx == 0) ? null : () => _moveFrame(-1),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 20),
              tooltip: 'Mover este paso después',
              visualDensity: VisualDensity.compact,
              onPressed: (_playing || _frameIdx >= n - 1)
                  ? null
                  : () => _moveFrame(1),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Borrar este fotograma',
              visualDensity: VisualDensity.compact,
              onPressed: _playing ? null : _deleteFrame,
            ),
          ],
          if (_canPlay) ...[
            TextButton.icon(
              icon: const Icon(Icons.speed, size: 18),
              label: Text(_speedLabel, style: const TextStyle(fontSize: 12)),
              onPressed: _playing ? null : _cycleSpeed,
            ),
            TextButton.icon(
              icon: const Icon(Icons.compress, size: 18),
              label: Text(_overlapLabel, style: const TextStyle(fontSize: 12)),
              onPressed: _playing ? null : _cycleOverlap,
            ),
            IconButton(
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
              color: _playing ? Colors.red : Colors.green,
              tooltip: _playing ? 'Parar' : 'Reproducir animación',
              onPressed: _togglePlay,
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final sel = (_selected != null && _selected! < _items.length)
        ? _items[_selected!]
        : null;
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Wrap(
          spacing: 2,
          runSpacing: -6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Alejar',
                onPressed: () => _zoomBtn(1 / 1.3)),
            IconButton(
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Acercar',
                onPressed: () => _zoomBtn(1.3)),
            IconButton(
                icon: const Icon(Icons.center_focus_strong),
                tooltip: 'Zoom 1:1',
                onPressed: () => setState(() {
                      _scale = 1;
                      _offset = Offset.zero;
                    })),
            if (_multiSel.length > 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${_multiSel.length} sel.',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                  icon: const Icon(Icons.zoom_in_map, size: 18),
                  label: const Text('Menos'),
                  onPressed: () => _resizeMulti(1 / 1.2)),
              TextButton.icon(
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  label: const Text('Más'),
                  onPressed: () => _resizeMulti(1.2)),
              TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Duplicar'),
                  onPressed: _duplicateMulti),
              TextButton.icon(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Quitar',
                      style: TextStyle(color: Colors.red)),
                  onPressed: _deleteMulti),
            ] else if (sel == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                    _tool == _Tool.seleccion
                        ? 'Arrastra un marco para seleccionar varios'
                        : 'Con «Mover», toca un elemento para ajustarlo',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              )
            else ...[
              TextButton.icon(
                  icon: const Icon(Icons.zoom_in_map, size: 18),
                  label: const Text('Menos'),
                  onPressed: () => _resizeSelected(1 / 1.2)),
              TextButton.icon(
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  label: const Text('Más'),
                  onPressed: () => _resizeSelected(1.2)),
              if (sel.kind == 'player')
                TextButton.icon(
                    icon: const Icon(Icons.sports_basketball, size: 18),
                    label: Text(sel.ballCount == 2
                        ? '2 balones'
                        : (sel.ballCount == 1 ? '1 balón' : 'Balón')),
                    onPressed: () => _cycleBall(_selected!)),
              if (sel.kind == 'player' || sel.kind == 'dot')
                TextButton.icon(
                    icon: const Icon(Icons.rotate_right, size: 18),
                    label: const Text('Girar'),
                    onPressed: () {
                      _pushHistory();
                      setState(() => _items[_selected!] = _items[_selected!]
                          .copyWith(
                              rot: (_items[_selected!].rot + 45) % 360,
                              flip: false));
                    }),
              if (sel.kind == 'arrow' && sel.arrowStyle == 'defense')
                TextButton.icon(
                    icon: const Icon(Icons.flip, size: 18),
                    label: const Text('Voltear'),
                    onPressed: () {
                      _pushHistory();
                      setState(() => _items[_selected!] = _items[_selected!]
                          .copyWith(flip: !_items[_selected!].flip));
                    }),
              if (sel.kind == 'arrow' &&
                  _curvable(sel.arrowStyle) &&
                  sel.pts.length <= 2)
                TextButton.icon(
                    icon: const Icon(Icons.timeline, size: 18),
                    label: Text(sel.ctrl.isEmpty ? 'Curvar' : 'Recta'),
                    onPressed: () => setState(() {
                          _pushHistory();
                          final it = _items[_selected!];
                          if (it.ctrl.isEmpty) {
                            // Curvar por defecto: control desplazado del medio.
                            final mx = (it.pts.first[0] + it.pts.last[0]) / 2;
                            final my = (it.pts.first[1] + it.pts.last[1]) / 2;
                            final dx = it.pts.last[0] - it.pts.first[0];
                            final dy = it.pts.last[1] - it.pts.first[1];
                            final len = math.sqrt(dx * dx + dy * dy);
                            final nx = len == 0 ? 0.0 : -dy / len;
                            final ny = len == 0 ? 0.0 : dx / len;
                            _items[_selected!] = it.copyWith(ctrl: [
                              (mx + nx * 0.12).clamp(0.0, 1.0),
                              (my + ny * 0.12).clamp(0.0, 1.0)
                            ]);
                          } else {
                            _items[_selected!] = it.copyWith(ctrl: const []);
                          }
                        })),
              if (sel.kind == 'arrow' && sel.ctrl.length >= 2)
                TextButton.icon(
                    icon: Icon(
                        sel.sharp ? Icons.gesture : Icons.change_history,
                        size: 18),
                    label: Text(sel.sharp ? 'Curva' : 'Pico'),
                    onPressed: _toggleSharp),
              // Recorrido/pase/entrega: número de paso y asignación.
              if ((sel.kind == 'arrow' || sel.kind == 'dot') &&
                  sel.order > 0) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _changeOrder(-1),
                        child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.remove, size: 18)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                            sel.kind == 'dot'
                                ? 'Entrega ${sel.order}'
                                : (sel.owner.isEmpty
                                    ? 'Pase ${sel.order}'
                                    : 'Paso ${sel.order}'),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      InkWell(
                        onTap: () => _changeOrder(1),
                        child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.add, size: 18)),
                      ),
                    ],
                  ),
                ),
                if (sel.kind == 'dot' ||
                    (sel.kind == 'arrow' &&
                        (sel.arrowStyle == 'dashed' ||
                            sel.arrowStyle == 'shot'))) ...[
                  const Text('De', style: TextStyle(fontSize: 11)),
                  _playerDropdown(sel.owner, _setOwner),
                  if (sel.arrowStyle != 'shot') ...[
                    const Text('a', style: TextStyle(fontSize: 11)),
                    _playerDropdown(sel.target, _setTarget),
                  ],
                  if (sel.kind == 'dot')
                    FilterChip(
                      label: const Text('Finta'),
                      selected: sel.fake,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: _setFake,
                    ),
                ],
                if (sel.kind == 'arrow')
                  TextButton.icon(
                      icon: const Icon(Icons.compress, size: 18),
                      label: Text(_leadLabel(sel.lead),
                          style: const TextStyle(fontSize: 12)),
                      onPressed: _cycleLead),
                if (sel.kind == 'arrow')
                  TextButton.icon(
                      icon: const Icon(Icons.fast_forward, size: 18),
                      label: Text('Vel: x${_spdLabel(sel.spd)}',
                          style: const TextStyle(fontSize: 12)),
                      onPressed: _cycleArrowSpeed),
                TextButton.icon(
                    icon: const Icon(Icons.link_off, size: 18),
                    label: Text(sel.kind == 'dot' ? 'Sin paso' : 'Sin recorrido'),
                    onPressed: _clearPath),
              ] else if (sel.kind == 'arrow' &&
                  (isMovementStyle(sel.arrowStyle) ||
                      sel.arrowStyle == 'dashed' ||
                      sel.arrowStyle == 'shot' ||
                      sel.arrowStyle == 'screencont'))
                TextButton.icon(
                    icon: const Icon(Icons.directions_run, size: 18),
                    label: Text(sel.arrowStyle == 'dashed'
                        ? 'Pase'
                        : (sel.arrowStyle == 'shot' ? 'Tiro' : 'Recorrido')),
                    onPressed: _assignPathToSelected)
              else if (sel.kind == 'dot')
                TextButton.icon(
                    icon: const Icon(Icons.tag, size: 18),
                    label: const Text('Paso'),
                    onPressed: () {
                      _pushHistory();
                      setState(() => _items[_selected!] = _items[_selected!]
                          .copyWith(order: _nextOrder()));
                    }),
              TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Duplicar'),
                  onPressed: _duplicateSelected),
              TextButton.icon(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Quitar',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    _pushHistory();
                    setState(() {
                      _items.removeAt(_selected!);
                      _selected = null;
                    });
                  }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    Widget btn(_Tool t, IconData icon, String label) {
      final sel = _tool == t;
      return ChoiceChip(
        avatar: Icon(icon,
            size: 16,
            color: sel ? Colors.white : Theme.of(context).colorScheme.primary),
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(color: sel ? Colors.white : null, fontSize: 11),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) => setState(() {
          _tool = t;
          _contPts = null;
          if (t != _Tool.mover) _selected = null;
          // La selección múltiple se conserva entre «Seleccionar» y «Mover».
          if (t != _Tool.mover && t != _Tool.seleccion) _multiSel = {};
        }),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: const Text('Nº'),
            tooltip: 'Poner número a los jugadores',
            selected: _numbered,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (v) => setState(() => _numbered = v),
          ),
          btn(_Tool.ninguno, Icons.pan_tool_alt_outlined, 'Ninguno'),
          btn(_Tool.mover, Icons.open_with, 'Mover'),
          btn(_Tool.seleccion, Icons.highlight_alt, 'Seleccionar'),
          btn(_Tool.atacante, Icons.radio_button_unchecked, 'Atacante'),
          btn(_Tool.defensor, Icons.expand_less, 'Defensor'),
          btn(_Tool.entrega, Icons.circle, 'Entrega'),
          btn(_Tool.balon, Icons.sports_basketball, 'Balón'),
          btn(_Tool.cono, Icons.change_history, 'Cono'),
          btn(_Tool.corte, Icons.arrow_forward, 'Desp.atac'),
          btn(_Tool.despDef, Icons.turn_right, 'Desp.def'),
          btn(_Tool.pase, Icons.more_horiz, 'Pase'),
          btn(_Tool.bote, Icons.gesture, 'Bote'),
          btn(_Tool.tiro, Icons.double_arrow, 'Tiro'),
          btn(_Tool.pantalla, Icons.horizontal_rule, 'Bloqueo'),
          btn(_Tool.ciega, Icons.density_small, 'Ciega'),
          btn(_Tool.bloqueoCont, Icons.subdirectory_arrow_right, 'Bloq.+cont'),
          btn(_Tool.paseDef, Icons.keyboard_double_arrow_right, 'Pase def.'),
          btn(_Tool.zona, Icons.crop_square, 'Zona'),
          btn(_Tool.texto, Icons.text_fields, 'Texto'),
          btn(_Tool.borrar, Icons.backspace_outlined, 'Borrar'),
        ],
      ),
    );
  }
}
