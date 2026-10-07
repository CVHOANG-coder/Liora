import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

abstract final class VideoFormStyle {
  static const background = AppColors.background;
  static const border = AppColors.divider;
  static const secondary = AppColors.textSecondary;
  static const muted = Color(0xFFAFA2BA);
  static const accent = AppColors.primary;
  static const pink = AppColors.primary;
  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surface, AppColors.surface],
  );
  static const gradient = LinearGradient(
    colors: [AppColors.primary, AppColors.primary],
  );
  static const artworkFilter = ColorFilter.matrix([
    0.54803,
    0.22886,
    0.02310,
    0,
    0,
    0.06803,
    0.70886,
    0.02310,
    0,
    0,
    0.06803,
    0.22886,
    0.50310,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  static TextStyle heading(
    double size, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Nunito',
    fontFamilyFallback: const ['Nunito Sans'],
    fontSize: size,
    fontWeight: fontWeight,
    height: 1.15,
    color: color,
  );
}
