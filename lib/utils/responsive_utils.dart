// ─── utils/responsive_utils.dart ─────────────────────────────────────────────
//
// Uso:
//   final r = R(context);
//   r.sp(14)      → tamaño de texto escalado
//   r.w(16)       → padding/margin relativo al ancho
//   r.h(12)       → padding/margin relativo al alto
//   r.wp(0.5)     → 50% del ancho de pantalla
//   r.hp(0.1)     → 10% del alto de pantalla
//   r.icon(20)    → tamaño de ícono escalado
//   r.radius(12)  → border radius escalado
//   r.isSmall     → true si alto < 700
//   r.isNarrow    → true si ancho < 360

import 'package:flutter/material.dart';

class R {
  final double _w;
  final double _h;
  final double _scale;

  R(BuildContext context)
      : _w     = MediaQuery.of(context).size.width,
        _h     = MediaQuery.of(context).size.height,
        // Base de referencia: 390×844 (iPhone 14 / Pixel 7)
        // S21 Ultra: 480dp lógicos de ancho → escala ~1.23
        _scale = MediaQuery.of(context).size.width / 390;

  // ── Texto ─────────────────────────────────────────────────────────────────
  /// Tamaño de texto escalado, con límite inferior y superior para evitar
  /// textos demasiado pequeños o gigantes.
  double sp(double size) => (size * _scale.clamp(0.85, 1.25)).roundToDouble();

  // ── Espaciado relativo al ancho ───────────────────────────────────────────
  double w(double size) => (size * _scale.clamp(0.85, 1.3)).roundToDouble();

  // ── Espaciado relativo al alto ────────────────────────────────────────────
  double h(double size) => (size * (_h / 844).clamp(0.85, 1.3)).roundToDouble();

  // ── Porcentajes ───────────────────────────────────────────────────────────
  double wp(double pct) => _w * pct;
  double hp(double pct) => _h * pct;

  // ── Íconos ────────────────────────────────────────────────────────────────
  double icon(double size) => (size * _scale.clamp(0.9, 1.2)).roundToDouble();

  // ── Border radius ─────────────────────────────────────────────────────────
  double radius(double r) => (r * _scale.clamp(0.9, 1.15)).roundToDouble();

  // ── Breakpoints ───────────────────────────────────────────────────────────
  bool get isSmall  => _h < 700;
  bool get isNarrow => _w < 360;
  bool get isLarge  => _w >= 420;   // S21 Ultra y similares

  // ── Helpers de EdgeInsets ─────────────────────────────────────────────────
  EdgeInsets padAll(double v)   => EdgeInsets.all(w(v));
  EdgeInsets padH(double v)     => EdgeInsets.symmetric(horizontal: w(v));
  EdgeInsets padV(double v)     => EdgeInsets.symmetric(vertical: h(v));
  EdgeInsets padHV(double h, double v) =>
      EdgeInsets.symmetric(horizontal: w(h), vertical: this.h(v));

  // ── SizedBox helpers ──────────────────────────────────────────────────────
  SizedBox gapW(double v) => SizedBox(width: w(v));
  SizedBox gapH(double v) => SizedBox(height: h(v));
}

// ── Extensión en BuildContext para acceso rápido ──────────────────────────────
extension RContext on BuildContext {
  R get r => R(this);
}
