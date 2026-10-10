// ─── services/horario_service.dart ───────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Modelo ───────────────────────────────────────────────────────────────────

class HorarioLoteria {
  final String loteria;
  final int abreHora;
  final int abreMinuto;
  final int cierraHora;
  final int cierraMinuto;
  final bool activo;
  final List<int> diasSemana;

  const HorarioLoteria({
    required this.loteria,
    required this.abreHora,
    required this.abreMinuto,
    required this.cierraHora,
    required this.cierraMinuto,
    this.activo = true,
    this.diasSemana = const [1, 2, 3, 4, 5, 6, 7],
  });

  factory HorarioLoteria.fromMap(String nombre, Map<String, dynamic> m) {
    final abre   = _parsearHora(m['abre']   as String? ?? '09:00');
    final cierra = _parsearHora(m['cierra'] as String? ?? '12:30');
    final dias   = (m['diasSemana'] as List?)?.map((e) => e as int).toList()
        ?? [1, 2, 3, 4, 5, 6, 7];
    return HorarioLoteria(
      loteria:      nombre,
      abreHora:     abre[0],
      abreMinuto:   abre[1],
      cierraHora:   cierra[0],
      cierraMinuto: cierra[1],
      activo:       m['activo'] as bool? ?? true,
      diasSemana:   dias,
    );
  }

  static List<int> _parsearHora(String s) {
    final p = s.split(':');
    return [int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0];
  }

  bool estaAbierta([DateTime? ahora]) {
    final now = ahora ?? DateTime.now();
    if (!activo) return false;
    if (!diasSemana.contains(now.weekday)) return false;
    final min       = now.hour * 60 + now.minute;
    final minAbre   = abreHora * 60 + abreMinuto;
    final minCierra = cierraHora * 60 + cierraMinuto;
    return min >= minAbre && min < minCierra;
  }

  int minutosParaCerrar([DateTime? ahora]) {
    final now = ahora ?? DateTime.now();
    final diff = (cierraHora * 60 + cierraMinuto) - (now.hour * 60 + now.minute);
    return diff > 0 ? diff : 0;
  }

  String proximaApertura([DateTime? ahora]) {
    final now  = ahora ?? DateTime.now();
    final hoy  = now.hour * 60 + now.minute;
    final abre = abreHora * 60 + abreMinuto;
    if (hoy < abre) return 'Abre a las ${_fmt(abreHora)}:${_fmt(abreMinuto)}';
    return 'Abre mañana a las ${_fmt(abreHora)}:${_fmt(abreMinuto)}';
  }

  String get horarioTexto =>
      '${_fmt(abreHora)}:${_fmt(abreMinuto)} – ${_fmt(cierraHora)}:${_fmt(cierraMinuto)}';

  static String _fmt(int n) => n.toString().padLeft(2, '0');

  HorarioLoteria copyWith({
    String? loteria,
    int? abreHora, int? abreMinuto,
    int? cierraHora, int? cierraMinuto,
    bool? activo,
    List<int>? diasSemana,
  }) => HorarioLoteria(
    loteria:      loteria      ?? this.loteria,
    abreHora:     abreHora     ?? this.abreHora,
    abreMinuto:   abreMinuto   ?? this.abreMinuto,
    cierraHora:   cierraHora   ?? this.cierraHora,
    cierraMinuto: cierraMinuto ?? this.cierraMinuto,
    activo:       activo       ?? this.activo,
    diasSemana:   diasSemana   ?? this.diasSemana,
  );
}

// ─── Servicio ─────────────────────────────────────────────────────────────────

class HorarioService {
  static final _db = FirebaseFirestore.instance;

  /// Stream en tiempo real — solo lee lo que está en Firebase
  static Stream<Map<String, HorarioLoteria>> streamHorarios() {
    return _db.collection('horarios').snapshots().map((snap) {
      final mapa = <String, HorarioLoteria>{};
      for (final doc in snap.docs) {
        mapa[doc.id] = HorarioLoteria.fromMap(doc.id, doc.data());
      }
      return mapa;
    });
  }

  /// Carga única — solo lee lo que está en Firebase
  static Future<Map<String, HorarioLoteria>> cargarHorarios() async {
    final snap = await _db.collection('horarios').get();
    final mapa = <String, HorarioLoteria>{};
    for (final doc in snap.docs) {
      mapa[doc.id] = HorarioLoteria.fromMap(doc.id, doc.data());
    }
    return mapa;
  }

  /// Guardar / actualizar en Firebase
  static Future<void> guardarHorario(HorarioLoteria h) async {
    await _db.collection('horarios').doc(h.loteria).set({
      'loteria':    h.loteria,
      'abre':       '${HorarioLoteria._fmt(h.abreHora)}:${HorarioLoteria._fmt(h.abreMinuto)}',
      'cierra':     '${HorarioLoteria._fmt(h.cierraHora)}:${HorarioLoteria._fmt(h.cierraMinuto)}',
      'activo':     h.activo,
      'diasSemana': h.diasSemana,
    });
  }

  /// Eliminar lotería de Firebase
  static Future<void> eliminarHorario(String loteria) async {
    await _db.collection('horarios').doc(loteria).delete();
  }
}
