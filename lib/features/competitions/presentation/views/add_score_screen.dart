import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/competitions_providers.dart';
import '../../data/models/station_score_model.dart';
import '../../../../core/models/user_model.dart';
import '../../data/models/station_day_model.dart';
import '../../data/models/station_model.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../../../core/sync/sync_status_banner.dart';
import '../../../../core/widgets/quick_number_field.dart';
import '../../../../core/widgets/dual_timer.dart';

class AddScoreScreen extends ConsumerStatefulWidget {
  const AddScoreScreen({super.key});

  @override
  ConsumerState<AddScoreScreen> createState() => _AddScoreScreenState();
}

class _AddScoreScreenState extends ConsumerState<AddScoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController();

  static const int _maxPlayers = 5;

  StationDayModel? _selectedDay;
  StationModel? _selectedStation;
  String? _selectedGroupId;
  final List<UserModel> _selectedPlayers = [];
  bool _isLoading = false;
  bool _dayAutoSelected = false;

  // Referencias al campo de búsqueda del autocompletado (para limpiarlo tras
  // seleccionar). Los gestiona el propio Autocomplete, no hay que liberarlos.
  TextEditingController? _playerSearchController;
  FocusNode? _playerSearchFocus;

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime? a, DateTime b) {
    return a != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  Future<void> _submitScore() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDay == null ||
        _selectedStation == null ||
        _selectedPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    // Si el día seleccionado no corresponde a la fecha de hoy, pedir confirmación.
    if (!_isSameDate(_selectedDay!.fecha, DateTime.now())) {
      final fecha = _selectedDay!.fecha;
      final fechaTexto = fecha != null ? ' (${fecha.day}/${fecha.month})' : '';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Guardar en otro día?'),
          content: Text(
            'Estás registrando esta puntuación en "${_selectedDay!.nombre}"$fechaTexto, '
            'que no corresponde al día de hoy.\n\n'
            '¿Seguro que quieres guardarla en ese día?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, guardar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final syncQueue = ref.read(syncQueueProvider);
      final coachId = Supabase.instance.client.auth.currentUser?.id;

      final int score = int.parse(_scoreController.text);
      final int playerCount = _selectedPlayers.length;
      int queued = 0;
      for (final player in _selectedPlayers) {
        // Guardar online; si no hay conexión, queda en cola y se subirá solo.
        final payload = StationScoreModel(
          id: '',
          userId: player.id,
          coachId: coachId,
          stationId: _selectedStation!.id,
          stationDayId: _selectedDay!.id,
          score: score,
          createdAt: DateTime.now(),
        ).toJson();
        payload['created_at'] = DateTime.now().toIso8601String();

        final uploaded = await syncQueue.insertOrQueue(
          'station_scores',
          payload,
          label:
              '${player.nombre} ${player.apellidos} · ${_selectedStation!.nombre} · $score pts',
        );
        if (!uploaded) queued++;
      }

      if (mounted) {
        final message = queued == 0
            ? (playerCount == 1
                  ? 'Puntuación guardada correctamente'
                  : 'Puntuación guardada para $playerCount jugadores')
            : 'Sin conexión: guardado en el dispositivo. Se subirá automáticamente al recuperar la conexión.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: queued == 0 ? null : Colors.orange.shade800,
            duration: Duration(seconds: queued == 0 ? 2 : 4),
          ),
        );
        _scoreController.clear();
        _selectedPlayers.clear();
        setState(() {});

        // Refresh standings
        ref.invalidate(globalStandingsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(stationDaysProvider);
    final stationsAsync = ref.watch(stationsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final playersAsync = _selectedGroupId == null
        ? ref.watch(playersProvider)
        : ref.watch(groupMembersProvider(_selectedGroupId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Puntuación'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Cronómetro (cuenta adelante y atrás), plegable.
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Cronómetro'),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        children: const [DualTimer(compact: true)],
                      ),
                    ),

                    // Select Day
                    daysAsync.when(
                      data: (days) {
                        // Preseleccionar automáticamente el día cuya fecha es hoy.
                        if (!_dayAutoSelected && _selectedDay == null) {
                          _dayAutoSelected = true;
                          final today = DateTime.now();
                          for (final d in days) {
                            if (_isSameDate(d.fecha, today)) {
                              _selectedDay = d;
                              break;
                            }
                          }
                        }
                        return DropdownButtonFormField<StationDayModel>(
                          decoration: const InputDecoration(
                            labelText: 'Día de Competición',
                          ),
                          value: _selectedDay,
                          items: days
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d.nombre),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedDay = val),
                          validator: (val) =>
                              val == null ? 'Selecciona un día' : null,
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 16),

                    // Select Station
                    stationsAsync.when(
                      data: (stations) => DropdownButtonFormField<StationModel>(
                        decoration: const InputDecoration(
                          labelText: 'Estación / Prueba',
                        ),
                        value: _selectedStation,
                        items: stations
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.nombre),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedStation = val),
                        validator: (val) =>
                            val == null ? 'Selecciona una prueba' : null,
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 16),

                    // Select Group
                    groupsAsync.when(
                      data: (groups) => DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          labelText: 'Grupo (Opcional)',
                        ),
                        value: _selectedGroupId,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos los jugadores'),
                          ),
                          ...groups.map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.nombre),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedGroupId = val;
                            _selectedPlayers
                                .clear(); // Reset players when group changes
                          });
                        },
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error al cargar grupos: $e'),
                    ),
                    const SizedBox(height: 16),

                    // Select Players (hasta 5, misma puntuación para todos)
                    playersAsync.when(
                      data: (players) {
                        // If a group is selected but somehow no players are in it, handle gracefully
                        if (players.isEmpty) {
                          return DropdownButtonFormField<UserModel>(
                            decoration: const InputDecoration(
                              labelText: 'Jugador',
                            ),
                            value: null,
                            items: const [],
                            onChanged: null,
                            hint: const Text('No hay jugadores en este grupo'),
                          );
                        }

                        // Ensure selected players are still in the list (e.g. group changed)
                        if (_selectedPlayers.any(
                          (sel) => !players.any((p) => p.id == sel.id),
                        )) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(
                                () => _selectedPlayers.removeWhere(
                                  (sel) => !players.any((p) => p.id == sel.id),
                                ),
                              );
                            }
                          });
                        }

                        // Jugadores disponibles, en orden alfabético.
                        final available =
                            players
                                .where(
                                  (p) => !_selectedPlayers.any(
                                    (sel) => sel.id == p.id,
                                  ),
                                )
                                .toList()
                              ..sort(
                                (a, b) => '${a.nombre} ${a.apellidos}'
                                    .toLowerCase()
                                    .compareTo(
                                      '${b.nombre} ${b.apellidos}'
                                          .toLowerCase(),
                                    ),
                              );
                        final limitReached =
                            _selectedPlayers.length >= _maxPlayers;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (limitReached)
                              InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Jugadores',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text('Máximo $_maxPlayers jugadores'),
                              )
                            else
                              // Búsqueda por nombre (autocompletado alfabético).
                              Autocomplete<UserModel>(
                                displayStringForOption: (u) =>
                                    '${u.nombre} ${u.apellidos}',
                                optionsBuilder: (value) {
                                  final q = value.text.trim().toLowerCase();
                                  if (q.isEmpty) return available;
                                  return available.where(
                                    (p) => '${p.nombre} ${p.apellidos}'
                                        .toLowerCase()
                                        .contains(q),
                                  );
                                },
                                onSelected: (u) {
                                  setState(() => _selectedPlayers.add(u));
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    _playerSearchController?.clear();
                                    _playerSearchFocus?.unfocus();
                                  });
                                },
                                fieldViewBuilder:
                                    (context, controller, focusNode, _) {
                                      _playerSearchController = controller;
                                      _playerSearchFocus = focusNode;
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: _selectedPlayers.isEmpty
                                              ? 'Buscar jugador'
                                              : 'Añadir otro jugador (${_selectedPlayers.length}/$_maxPlayers)',
                                          hintText: 'Escribe un nombre…',
                                          prefixIcon: const Icon(Icons.search),
                                          border: const OutlineInputBorder(),
                                        ),
                                      );
                                    },
                              ),
                            if (_selectedPlayers.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _selectedPlayers
                                    .map(
                                      (p) => Chip(
                                        label: Text(
                                          '${p.nombre} ${p.apellidos}',
                                        ),
                                        onDeleted: () => setState(
                                          () => _selectedPlayers.remove(p),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (_selectedPlayers.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Se guardará la misma puntuación para los ${_selectedPlayers.length} jugadores.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 16),

                    // Input Score
                    QuickNumberField(
                      controller: _scoreController,
                      label: 'Puntuación obtenida',
                      quickAdds: const [1, 3, 5],
                    ),
                    const SizedBox(height: 32),

                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitScore,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Guardar Puntuación',
                              style: TextStyle(fontSize: 16),
                            ),
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
}
