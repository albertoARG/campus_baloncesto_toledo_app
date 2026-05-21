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

  StationDayModel? _selectedDay;
  StationModel? _selectedStation;
  String? _selectedGroupId;
  UserModel? _selectedPlayer;
  bool _isLoading = false;

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _submitScore() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDay == null ||
        _selectedStation == null ||
        _selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(competitionsRepositoryProvider);
      // The coachId variable is used, so it's not removed.
      final coachId = Supabase.instance.client.auth.currentUser?.id;

      // Enviar a supabase, nota: el ID lo genera la bbdd pero el modelo pide String.
      // Arreglado quitando id en toJson() si está vacío.
      await repository.addScore(
        StationScoreModel(
          id: '',
          userId: _selectedPlayer!.id,
          coachId: coachId,
          stationId: _selectedStation!.id,
          stationDayId: _selectedDay!.id,
          score: int.parse(_scoreController.text),
          createdAt: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Puntuación guardada correctamente')),
        );
        _scoreController.clear();
        _selectedPlayer = null;
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
                data: (days) => DropdownButtonFormField<StationDayModel>(
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
                ),
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
                      _selectedPlayer = null; // Reset player when group changes
                    });
                  },
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Error al cargar grupos: $e'),
              ),
              const SizedBox(height: 16),

              // Select Player
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
                  
                  // Ensure current _selectedPlayer is still in the list, otherwise null it
                  if (_selectedPlayer != null && !players.any((p) => p.id == _selectedPlayer!.id)) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedPlayer = null);
                     });
                  }

                  return DropdownButtonFormField<UserModel>(
                    decoration: const InputDecoration(labelText: 'Jugador'),
                    value: _selectedPlayer,
                    items: players
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.nombre} ${p.apellidos}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedPlayer = val),
                    validator: (val) =>
                        val == null ? 'Selecciona un jugador' : null,
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
