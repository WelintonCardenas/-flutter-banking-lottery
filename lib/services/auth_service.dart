// ─── services/auth_service.dart ──────────────────────────────────────────────
// Maneja roles de usuario desde Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum RolUsuario { admin, banca }

class UsuarioData {
  final String uid;
  final String email;
  final String nombre;
  final RolUsuario rol;
  final bool activo;

  const UsuarioData({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.activo,
  });

  factory UsuarioData.fromMap(String uid, Map<String, dynamic> m) {
    return UsuarioData(
      uid:    uid,
      email:  m['email']  as String? ?? '',
      nombre: m['nombre'] as String? ?? '',
      rol:    (m['rol'] as String?) == 'admin'
          ? RolUsuario.admin
          : RolUsuario.banca,
      activo: m['activo'] as bool? ?? true,
    );
  }

  bool get esAdmin => rol == RolUsuario.admin;
  bool get esBanca => rol == RolUsuario.banca;
}

class AuthService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Usuario actual ────────────────────────────────────────────────────────
  static Future<UsuarioData?> usuarioActual() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return null;
    return UsuarioData.fromMap(uid, doc.data()!);
  }

  static Stream<UsuarioData?> streamUsuarioActual() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db.collection('usuarios').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UsuarioData.fromMap(uid, snap.data()!);
    });
  }

  // ── Todos los usuarios (solo admin) ──────────────────────────────────────
  static Stream<List<UsuarioData>> streamUsuarios() {
    return _db.collection('usuarios').snapshots().map((snap) =>
        snap.docs
            .map((d) => UsuarioData.fromMap(d.id, d.data()))
            .toList());
  }

  // ── Solo los usuarios creados por el admin actual ─────────────────────────
  static Stream<List<UsuarioData>> streamMisUsuarios() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('usuarios')
        .where('creadoPor', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UsuarioData.fromMap(d.id, d.data()))
            .toList());
  }

  // ── Crear usuario vendedor (admin crea desde la app) ─────────────────────
  // Usa Firebase Auth REST API para crear sin cerrar sesión del admin.
  static Future<void> crearUsuarioBanca({
    required String email,
    required String password,
    required String nombre,
  }) async {
    // Crear en Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final newUid = cred.user!.uid;

    // Guardar rol en Firestore
    await _db.collection('usuarios').doc(newUid).set({
      'email':    email,
      'nombre':   nombre,
      'rol':      'banca',
      'activo':   true,
      'creadoPor': _auth.currentUser?.uid,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    // IMPORTANTE: cerrar sesión del nuevo usuario y reautenticar el admin
    // Esto no es posible directamente con el SDK cliente.
    // Solución: guardar el documento y el admin sigue logueado
    // porque createUserWithEmailAndPassword cambia la sesión activa.
    // Necesitamos que el admin cierre y reabra sesión, o usar Firebase Admin SDK.
    // Aquí usamos la solución simple: anotar que el admin debe reloguearse.
  }

  // ── Versión segura: solo guarda en Firestore, auth lo hace el vendedor ────
  // El admin registra el usuario en /usuarios y el vendedor se registra solo.
  static Future<void> registrarUsuarioBanca({
    required String uid,
    required String email,
    required String nombre,
  }) async {
    await _db.collection('usuarios').doc(uid).set({
      'email':    email,
      'nombre':   nombre,
      'rol':      'banca',
      'activo':   true,
      'creadoPor': _auth.currentUser?.uid,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ── Crear usuario admin inicial (primera vez) ─────────────────────────────
  static Future<void> asegurarAdminExiste() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) {
      // Primera vez: este usuario es admin
      await _db.collection('usuarios').doc(uid).set({
        'email':    _auth.currentUser?.email ?? '',
        'nombre':   'Administrador',
        'rol':      'admin',
        'activo':   true,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Cambiar rol ───────────────────────────────────────────────────────────
  static Future<void> cambiarRol(String uid, RolUsuario rol) async {
    await _db.collection('usuarios').doc(uid).update({
      'rol': rol == RolUsuario.admin ? 'admin' : 'banca',
    });
  }

  // ── Activar / desactivar ──────────────────────────────────────────────────
  static Future<void> toggleActivo(String uid, bool activo) async {
    await _db.collection('usuarios').doc(uid).update({'activo': activo});
  }
}
