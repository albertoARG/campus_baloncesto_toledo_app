import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/dual_timer.dart';

/// Cronómetro a pantalla completa (cuenta adelante y atrás) para cronometrar
/// pruebas de estaciones.
class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronómetro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: DualTimer(),
        ),
      ),
    );
  }
}
