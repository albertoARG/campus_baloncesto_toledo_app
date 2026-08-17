import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/training_plan_data.dart';
import '../models/play_data.dart';

/// Genera una plantilla de entrenamiento imprimible (estilo hoja de apuntes de
/// baloncesto) con el logo del campus en la esquina superior.
class TrainingTemplateService {
  Future<pw.MemoryImage?> _logo() async {
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  String _safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  Future<pw.MemoryImage?> _asset(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// PDF de una ficha de sesión ya rellena.
  Future<void> printFilled(String titulo, TrainingPlanData d) async {
    final doc = pw.Document();
    final logo = await _logo();
    final halfImg = await _asset('assets/images/media_pista.png');
    final fullImg = await _asset('assets/images/pista_entera.jpg');
    final font = PdfFont.helvetica(doc.document);

    pw.Widget kv(String k, String v) => pw.Text(
        '$k: ${v.trim().isEmpty ? '—' : v}',
        style: const pw.TextStyle(fontSize: 9));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 110,
                height: 56,
                child: logo != null
                    ? pw.Image(logo,
                        fit: pw.BoxFit.contain,
                        alignment: pw.Alignment.topLeft)
                    : pw.SizedBox(),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(titulo,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Wrap(spacing: 14, runSpacing: 2, children: [
                      kv('Día', d.dia),
                      kv('Hora', d.hora),
                      kv('Duración', d.duracion),
                      kv('Lugar', d.lugar),
                      kv('Sesión Nº', d.sesion),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          if (d.objetivos.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text('Objetivos: ${d.objetivos}',
                  style: const pw.TextStyle(fontSize: 10)),
            ),
          pw.Table.fromTextArray(
            headers: [
              'Tiempo',
              'Ejercicio / aspectos',
              'Descripción / observaciones'
            ],
            data: (d.ejercicios.isEmpty
                    ? [const PlanExercise()]
                    : d.ejercicios)
                .map((e) => [e.tiempo, e.nombre, e.descripcion])
                .toList(),
            columnWidths: {
              0: const pw.FixedColumnWidth(48),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
            },
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 26,
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
          ),
          pw.SizedBox(height: 10),
          if (d.asistentes.trim().isNotEmpty || d.ausentes.trim().isNotEmpty)
            pw.Row(children: [
              pw.Expanded(child: kv('Asistentes', d.asistentes)),
              pw.Expanded(child: kv('Ausentes', d.ausentes)),
            ]),
          pw.SizedBox(height: 12),
          if (d.jugadas.isNotEmpty) ...[
            pw.Text('Jugadas',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final play in d.jugadas)
                  _playWidget(play, halfImg, fullImg, font),
              ],
            ),
          ] else ...[
            pw.Text('Pizarra / jugadas',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              for (var i = 0; i < 3; i++)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 8),
                    child: pw.CustomPaint(
                        size: const PdfPoint(160, 90),
                        painter: _paintFullCourt),
                  ),
                ),
            ]),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              for (var i = 0; i < 3; i++)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 8),
                    child: pw.CustomPaint(
                        size: const PdfPoint(120, 120),
                        painter: _paintHalfCourt),
                  ),
                ),
            ]),
          ],
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
              'Campus Baloncesto · ${context.pageNumber}/${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Entrenamiento_${_safe(titulo)}.pdf',
    );
  }

  Future<void> printTemplate() async {
    final doc = pw.Document();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => _sheet(logo),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Plantilla_entrenamiento.pdf',
    );
  }

  pw.Widget _sheet(pw.MemoryImage? logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Cabecera: logo + campos.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              height: 64,
              child: logo != null
                  ? pw.Image(logo,
                      fit: pw.BoxFit.contain,
                      alignment: pw.Alignment.topLeft)
                  : pw.Text('Campus Baloncesto',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _fieldLine('Tema'),
                  _fieldLine('Objetivo'),
                  _fieldLine('Fecha'),
                  _fieldLine('Hora'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        // Zona central: apuntes con líneas + columna de medias pistas.
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 10),
                  child: _linedArea(20),
                ),
              ),
              pw.SizedBox(
                width: 128,
                child: pw.Column(
                  children: [
                    for (var i = 0; i < 4; i++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.SizedBox(
                          width: 128,
                          height: 128,
                          child: pw.CustomPaint(
                            size: const PdfPoint(128, 128),
                            painter: _paintHalfCourt,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        // Pie: fila de pistas completas.
        pw.SizedBox(
          height: 92,
          child: pw.Row(
            children: [
              for (var i = 0; i < 3; i++)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 8),
                    child: pw.CustomPaint(
                      size: const PdfPoint(160, 92),
                      painter: _paintFullCourt,
                    ),
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Plantilla de entrenamiento · Campus Baloncesto',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _fieldLine(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('$label: ',
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Container(
              height: 12,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey, width: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _linedArea(int lines) {
    return pw.Column(
      children: [
        for (var i = 0; i < lines; i++)
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom:
                        pw.BorderSide(color: PdfColors.grey400, width: 0.6)),
              ),
            ),
          ),
      ],
    );
  }

  // ── Dibujo de una jugada en el PDF ──────────────────────────────────────

  /// Widget de una jugada: la imagen de pista de fondo + los elementos encima.
  /// Si la jugada tiene varios fotogramas, se dibujan todos etiquetados «Paso N».
  pw.Widget _playWidget(Play play, pw.MemoryImage? halfImg,
      pw.MemoryImage? fullImg, PdfFont font) {
    final frames = play.framesOrSingle;
    pw.Widget diagram;
    if (frames.length <= 1) {
      diagram = _frameWidget(play, play.items, halfImg, fullImg, font,
          play.court == 'full' ? 250.0 : 190.0);
    } else {
      final w = play.court == 'full' ? 165.0 : 130.0;
      diagram = pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < frames.length; i++)
            pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    play.frameTitleAt(i).isNotEmpty
                        ? 'Paso ${i + 1}: ${play.frameTitleAt(i)}'
                        : 'Paso ${i + 1}',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                _frameWidget(play, frames[i], halfImg, fullImg, font, w),
              ],
            ),
        ],
      );
    }
    if (play.title.isEmpty) return diagram;
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(play.title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        diagram,
      ],
    );
  }

  /// Dibuja un fotograma concreto (lista de elementos) sobre la pista.
  pw.Widget _frameWidget(Play play, List<PlayItem> items,
      pw.MemoryImage? halfImg, pw.MemoryImage? fullImg, PdfFont font, double w) {
    final img = play.court == 'full' ? fullImg : halfImg;
    final h = w / play.aspect;
    final size = PdfPoint(w, h);
    final framePlay =
        Play(court: play.court, items: items, itemScale: play.itemScale);
    if (img != null) {
      return pw.SizedBox(
        width: w,
        height: h,
        child: pw.Stack(
          children: [
            pw.Positioned.fill(child: pw.Image(img, fit: pw.BoxFit.fill)),
            pw.CustomPaint(
                size: size,
                painter: (c, s) => _paintPlayItems(c, s, framePlay, font)),
          ],
        ),
      );
    }
    return pw.CustomPaint(
        size: size, painter: (c, s) => _paintPlay(c, s, framePlay, font));
  }

  static void _paintPlay(PdfGraphics c, PdfPoint s, Play play, PdfFont font) {
    c.setLineWidth(0.8);
    c.setStrokeColor(PdfColors.grey600);
    _courtPdf(c, s.x, s.y, play.court);
    _paintPlayItems(c, s, play, font);
  }

  static void _paintPlayItems(
      PdfGraphics c, PdfPoint s, Play play, PdfFont font) {
    final w = s.x, h = s.y;
    // En pista entera los símbolos se reducen (igual que en la app).
    final k = play.itemScale * (play.court == 'full' ? 0.52 : 1.0);
    double px(double nx) => nx * w;
    double py(double ny) => h - ny * h; // el 0 normalizado es arriba

    // Zonas de fondo.
    for (final it in play.items) {
      if (it.kind == 'zone' && it.pts.length >= 2) {
        final ax = px(it.pts[0][0]), ay = py(it.pts[0][1]);
        final bx = px(it.pts[1][0]), by = py(it.pts[1][1]);
        final x = ax < bx ? ax : bx, y = ay < by ? ay : by;
        final rw = (bx - ax).abs(), rh = (by - ay).abs();
        c.setFillColor(const PdfColor(1, 0.75, 0, 0.22));
        c.drawRect(x, y, rw, rh);
        c.fillPath();
        c.setLineWidth(1);
        c.setStrokeColor(PdfColors.amber700);
        c.drawRect(x, y, rw, rh);
        c.strokePath();
      }
    }

    for (final it in play.items) {
      if (it.kind == 'player') {
        c.setLineWidth(1.4);
        final r = w * 0.026 * k;
        final ox = px(it.x), oy = py(it.y);
        // Rotación del defensor (grados). En PDF la y va hacia arriba, por eso
        // se resta para que el giro coincida visualmente con la app.
        final defRot = (it.rot + (it.flip ? 180 : 0)) * math.pi / 180;
        if (it.team == 'off') {
          c.setStrokeColor(PdfColors.blue800);
          c.drawEllipse(ox, oy, r, r);
          c.strokePath();
        } else {
          // Defensor: arco (∩) orientable en 360º.
          c.setStrokeColor(PdfColors.grey900);
          const segs = 14;
          for (var i = 0; i <= segs; i++) {
            final ang = math.pi - math.pi * i / segs - defRot;
            final x = ox + r * math.cos(ang), y = oy + r * math.sin(ang);
            if (i == 0) {
              c.moveTo(x, y);
            } else {
              c.lineTo(x, y);
            }
          }
          c.strokePath();
        }
        if (it.label.isNotEmpty) {
          final fs = r * 1.1;
          c.setFillColor(
              it.team == 'off' ? PdfColors.blue800 : PdfColors.grey900);
          if (it.team == 'off') {
            c.drawString(font, fs, it.label,
                ox - fs * 0.3 * it.label.length, oy - fs * 0.35);
          } else {
            // Número en el lado abierto del arco.
            final openAng = -math.pi / 2 - defRot;
            final tx = ox + math.cos(openAng) * r * 0.7;
            final ty = oy + math.sin(openAng) * r * 0.7;
            c.drawString(font, fs, it.label,
                tx - fs * 0.3 * it.label.length, ty - fs * 0.35);
          }
        }
        final nballs = it.ballCount;
        if (nballs > 0) {
          // Los balones acompañan la orientación (en PDF la y va hacia arriba).
          final base = it.team == 'off' ? math.pi / 4 : 0.0;
          c.setFillColor(PdfColors.orange800);
          for (var bi = 0; bi < nballs; bi++) {
            final ang = base -
                defRot +
                (nballs == 1 ? 0.0 : (bi - (nballs - 1) / 2) * 0.9);
            c.drawEllipse(ox + math.cos(ang) * r * 1.5,
                oy + math.sin(ang) * r * 1.5, r * 0.5, r * 0.5);
            c.fillPath();
          }
        }
      } else if (it.kind == 'dot') {
        // Entrega mano a mano: barra + balón.
        final ox = px(it.x), oy = py(it.y);
        final r = w * 0.018 * k;
        final rot = it.rot * math.pi / 180;
        final dx = math.cos(rot) * r * 1.7, dy = math.sin(rot) * r * 1.7;
        c.setStrokeColor(PdfColors.grey900);
        c.setLineWidth(math.max(1.0, w * 0.009 * k));
        c.moveTo(ox - dx, oy - dy);
        c.lineTo(ox + dx, oy + dy);
        c.strokePath();
        c.setFillColor(PdfColors.orange800);
        c.drawEllipse(ox, oy, r * 0.7, r * 0.7);
        c.fillPath();
      } else if (it.kind == 'ball') {
        final ox = px(it.x), oy = py(it.y);
        final r = w * 0.016 * k;
        c.setFillColor(PdfColors.orange800);
        c.drawEllipse(ox, oy, r, r);
        c.fillPath();
        c.setStrokeColor(PdfColors.brown900);
        c.setLineWidth(math.max(0.4, r * 0.12));
        c.drawEllipse(ox, oy, r, r);
        c.moveTo(ox - r, oy);
        c.lineTo(ox + r, oy);
        c.moveTo(ox, oy - r);
        c.lineTo(ox, oy + r);
        c.strokePath();
      } else if (it.kind == 'cross') {
        c.setLineWidth(1.4);
        c.setStrokeColor(PdfColors.purple800);
        final r = w * 0.02 * k;
        final ox = px(it.x), oy = py(it.y);
        c.moveTo(ox - r, oy - r);
        c.lineTo(ox + r, oy + r);
        c.moveTo(ox - r, oy + r);
        c.lineTo(ox + r, oy - r);
        c.strokePath();
      } else if (it.kind == 'text' && it.label.isNotEmpty) {
        final fs = w * 0.028 * k;
        c.setFillColor(PdfColors.grey900);
        c.drawString(font, fs, it.label,
            px(it.x) - fs * 0.28 * it.label.length, py(it.y) - fs * 0.35);
      } else if (it.kind == 'cone') {
        c.setLineWidth(1.2);
        c.setStrokeColor(PdfColors.orange800);
        final r = w * 0.03 * k;
        final ox = px(it.x), oy = py(it.y);
        c.moveTo(ox, oy + r);
        c.lineTo(ox - r * 0.85, oy - r * 0.8);
        c.lineTo(ox + r * 0.85, oy - r * 0.8);
        c.closePath();
        c.strokePath();
      } else if (it.kind == 'arrow' && it.pts.length >= 2) {
        final lw = (w * 0.008 * k).clamp(0.5, 4.0);
        c.setLineWidth(lw);
        c.setStrokeColor(PdfColors.red800);
        final ax = px(it.pts.first[0]), ay = py(it.pts.first[1]);
        final bx = px(it.pts.last[0]), by = py(it.pts.last[1]);
        if (it.arrowStyle == 'shot') {
          // Tiro (=>): la doble línea termina antes y una línea entra en la flecha.
          final dir = math.atan2(by - ay, bx - ax);
          final ux = math.cos(dir), uy = math.sin(dir);
          final ox = -uy * (lw * 0.8 + 0.7), oy = ux * (lw * 0.8 + 0.7);
          final head = w * 0.04 * k;
          final sx = bx - ux * head * 0.7, sy = by - uy * head * 0.7;
          c.setLineWidth(math.max(0.4, lw * 0.5)); // "=" más fino
          c.moveTo(ax + ox, ay + oy);
          c.lineTo(sx + ox, sy + oy);
          c.moveTo(ax - ox, ay - oy);
          c.lineTo(sx - ox, sy - oy);
          c.strokePath();
          c.setLineWidth(lw); // ">" normal
          _headPdf(c, ax, ay, bx, by, head);
        } else if (it.arrowStyle == 'chevrons') {
          // Pase definitivo: cadena de chevrones.
          final head = w * 0.04 * k;
          final dir = math.atan2(by - ay, bx - ax);
          final total =
              math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
          final n = math.max(3, (total / (head * 1.3)).floor());
          final step = total / n;
          for (var i = 1; i <= n; i++) {
            final tx = ax + math.cos(dir) * step * i;
            final ty = ay + math.sin(dir) * step * i;
            _headPdf(c, ax, ay, tx, ty, head * 0.7);
          }
        } else if (it.arrowStyle == 'screencont') {
          // Bloqueo y continuación: dos tramos (con sus curvas) + barra + flecha.
          final head = w * 0.04 * k;
          final line = arrowLine(it).map((e) => [px(e[0]), py(e[1])]).toList();
          c.moveTo(line[0][0], line[0][1]);
          for (var i = 1; i < line.length; i++) {
            c.lineTo(line[i][0], line[i][1]);
          }
          c.strokePath();
          if (it.pts.length >= 2) {
            _barPdf(c, px(it.pts[0][0]), py(it.pts[0][1]), px(it.pts[1][0]),
                py(it.pts[1][1]), w * 0.036 * k);
          }
          final la = line[line.length - 2], lb = line.last;
          _headPdf(c, la[0], la[1], lb[0], lb[1], head);
        } else {
          final head = w * 0.04 * k;
          // Cuerpo recto, curvo (punto de control) o a mano alzada (multi).
          final curved = it.ctrl.length >= 2;
          final multi = it.pts.length > 2 && it.ctrl.isEmpty;
          final shaft = multi
              ? it.pts.map((e) => [px(e[0]), py(e[1])]).toList()
              : (!curved
                  ? [
                      [ax, ay],
                      [bx, by]
                    ]
                  : (it.sharp
                      ? [
                          [ax, ay],
                          [px(it.ctrl[0]), py(it.ctrl[1])],
                          [bx, by]
                        ]
                      : quadBezier(
                          ax, ay, px(it.ctrl[0]), py(it.ctrl[1]), bx, by)));
          final pen = shaft[shaft.length - 2];
          if (it.arrowStyle == 'dashed') {
            if (curved || multi) {
              _dashedPolyPdf(c, shaft);
            } else {
              _dashedPdf(c, ax, ay, bx, by);
            }
          } else if (it.arrowStyle == 'snake') {
            c.setLineWidth(math.max(0.4, lw * 0.6)); // bote más fino
            final wave = (curved || multi)
                ? waveAlongPolyline(shaft, w * 0.02 * k)
                : wavePolyline(ax, ay, bx, by, w * 0.02 * k);
            c.moveTo(wave.first[0], wave.first[1]);
            for (var i = 1; i < wave.length; i++) {
              c.lineTo(wave[i][0], wave[i][1]);
            }
            c.lineTo(bx, by); // acabar en la punta
            c.strokePath();
            c.setLineWidth(lw);
          } else {
            // solid / defense / screen: cuerpo (curvo o recto).
            c.moveTo(shaft.first[0], shaft.first[1]);
            for (var i = 1; i < shaft.length; i++) {
              c.lineTo(shaft[i][0], shaft[i][1]);
            }
            c.strokePath();
          }
          if (it.arrowStyle == 'screen') {
            _barPdf(c, pen[0], pen[1], bx, by, w * 0.045 * k);
          } else if (it.arrowStyle == 'screen2') {
            _barPdf(c, pen[0], pen[1], bx, by, w * 0.045 * k, dbl: true);
          } else if (it.arrowStyle == 'defense') {
            // Gancho: semicírculo en la punta (volteable, tangente al final).
            final dir = math.atan2(by - pen[1], bx - pen[0]);
            final sd = it.flip ? -1.0 : 1.0;
            final hr = head * 0.55;
            final cx = bx + math.cos(dir + sd * math.pi / 2) * hr;
            final cy = by + math.sin(dir + sd * math.pi / 2) * hr;
            const segs = 10;
            for (var i = 0; i <= segs; i++) {
              final ang = (dir - sd * math.pi / 2) + sd * math.pi * i / segs;
              final x = cx + hr * math.cos(ang), y = cy + hr * math.sin(ang);
              if (i == 0) {
                c.moveTo(x, y);
              } else {
                c.lineTo(x, y);
              }
            }
            c.strokePath();
          } else {
            // solid / dashed / snake: flecha en la punta.
            _headPdf(c, pen[0], pen[1], bx, by, head);
          }
        }
      }
    }
  }

  static void _courtPdf(PdfGraphics c, double w, double h, String court) {
    final m = w * 0.02;
    c.drawRect(m, m, w - 2 * m, h - 2 * m);
    c.strokePath();
    if (court == 'full') {
      c.moveTo(w / 2, m);
      c.lineTo(w / 2, h - m);
      c.strokePath();
      c.drawEllipse(w / 2, h / 2, h * 0.12, h * 0.12);
      c.strokePath();
      final keyW = w * 0.13, keyH = h * 0.44;
      c.drawRect(m, (h - keyH) / 2, keyW, keyH);
      c.drawRect(w - m - keyW, (h - keyH) / 2, keyW, keyH);
      c.strokePath();
      c.drawEllipse(m + keyW, h / 2, keyH * 0.22, keyH * 0.22);
      c.drawEllipse(w - m - keyW, h / 2, keyH * 0.22, keyH * 0.22);
      c.strokePath();
    } else {
      // media pista con el aro arriba (y alta en PDF)
      final keyW = w * 0.32, keyH = h * 0.38;
      c.drawRect((w - keyW) / 2, h - m - keyH, keyW, keyH);
      c.strokePath();
      c.drawEllipse(w / 2, h - m - keyH, keyW / 2, keyW / 2);
      c.strokePath();
      c.drawEllipse(w / 2, h - m - h * 0.025, w * 0.02, w * 0.02);
      c.strokePath();
    }
  }

  static void _dashedPdf(
      PdfGraphics c, double ax, double ay, double bx, double by) {
    final total = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
    if (total == 0) return;
    final ux = (bx - ax) / total, uy = (by - ay) / total;
    const dash = 6.0, gap = 4.0;
    double d = 0;
    while (d < total) {
      final e = math.min(d + dash, total);
      c.moveTo(ax + ux * d, ay + uy * d);
      c.lineTo(ax + ux * e, ay + uy * e);
      d += dash + gap;
    }
    c.strokePath();
  }

  // Guiones a lo largo de una polilínea (para flechas de pase curvas).
  static void _dashedPolyPdf(PdfGraphics c, List<List<double>> pts) {
    const dash = 6.0, gap = 4.0;
    bool draw = true;
    double rem = dash;
    var prevX = pts.first[0], prevY = pts.first[1];
    for (var i = 1; i < pts.length; i++) {
      var tx = pts[i][0], ty = pts[i][1];
      var segLen = math.sqrt((tx - prevX) * (tx - prevX) + (ty - prevY) * (ty - prevY));
      while (segLen > 0.0001) {
        final step = math.min(rem, segLen);
        final ux = (tx - prevX) / segLen, uy = (ty - prevY) / segLen;
        final nx = prevX + ux * step, ny = prevY + uy * step;
        if (draw) {
          c.moveTo(prevX, prevY);
          c.lineTo(nx, ny);
        }
        prevX = nx;
        prevY = ny;
        segLen -= step;
        rem -= step;
        if (rem <= 0.0001) {
          draw = !draw;
          rem = draw ? dash : gap;
        }
      }
      prevX = pts[i][0];
      prevY = pts[i][1];
    }
    c.strokePath();
  }

  static void _headPdf(
      PdfGraphics c, double ax, double ay, double bx, double by, double len) {
    final angle = math.atan2(by - ay, bx - ax);
    const spread = 0.5;
    c.moveTo(bx, by);
    c.lineTo(bx - math.cos(angle - spread) * len,
        by - math.sin(angle - spread) * len);
    c.moveTo(bx, by);
    c.lineTo(bx - math.cos(angle + spread) * len,
        by - math.sin(angle + spread) * len);
    c.strokePath();
  }

  static void _barPdf(
      PdfGraphics c, double ax, double ay, double bx, double by, double len,
      {bool dbl = false}) {
    final dir = math.atan2(by - ay, bx - ax);
    final perp = dir + math.pi / 2;
    final dx = math.cos(perp) * len, dy = math.sin(perp) * len;
    c.moveTo(bx - dx, by - dy);
    c.lineTo(bx + dx, by + dy);
    if (dbl) {
      final backX = bx - math.cos(dir) * len * 0.6;
      final backY = by - math.sin(dir) * len * 0.6;
      c.moveTo(backX - dx, backY - dy);
      c.lineTo(backX + dx, backY + dy);
    }
    c.strokePath();
  }

  static void _paintHalfCourt(PdfGraphics c, PdfPoint s) {
    final w = s.x, h = s.y;
    c.setLineWidth(0.8);
    c.setStrokeColor(PdfColors.grey700);
    // Borde exterior.
    c.drawRect(0, 0, w, h);
    // Zona (key) desde arriba.
    final keyW = w * 0.34, keyH = h * 0.46;
    c.drawRect((w - keyW) / 2, h - keyH, keyW, keyH);
    // Círculo de tiros libres.
    c.drawEllipse(w / 2, h - keyH, keyW / 2, keyW / 2);
    // Aro.
    c.drawEllipse(w / 2, h - 8, 2.5, 2.5);
    // Tablero.
    c.moveTo(w * 0.38, h - 4);
    c.lineTo(w * 0.62, h - 4);
    c.strokePath();
  }

  static void _paintFullCourt(PdfGraphics c, PdfPoint s) {
    final w = s.x, h = s.y;
    c.setLineWidth(0.8);
    c.setStrokeColor(PdfColors.grey700);
    c.drawRect(0, 0, w, h);
    // Línea de medio campo.
    c.moveTo(w / 2, 0);
    c.lineTo(w / 2, h);
    // Círculo central.
    c.drawEllipse(w / 2, h / 2, h * 0.16, h * 0.16);
    // Zonas y aros.
    final keyW = w * 0.16, keyH = h * 0.42;
    c.drawRect(0, (h - keyH) / 2, keyW, keyH);
    c.drawEllipse(keyW, h / 2, keyH * 0.26, keyH * 0.26);
    c.drawRect(w - keyW, (h - keyH) / 2, keyW, keyH);
    c.drawEllipse(w - keyW, h / 2, keyH * 0.26, keyH * 0.26);
    c.strokePath();
  }
}
