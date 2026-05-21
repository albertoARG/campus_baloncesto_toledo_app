import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5E35B1), // Purple from Logo
        primary: const Color(0xFF5E35B1),
        secondary: const Color(0xFFFF9800), // Orange from Logo
        surface: Colors.white,
        background: const Color(0xFFF5F5F5),
      ),
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5E35B1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
