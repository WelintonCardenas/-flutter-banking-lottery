// ─── services/ticket_service.dart ────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/jugada.dart';

class TicketService {
  static final _db = FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Genera un ID único basado en la fecha + sufijo de 4 dígitos
  static String generarTicketId() {
    final ahora  = DateTime.now();
    final fecha  = '${ahora.year}'
        '${ahora.month.toString().padLeft(2, '0')}'
        '${ahora.day.toString().padLeft(2, '0')}';
    final sufijo = (ahora.millisecondsSinceEpoch % 9000 + 1000).toString();
    return 'T-$fecha-$sufijo';
  }

  /// Guarda un nuevo ticket en Firestore
  static Future<String> guardar(List<Jugada> jugadas) async {
    final ticketId = generarTicketId();
    final total    = jugadas.fold<double>(0, (s, j) => s + j.monto);

    await _db.collection('tickets').doc(ticketId).set({
      'ticketId': ticketId,
      'uid':      _uid,
      'fecha':    FieldValue.serverTimestamp(),
      'total':    total,
      'jugadas':  jugadas.map((j) => j.toMap()).toList(),
      'estado':   'activo',
    });

    return ticketId;
  }

  /// Actualiza jugadas y total de un ticket existente
  static Future<void> actualizar(String docId, List<Jugada> jugadas) async {
    final nuevoTotal = jugadas.fold<double>(0, (s, j) => s + j.monto);
    await _db.collection('tickets').doc(docId).update({
      'jugadas': jugadas.map((j) => j.toMap()).toList(),
      'total':   nuevoTotal,
    });
  }

  /// Busca un ticket por los últimos 4 dígitos del sufijo del día actual.
  /// El ticket impreso muestra "Ticket #XXXXXX" — los últimos 4 dígitos
  /// son el sufijo exacto del docId (T-YYYYMMDD-XXXX).
  static Future<Map<String, dynamic>?> buscarPorSufijo(String sufijo) async {
    final hoy   = DateTime.now();
    final fecha = '${hoy.year}'
        '${hoy.month.toString().padLeft(2, '0')}'
        '${hoy.day.toString().padLeft(2, '0')}';

    // Reconstrucción directa: T-20260510-4891
    final docId = 'T-$fecha-$sufijo';
    final doc   = await _db.collection('tickets').doc(docId).get();
    if (doc.exists) return {'id': docId, ...doc.data()!};

    return null;
  }
}
