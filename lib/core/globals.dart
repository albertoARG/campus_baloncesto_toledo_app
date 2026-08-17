import 'package:flutter/material.dart';

/// Clave global del ScaffoldMessenger, para poder mostrar SnackBars desde
/// servicios que no tienen contexto (p. ej. la cola de sincronización).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Número de pantallas abiertas que piden usar TODO el ancho (sin el límite de
/// 720). La pizarra la usa para abrirse a pantalla completa tipo «Paint».
final ValueNotifier<int> fullBleedRoutes = ValueNotifier<int>(0);
