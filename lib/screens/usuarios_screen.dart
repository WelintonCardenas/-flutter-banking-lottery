// ─── screens/usuarios_screen.dart ────────────────────────────────────────────
// Solo visible para admin. Lista vendedores y permite crear nuevos.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class UsuariosScreen extends StatelessWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Usuarios / Vendedores',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined,
                color: Color(0xFF34D399), size: 22),
            onPressed: () => _mostrarCrearUsuario(context),
            tooltip: 'Nuevo vendedor',
          ),
        ],
      ),
      body: StreamBuilder<List<UsuarioData>>(
        stream: AuthService.streamMisUsuarios(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4F46E5)));
          }
          final usuarios = snap.data ?? [];
          if (usuarios.isEmpty) {
            return const Center(
              child: Text('No hay usuarios registrados',
                  style: TextStyle(color: Color(0xFF374151))),
            );
          }

          // Admin primero, luego bancas
          final sorted = [...usuarios]
            ..sort((a, b) {
              if (a.esAdmin && !b.esAdmin) return -1;
              if (!a.esAdmin && b.esAdmin) return 1;
              return a.nombre.compareTo(b.nombre);
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _TarjetaUsuario(
              usuario: sorted[i],
              onCambiarRol: (u, rol) async {
                await AuthService.cambiarRol(u.uid, rol);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Rol actualizado a ${rol == RolUsuario.admin ? "Admin" : "Banca"}'),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              onToggleActivo: (u) async {
                await AuthService.toggleActivo(u.uid, !u.activo);
              },
            ),
          );
        },
      ),
    );
  }

  void _mostrarCrearUsuario(BuildContext context) {
    final emailCtrl  = TextEditingController();
    final nombreCtrl = TextEditingController();
    final passCtrl   = TextEditingController();
    bool creando     = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Ícono
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add_outlined,
                  color: Color(0xFF34D399), size: 24),
            ),
            const SizedBox(height: 12),
            const Text('Nuevo vendedor',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Se creará con rol "Banca" — solo puede vender tickets',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            const SizedBox(height: 20),

            _Campo(ctrl: nombreCtrl, label: 'Nombre'),
            const SizedBox(height: 12),
            _Campo(ctrl: emailCtrl,  label: 'Correo electrónico',
                tipo: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _Campo(ctrl: passCtrl,   label: 'Contraseña',
                oculto: true),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: creando
                    ? null
                    : () async {
                        final email  = emailCtrl.text.trim();
                        final nombre = nombreCtrl.text.trim();
                        final pass   = passCtrl.text.trim();

                        if (email.isEmpty || nombre.isEmpty || pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Completa todos los campos '
                                  '(contraseña mínimo 6 caracteres)'),
                              backgroundColor: Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        setModal(() => creando = true);

                        try {
                          // Guardar admin actual para reautenticar
                          final adminUser = FirebaseAuth.instance.currentUser;
                          final adminEmail = adminUser?.email ?? '';

                          // Crear cuenta del vendedor
                          final cred = await FirebaseAuth.instance
                              .createUserWithEmailAndPassword(
                                  email: email, password: pass);

                          // Guardar datos en Firestore
                          await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(cred.user!.uid)
                              .set({
                            'email':    email,
                            'nombre':   nombre,
                            'rol':      'banca',
                            'activo':   true,
                            'creadoPor': adminUser?.uid,
                            'creadoEn': FieldValue.serverTimestamp(),
                          });

                          // Cerrar sesión del vendedor recién creado
                          await FirebaseAuth.instance.signOut();

                          // Pedir al admin que vuelva a autenticarse
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            _pedirReautenticacion(context, adminEmail);
                          }
                        } catch (e) {
                          setModal(() => creando = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34D399),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: creando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Crear vendedor',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _pedirReautenticacion(BuildContext context, String adminEmail) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirma tu sesión',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Para continuar como administrador,\ningresa tu contraseña:',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _Campo(ctrl: passCtrl, label: 'Tu contraseña', oculto: true),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: adminEmail, password: passCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vendedor creado exitosamente'),
                      backgroundColor: Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contraseña incorrecta'),
                      backgroundColor: Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Confirmar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  final UsuarioData usuario;
  final void Function(UsuarioData, RolUsuario) onCambiarRol;
  final void Function(UsuarioData) onToggleActivo;

  const _TarjetaUsuario({
    required this.usuario,
    required this.onCambiarRol,
    required this.onToggleActivo,
  });

  @override
  Widget build(BuildContext context) {
    final esAdmin = usuario.esAdmin;
    final activo  = usuario.activo;
    final color   = esAdmin
        ? const Color(0xFF4F46E5)
        : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo
              ? color.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.15),
          child: Text(
            usuario.nombre.isNotEmpty
                ? usuario.nombre[0].toUpperCase()
                : '?',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(usuario.nombre,
                      style: TextStyle(
                          color: activo
                              ? Colors.white
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const SizedBox(width: 6),
                _Badge(
                  text: esAdmin ? 'ADMIN' : 'BANCA',
                  color: color,
                ),
                if (!activo) ...[
                  const SizedBox(width: 4),
                  const _Badge(
                      text: 'INACTIVO',
                      color: Color(0xFF6B7280)),
                ],
              ]),
              Text(usuario.email,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 11)),
            ],
          ),
        ),

        // Acciones
        PopupMenuButton<String>(
          color: const Color(0xFF1A1A2E),
          icon: const Icon(Icons.more_vert,
              color: Color(0xFF6B7280), size: 20),
          onSelected: (v) {
            if (v == 'admin') {
              onCambiarRol(usuario, RolUsuario.admin);
            } else if (v == 'banca') {
              onCambiarRol(usuario, RolUsuario.banca);
            } else if (v == 'toggle') {
              onToggleActivo(usuario);
            }
          },
          itemBuilder: (_) => [
            if (!esAdmin)
              const PopupMenuItem(
                value: 'admin',
                child: Row(children: [
                  Icon(Icons.admin_panel_settings,
                      color: Color(0xFF4F46E5), size: 18),
                  SizedBox(width: 8),
                  Text('Hacer Admin',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
            if (esAdmin)
              const PopupMenuItem(
                value: 'banca',
                child: Row(children: [
                  Icon(Icons.store_outlined,
                      color: Color(0xFF059669), size: 18),
                  SizedBox(width: 8),
                  Text('Hacer Banca',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(
                  activo
                      ? Icons.block
                      : Icons.check_circle_outline,
                  color: activo
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF34D399),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(activo ? 'Desactivar' : 'Activar',
                    style: const TextStyle(color: Colors.white)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color  color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)));
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool oculto;
  final TextInputType tipo;

  const _Campo({
    required this.ctrl,
    required this.label,
    this.oculto = false,
    this.tipo   = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller:     ctrl,
        obscureText:    oculto,
        keyboardType:   tipo,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          filled:     true,
          fillColor:  const Color(0xFF0D0D0D),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.08))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF4F46E5), width: 1.5)),
        ),
      );
}
