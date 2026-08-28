import 'package:flutter/material.dart';

abstract final class VideoFormStyle {
  static const background = Color(0xFF02050C);
  static const border = Color(0xFF474253);
  static const secondary = Color(0xFFB4B1BD);
  static const muted = Color(0xFF85818F);
  static const accent = Color(0xFFC68AED);
  static const pink = Color(0xFFEC5FB6);
  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E1020), Color(0xFF070C17)],
  );
  static const gradient = LinearGradient(
    colors: [Color(0xFFCF559F), Color(0xFF8643B5), Color(0xFF294CD7)],
  );

  static TextStyle serif(double size, {Color color = Colors.white}) =>
      TextStyle(
        fontFamily: 'Times New Roman',
        fontFamilyFallback: const ['Times', 'serif'],
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.15,
        color: color,
      );
}
