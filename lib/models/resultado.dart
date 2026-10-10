// ─── models/resultado.dart ────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

class Resultado {
  final String loteria;
  final String loteriaDisplay;
  final DateTime fecha;
  final String primero;
  final String? segundo;
  final String? tercero;

  const Resultado({
    required this.loteria,
    required this.loteriaDisplay,
    required this.fecha,
    required this.primero,
    this.segundo,
    this.tercero,
  });

  factory Resultado.fromMap(Map<String, dynamic> m) {
    final raw = (m['loteria'] as String? ?? '').trim();
    return Resultado(
      loteria:        raw.toLowerCase(),
      loteriaDisplay: raw,
      fecha: m['fecha'] != null
          ? (m['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      primero: (m['primero'] as String? ?? '').trim(),
      segundo: (m['segundo'] as String?)?.trim(),
      tercero: (m['tercero'] as String?)?.trim(),
    );
  }

  Set<String> get numeros => {
        if (primero.isNotEmpty) primero,
        if (segundo != null && segundo!.isNotEmpty) segundo!,
        if (tercero != null && tercero!.isNotEmpty) tercero!,
      };
}

// ── Lógica de premios ─────────────────────────────────────────────────────────

String normLoteria(String s) => s.trim().toLowerCase();

double calcularMultiplicador(
  Map<String, dynamic> jugada,
  List<Resultado> resultados,
) {
  final comb    = (jugada['comb']    as String? ?? '').trim();
  final loteria = normLoteria(jugada['loteria'] as String? ?? '');
  final numero  = (jugada['numero']  as String? ?? '').trim();

  final res = resultados.where((r) => r.loteria == loteria).toList();
  if (res.isEmpty) return 0;

  if (comb.contains('Quiniela')) {
    for (final r in res) {
      if (r.primero == numero) return 80;
      if (r.segundo == numero) return 8;
      if (r.tercero == numero) return 4;
    }
    return 0;
  }

  if (comb.contains('Pale') && numero.length == 4) {
    final n1 = numero.substring(0, 2);
    final n2 = numero.substring(2, 4);
    for (final r in res) {
      if (r.numeros.contains(n1) && r.numeros.contains(n2)) return 400;
    }
    return 0;
  }

  if (comb.contains('Tripleta') && numero.length == 6) {
    final n1 = numero.substring(0, 2);
    final n2 = numero.substring(2, 4);
    final n3 = numero.substring(4, 6);
    for (final r in res) {
      if (r.numeros.contains(n1) &&
          r.numeros.contains(n2) &&
          r.numeros.contains(n3)) return 1500;
    }
    return 0;
  }

  return 0;
}

double calcularPremioTicket(
  List jugadas,
  List<Resultado> resultados,
) =>
    jugadas.fold(0.0, (total, j) {
      final mult = calcularMultiplicador(
          Map<String, dynamic>.from(j as Map), resultados);
      return total + (j['monto'] as num).toDouble() * mult;
    });
