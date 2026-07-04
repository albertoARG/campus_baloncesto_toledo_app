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

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime? a, DateTime b) {
    return a != null && a.year == b.year && a.month == b.month && a.day == b.day;
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
      final fechaTexto = fecha != null
          ? ' (${fecha.day}/${fecha.month})'
          : '';
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
      final repository = ref.read(competitionsRepositoryProvider);
      // The coachId variable is used, so it's not removed.
      final coachId = Supabase.instance.client.auth.currentUser?.id;

      // Enviar a supabase, nota: el ID lo genera la bbdd pero el modelo pide String.
      // Arreglado quitando id en toJson() si está vacío.
      final int score = int.parse(_scoreController.text);
      final int playerCount = _selectedPlayers.length;
      for (final player in _selectedPlayers) {
        await repository.addScore(
          StationScoreModel(
            id: '',
            userId: player.id,
            coachId: coachId,
            stationId: _selectedStation!.id,
            stationDayId: _selectedDay!.id,
            score: score,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(playerCount == 1
                ? 'Puntuación guardada correctamente'
                : 'Puntuación guardada para $playerCount jugadores'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                        (d) =>
                            DropdownMenuItem(value: d, child: Text(d.nombre)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedDay = val),
                  validator: (val) => val == null ? 'Selecciona un día' : null,
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
                        (s) =>
                            DropdownMenuItem(value: s, child: Text(s.nombre)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStation = val),
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
                  decoration: const InputDecoration(labelText: 'Grupo (Opcional)'),
                  value: _selectedGroupId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos los jugadores')),
                    ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nombre))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGroupId = val;
                      _selectedPlayers.clear(); // Reset players when group changes
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
                        decoration: const InputDecoration(labelText: 'Jugador'),
                        value: null,
                        items: const [],
                        onChanged: null,
                        hint: const Text('No hay jugadores en este grupo'),
                     );
                  }

                  // Ensure selected players are still in the list (e.g. group changed)
                  if (_selectedPlayers.any((sel) => !players.any((p) => p.id == sel.id))) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _selectedPlayers
                              .removeWhere((sel) => !players.any((p) => p.id == sel.id)));
                        }
                     });
                  }

                  final available = players
                      .where((p) => !_selectedPlayers.any((sel) => sel.id == p.id))
                      .toList();
                  final limitReached = _selectedPlayers.length >= _maxPlayers;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<UserModel>(
                        key: ValueKey(_selectedPlayers.length),
                        decoration: InputDecoration(
                          labelText: _selectedPlayers.isEmpty
                              ? 'Jugador'
                              : 'Añadir otro jugador (${_selectedPlayers.length}/$_maxPlayers)',
                        ),
                        value: null,
                        hint: Text(
                          limitReached
                              ? 'Máximo $_maxPlayers jugadores'
                              : 'Selecciona un jugador',
                        ),
                        items: available
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p.nombre} ${p.apellidos}'),
                              ),
                            )
                            .toList(),
                        onChanged: limitReached
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedPlayers.add(val));
                                }
                              },
                        validator: (_) => _selectedPlayers.isEmpty
                            ? 'Selecciona al menos un jugador'
                            : null,
                      ),
                      if (_selectedPlayers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedPlayers
                              .map(
                                (p) => Chip(
                                  label: Text('${p.nombre} ${p.apellidos}'),
                                  onDeleted: () => setState(
                                      () => _selectedPlayers.remove(p)),
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
              TextFormField(
                controller: _scoreController,
                decoration: const InputDecoration(
                  labelText: 'Puntuación Obtenida',
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'Introduce la puntuación';
                  if (int.tryParse(val) == null)
                    return 'Debe ser un número válido';
                  return null;
                },
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
    );
  }
}
