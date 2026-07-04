import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/siesta_providers.dart';

class CreateSiestaCompetitionScreen extends ConsumerStatefulWidget {
  const CreateSiestaCompetitionScreen({super.key});

  @override
  ConsumerState<CreateSiestaCompetitionScreen> createState() => _CreateSiestaCompetitionScreenState();
}

class _CreateSiestaCompetitionScreenState extends ConsumerState<CreateSiestaCompetitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  
  String _selectedJuego = 'Ping Pong';
  String _selectedFormato = 'grupos_playoffs';
  bool _isLoading = false;

  final List<String> _juegos = ['Ping Pong', 'Billar', 'Bolos', 'Tiro a canasta', 'Futbolín', 'Mus', 'Otro'];
  final Map<String, String> _formatos = {
    'grupos_playoffs': 'Grupos + Playoffs',
    'liga': 'Liga (Todos contra todos)',
    'individual': 'Clasificación Individual Diaria',
    'tiros_libres_seguidos': 'Tiros Libres Seguidos',
  };

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _crearCompeticion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(siestaRepositoryProvider);
      await repository.createCompetition(
        _nombreController.text.trim(),
        _selectedJuego,
        _selectedFormato,
      );
      
      ref.invalidate(siestaCompetitionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Competición creada con éxito')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Competición Siesta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la Competición',
                  hintText: 'Ej. Gran Torneo de Ping Pong',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedJuego,
                decoration: InputDecoration(
                  labelText: 'Juego',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _juegos.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedJuego = val);
                },
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedFormato,
                decoration: InputDecoration(
                  labelText: 'Formato',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _formatos.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFormato = val);
                },
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading ? null : _crearCompeticion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text('CREAR COMPETICIÓN', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
