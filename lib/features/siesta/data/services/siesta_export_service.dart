import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/siesta_competition_model.dart';
import '../models/siesta_daily_score_model.dart';
import '../models/siesta_match_model.dart';
import '../models/siesta_participant_model.dart';

/// Servicio encargado de generar y exportar a PDF las clasificaciones,
/// cuadros y eliminatorias de cualquier competición de siesta.
class SiestaExportService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF5E35B1);
  static const PdfColor _primaryLight = PdfColor.fromInt(0xFFEDE7F6);
  static const PdfColor _accent = PdfColor.fromInt(0xFFFF9800);

  /// Orden de las rondas de eliminatoria (de primera a última).
  static const List<String> _eliminationOrder = [
    'dieciseisavos',
    'octavos',
    'cuartos',
    'semifinal',
    'semifinales',
    'tercer',
    'final',
  ];

  // ---------------------------------------------------------------------------
  // Public API — one method per competition format
  // ---------------------------------------------------------------------------

  /// Liga / Grupos + Playoffs: clasificación agrupada + cuadro de eliminatorias.
  Future<void> exportLeagueToPdf({
    required SiestaCompetitionModel competition,
    required List<SiestaParticipantModel> participants,
    required List<SiestaMatchModel> matches,
  }) async {
    final logo = await _loadLogo();
    final doc = pw.Document();

    // Standings grouped by 'grupo'.
    final Map<String, List<SiestaParticipantModel>> groups = {};
    for (final p in participants) {
      final g = (p.grupo ?? '').trim();
      final groupName = g.isEmpty ? 'General' : 'Grupo $g';
      groups.putIfAbsent(groupName, () => []).add(p);
    }
    final sortedGroupKeys = groups.keys.toList()..sort();
    for (final key in sortedGroupKeys) {
      _sortParticipants(groups[key]!, matches);
    }

    // Bracket rounds grouped by 'ronda' — groups first, eliminations last.
    final Map<String, List<SiestaMatchModel>> roundsMap = {};
    for (final m in matches) {
      final ronda = (m.ronda ?? '').trim();
      if (ronda.isEmpty) continue;
      roundsMap.putIfAbsent(ronda, () => []).add(m);
    }
    final sortedRoundKeys = roundsMap.keys.toList()
      ..sort(_compareRounds);

    final participantById = {for (final p in participants) p.id: p};

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            context.pageNumber == 1 ? _buildHeader(competition, logo) : pw.SizedBox(),
        footer: _footer,
        build: (context) => [
          pw.SizedBox(height: 8),
          _sectionTitle('Clasificación'),
          pw.SizedBox(height: 8),
          ...sortedGroupKeys.map((key) => _buildStandingsTable(key, groups[key]!)),
          if (sortedRoundKeys.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _sectionTitle('Eliminatorias / Cuadro'),
            pw.SizedBox(height: 8),
            ...sortedRoundKeys.map(
              (key) => _buildRoundBlock(key, roundsMap[key]!, participantById),
            ),
          ],
        ],
      ),
    );

    await _print(doc, competition.nombre);
  }

  /// Formato individual (escalera diaria): ranking simple por puntos.
  Future<void> exportRankingToPdf({
    required SiestaCompetitionModel competition,
    required List<SiestaParticipantModel> participants,
  }) async {
    final logo = await _loadLogo();
    final doc = pw.Document();

    final sorted = List<SiestaParticipantModel>.from(participants)
      ..sort((a, b) => b.puntosLiga.compareTo(a.puntosLiga));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            context.pageNumber == 1 ? _buildHeader(competition, logo) : pw.SizedBox(),
        footer: _footer,
        build: (context) => [
          pw.SizedBox(height: 8),
          _sectionTitle('Clasificación'),
          pw.SizedBox(height: 8),
          _buildSimpleRankingTable(
            headers: const ['#', 'Jugador', 'Puntos'],
            rows: [
              for (var i = 0; i < sorted.length; i++)
                [
                  '${i + 1}',
                  sorted[i].user != null
                      ? '${sorted[i].user!.nombre} ${sorted[i].user!.apellidos}'
                      : 'Desconocido',
                  '${sorted[i].puntosLiga}',
                ],
            ],
          ),
        ],
      ),
    );

    await _print(doc, competition.nombre);
  }

  /// Tiros libres seguidos: ranking por número de tiros, con fecha.
  Future<void> exportFreeThrowsToPdf({
    required SiestaCompetitionModel competition,
    required List<SiestaDailyScoreModel> scores,
  }) async {
    final logo = await _loadLogo();
    final doc = pw.Document();

    final sorted = List<SiestaDailyScoreModel>.from(scores)
      ..sort((a, b) => b.puntos.compareTo(a.puntos));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            context.pageNumber == 1 ? _buildHeader(competition, logo) : pw.SizedBox(),
        footer: _footer,
        build: (context) => [
          pw.SizedBox(height: 8),
          _sectionTitle('Clasificación Tiros Libres'),
          pw.SizedBox(height: 8),
          _buildSimpleRankingTable(
            headers: const ['#', 'Jugador', 'Fecha', 'Tiros'],
            rows: [
              for (var i = 0; i < sorted.length; i++)
                [
                  '${i + 1}',
                  sorted[i].user != null
                      ? '${sorted[i].user!.nombre} ${sorted[i].user!.apellidos}'
                      : 'Desconocido',
                  _formatDate(sorted[i].fecha),
                  '${sorted[i].puntos}',
                ],
            ],
          ),
        ],
      ),
    );

    await _print(doc, competition.nombre);
  }

  // ---------------------------------------------------------------------------
  // Round ordering — groups first, elimination rounds last
  // ---------------------------------------------------------------------------

  int _eliminationIndex(String round) {
    final lower = round.toLowerCase();
    return _eliminationOrder.indexWhere((r) => lower.contains(r));
  }

  int _compareRounds(String a, String b) {
    final idxA = _eliminationIndex(a);
    final idxB = _eliminationIndex(b);
    final aElim = idxA != -1;
    final bElim = idxB != -1;

    // Both elimination rounds → order by stage (octavos → ... → final).
    if (aElim && bElim) return idxA.compareTo(idxB);
    // Only one is elimination → groups go first, eliminations to the end.
    if (aElim) return 1;
    if (bElim) return -1;
    // Both are group/other rounds → alphabetical.
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  // ---------------------------------------------------------------------------
  // Shared PDF helpers
  // ---------------------------------------------------------------------------

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<void> _print(pw.Document doc, String compName) async {
    final fileName = 'Clasificacion_${_sanitize(compName)}.pdf';
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: fileName,
    );
  }

  pw.Widget _footer(pw.Context context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Campus Baloncesto · Página ${context.pageNumber}/${context.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      );

  pw.Widget _buildHeader(
    SiestaCompetitionModel competition,
    pw.MemoryImage? logo,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.SizedBox(height: 48, width: 48, child: pw.Image(logo)),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  competition.nombre,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${competition.juego} · Formato: ${competition.formato.replaceAll('_', ' ')}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.Text(
            _formatDate(DateTime.now()),
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _accent,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  /// Tabla de clasificación de liga con columnas J/G/P/Pts.
  pw.Widget _buildStandingsTable(
    String groupName,
    List<SiestaParticipantModel> participants,
  ) {
    final headers = ['#', 'Jugador', 'J', 'G', 'P', 'Pts'];

    final rows = <pw.TableRow>[_headerRow(headers)];
    for (var i = 0; i < participants.length; i++) {
      final p = participants[i];
      final name = p.user != null
          ? '${p.user!.nombre} ${p.user!.apellidos}'
          : 'Desconocido';
      rows.add(
        _dataRow(
          [
            '${i + 1}',
            name,
            '${p.partidosJugados}',
            '${p.partidosGanados}',
            '${p.partidosPerdidos}',
            '${p.puntosLiga}',
          ],
          even: i.isEven,
          nameColumn: 1,
          highlightColumn: 5,
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
          child: pw.Text(
            groupName,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(34),
            3: pw.FixedColumnWidth(34),
            4: pw.FixedColumnWidth(34),
            5: pw.FixedColumnWidth(42),
          },
          children: rows,
        ),
      ],
    );
  }

  /// Tabla de ranking genérica (formatos individual / tiros libres).
  pw.Widget _buildSimpleRankingTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final tableRows = <pw.TableRow>[_headerRow(headers)];
    final highlightCol = headers.length - 1;
    for (var i = 0; i < rows.length; i++) {
      tableRows.add(
        _dataRow(
          rows[i],
          even: i.isEven,
          nameColumn: 1,
          highlightColumn: highlightCol,
        ),
      );
    }

    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(28),
      1: const pw.FlexColumnWidth(),
    };
    for (var c = 2; c < headers.length; c++) {
      widths[c] = const pw.FixedColumnWidth(80);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: widths,
      children: tableRows,
    );
  }

  pw.TableRow _headerRow(List<String> headers) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _primary),
      children: headers
          .map(
            (h) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _dataRow(
    List<String> cells, {
    required bool even,
    required int nameColumn,
    required int highlightColumn,
  }) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: even ? PdfColors.white : _primaryLight),
      children: List.generate(cells.length, (c) {
        final isName = c == nameColumn;
        final isHighlight = c == highlightColumn;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: pw.Text(
            cells[c],
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: (isHighlight || isName)
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: isHighlight ? _primary : PdfColors.black,
            ),
            textAlign: isName ? pw.TextAlign.left : pw.TextAlign.center,
          ),
        );
      }),
    );
  }

  pw.Widget _buildRoundBlock(
    String roundName,
    List<SiestaMatchModel> matches,
    Map<String, SiestaParticipantModel> participantById,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
          child: pw.Text(
            roundName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: matches.map((m) {
            final p1 = participantById[m.participant1Id];
            final p2 = participantById[m.participant2Id];
            final p1Name = p1?.user != null
                ? '${p1!.user!.nombre} ${p1.user!.apellidos}'
                : 'P1';
            final p2Name = p2?.user != null
                ? '${p2!.user!.nombre} ${p2.user!.apellidos}'
                : 'P2';
            final finished = m.estado == 'finalizado';
            final p1Won = finished && m.score1 > m.score2;
            final p2Won = finished && m.score2 > m.score1;

            return pw.Container(
              width: 230,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _bracketRow(p1Name, finished ? '${m.score1}' : '-', p1Won),
                  pw.Divider(height: 8, color: PdfColors.grey300),
                  _bracketRow(p2Name, finished ? '${m.score2}' : '-', p2Won),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  pw.Widget _bracketRow(String name, String score, bool winner) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            name,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: winner ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          score,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: winner ? _primary : PdfColors.black,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Replica la lógica de desempate (FIBA) usada en la vista de clasificación.
  void _sortParticipants(
    List<SiestaParticipantModel> group,
    List<SiestaMatchModel> matches,
  ) {
    group.sort((a, b) {
      final ptsA = a.puntosLiga;
      final ptsB = b.puntosLiga;
      if (ptsA != ptsB) return ptsB.compareTo(ptsA);

      final tiedPts = ptsA;
      final tiedGroup = group.where((p) => p.puntosLiga == tiedPts).toList();

      if (tiedGroup.length == 2) {
        int aWins = 0;
        int bWins = 0;
        int aDiff = 0;
        int bDiff = 0;
        for (final m in matches) {
          if (m.estado != 'finalizado') continue;
          final isA1 = m.participant1Id == a.id && m.participant2Id == b.id;
          final isA2 = m.participant2Id == a.id && m.participant1Id == b.id;
          if (isA1 || isA2) {
            final scoreA = isA1 ? m.score1 : m.score2;
            final scoreB = isA1 ? m.score2 : m.score1;
            if (scoreA > scoreB) {
              aWins++;
            } else if (scoreB > scoreA) {
              bWins++;
            }
            aDiff += (scoreA - scoreB);
            bDiff += (scoreB - scoreA);
          }
        }
        if (aWins != bWins) return bWins.compareTo(aWins);
        if (aDiff != bDiff) return bDiff.compareTo(aDiff);
      } else if (tiedGroup.length > 2) {
        final tiedIds = tiedGroup.map((p) => p.id).toSet();
        int aDiff = 0;
        int bDiff = 0;
        for (final m in matches) {
          if (m.estado != 'finalizado') continue;
          if (tiedIds.contains(m.participant1Id) &&
              tiedIds.contains(m.participant2Id)) {
            if (m.participant1Id == a.id) {
              aDiff += m.score1 - m.score2;
            } else if (m.participant2Id == a.id) {
              aDiff += m.score2 - m.score1;
            }
            if (m.participant1Id == b.id) {
              bDiff += m.score1 - m.score2;
            } else if (m.participant2Id == b.id) {
              bDiff += m.score2 - m.score1;
            }
          }
        }
        if (aDiff != bDiff) return bDiff.compareTo(aDiff);
      }

      final winsA = a.partidosGanados;
      final winsB = b.partidosGanados;
      if (winsA != winsB) return winsB.compareTo(winsA);
      return 0;
    });
  }

  String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
