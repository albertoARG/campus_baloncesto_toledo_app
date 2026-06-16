import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../repositories/competitions_repository.dart';
import '../../presentation/providers/competitions_providers.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  final supabaseClient = Supabase.instance.client;
  final repo = ref.watch(competitionsRepositoryProvider);
  return ExportService(supabaseClient, repo);
});

class ExportService {
  final SupabaseClient _supabaseClient;
  final CompetitionsRepository _competitionsRepo;

  ExportService(this._supabaseClient, this._competitionsRepo);

  Future<String> exportStandingsToExcel() async {
    // 1. Get all days
    final days = await _competitionsRepo.getStationDays();
    final allDays = days.toList();
    allDays.sort((a, b) {
      final numRegex = RegExp(r'\d+');
      final matchA = numRegex.firstMatch(a.nombre);
      final matchB = numRegex.firstMatch(b.nombre);
      
      if (matchA != null && matchB != null) {
        final numA = int.parse(matchA.group(0)!);
        final numB = int.parse(matchB.group(0)!);
        if (numA != numB) {
          return numA.compareTo(numB);
        }
      }
      return a.nombre.compareTo(b.nombre);
    });
    
    // 2. Get all groups (solo de competición; excluye equipos de partido)
    final groupsResponse = await _supabaseClient
        .from('teams')
        .select()
        .eq('is_match_team', false)
        .order('nombre');
    
    // 3. Keep all data in memory
    final globalRankings = await _competitionsRepo.getGlobalStandings();
    
    final Map<String, List<Map<String, dynamic>>> rankingsPerDay = {};
    for (var day in allDays) {
       if (day.isPublished) {
         rankingsPerDay[day.id] = await _competitionsRepo.getGlobalStandings(dayId: day.id);
       }
    }
    
    // Map players to their teams
    final teamMembersResponse = await _supabaseClient.from('team_members').select('team_id, user_id');
    final Map<String, String> userToTeam = {};
    for(var row in teamMembersResponse as List) {
      userToTeam[row['user_id']] = row['team_id'];
    }

    // 4. Create Excel
    var excel = Excel.createExcel();
    
    CellStyle centerStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    
    for (var group in groupsResponse as List) {
      final teamId = group['id'];
      final String teamName = group['nombre'] ?? 'Grupo';
      
      Sheet sheetObject = excel[teamName];
      
      // Ampliar la primera columna (columna 0) para que entren los nombres
      sheetObject.setColumnWidth(0, 35.0);
      
      // Select the players in this group from the overall globalRankings 
      // globalRankings is ALREADY sorted by totalScore descending!
      final teamPlayersRankings = globalRankings.where((r) {
        UserModel p = r['player'];
        return userToTeam[p.id] == teamId;
      }).toList();
      
      if (teamPlayersRankings.isEmpty) continue;

      // Header row
      List<CellValue> headers = [
        TextCellValue('Jugador'),
      ];
      for (var day in allDays) {
        final shortName = day.nombre.replaceAll(RegExp(r'competici[oó]n\s*', caseSensitive: false), '').trim();
        headers.add(TextCellValue(shortName));
      }
      headers.add(TextCellValue('TOTAL'));
      
      sheetObject.appendRow(headers);
      
      // Rows for each player
      for (var ranking in teamPlayersRankings) {
        UserModel player = ranking['player'];
        final int totalOverall = ranking['totalScore'] ?? 0;
        
        List<CellValue> rowData = [
          TextCellValue('${player.nombre} ${player.apellidos}'),
        ];
        
        for (var day in allDays) {
           if (!day.isPublished) {
             rowData.add(TextCellValue(''));
           } else {
             final dayRankingList = rankingsPerDay[day.id] ?? [];
             // Find player's score for this day
             int dayScore = 0;
             try {
               final dayRanking = dayRankingList.firstWhere(
                 (r) => (r['player'] as UserModel).id == player.id
               );
               dayScore = dayRanking['totalScore'] ?? 0;
             } catch (_) {
               dayScore = 0;
             }
             rowData.add(IntCellValue(dayScore));
           }
        }
        
        rowData.add(IntCellValue(totalOverall));
        
        sheetObject.appendRow(rowData);
        
        // Centrar las columnas de puntuación (de la 1 en adelante)
        for (int c = 1; c < rowData.length; c++) {
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sheetObject.maxRows - 1)).cellStyle = centerStyle;
        }
      }
    }
    
    // Remove default sheet if not used
    if (excel.sheets.keys.contains('Sheet1') && excel.sheets.keys.length > 1) {
       excel.delete('Sheet1');
    }
    
    // 5. Save file locally
    // In excel ^4.0.0, passing fileName automatically triggers a file download in the browser on Web
    final fileBytes = excel.save(fileName: 'Clasificacion_Campus.xlsx');
    
    if (kIsWeb) {
      // On the web, we do not have access to local directories, so we stop here.
      return 'Excel descargado en tu navegador.';
    }
    
    if (fileBytes != null) {
      if (Platform.isAndroid) {
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (!downloadDir.existsSync()) {
            downloadDir.createSync(recursive: true);
          }
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${downloadDir.path}/Clasificacion_Campus_$timestamp.xlsx';
          final file = File(filePath);
          await file.writeAsBytes(fileBytes);
          return 'Excel guardado con éxito en Descargas';
        } catch (e) {
          // Fallback if writing to public Download fails (e.g. older Android versions)
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/Clasificacion_Campus.xlsx';
          final file = File(filePath);
          await file.writeAsBytes(fileBytes);
          await Share.shareXFiles([XFile(filePath)], text: 'Clasificación del Campus');
          return 'Excel exportado. Elige dónde guardarlo.';
        }
      } else if (Platform.isIOS) {
        try {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/Clasificacion_Campus.xlsx';
          final file = File(filePath);
          await file.writeAsBytes(fileBytes);
          
          await Share.shareXFiles(
            [XFile(filePath)], 
            text: 'Clasificación del Campus',
          );
          return 'Abriendo menú para guardar el Excel...';
        } catch (e) {
          return 'Error al compartir: $e';
        }
      } else {
        // Windows/Desktop fallback
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Clasificacion_Campus.xlsx');
        await file.writeAsBytes(fileBytes);
        return 'Excel guardado en: ${file.path}';
      }
    }
    return 'Error: No se pudo generar el archivo.';
  }
}
