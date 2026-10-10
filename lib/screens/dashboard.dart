// ─── screens/dashboard.dart ──────────────────────────────────────────────────
// Admin ve todas las opciones.
// Banca NO ve: publicar números, horarios.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/cambiar_contrasena_dialog.dart';
import 'login.dart';
import 'clientes.dart';
import 'vender_numero.dart';
import 'lista_numeros.dart';
import 'impresora_screen.dart';
import 'reportes_screen.dart';
import 'admin_horarios_screen.dart';
import 'usuarios_screen.dart';

String _normLoteria(String s) => s.trim().toLowerCase();

double _calcularPremioTicket(
  List jugadas,
  List<Map<String, dynamic>> resultados,
) {
  double total = 0;
  for (final j in jugadas) {
    final comb    = (j['comb']    as String? ?? '').trim();
    final loteria = _normLoteria(j['loteria'] as String? ?? '');
    final numero  = (j['numero']  as String? ?? '').trim();
    final res     = resultados.where((r) =>
        _normLoteria(r['loteria'] as String? ?? '') == loteria).toList();
    if (res.isEmpty) continue;
    double mult = 0;
    if (comb.contains('Quiniela')) {
      for (final r in res) {
        if (r['primero'] == numero) { mult = 80; break; }
        if (r['segundo'] == numero) { mult =  8; break; }
        if (r['tercero'] == numero) { mult =  4; break; }
      }
    } else if (comb.contains('Pale') && numero.length == 4) {
      final n1 = numero.substring(0, 2);
      final n2 = numero.substring(2, 4);
      for (final r in res) {
        final s = <String>{
          r['primero'] as String? ?? '',
          if ((r['segundo'] as String? ?? '').isNotEmpty) r['segundo'] as String,
          if ((r['tercero'] as String? ?? '').isNotEmpty) r['tercero'] as String,
        };
        if (s.contains(n1) && s.contains(n2)) { mult = 400; break; }
      }
    } else if (comb.contains('Tripleta') && numero.length == 6) {
      final n1 = numero.substring(0, 2);
      final n2 = numero.substring(2, 4);
      final n3 = numero.substring(4, 6);
      for (final r in res) {
        final s = <String>{
          r['primero'] as String? ?? '',
          if ((r['segundo'] as String? ?? '').isNotEmpty) r['segundo'] as String,
          if ((r['tercero'] as String? ?? '').isNotEmpty) r['tercero'] as String,
        };
        if (s.contains(n1) && s.contains(n2) && s.contains(n3)) {
          mult = 1500; break;
        }
      }
    }
    total += (j['monto'] as num).toDouble() * mult;
  }
  return total;
}

// =============================================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _uid  = FirebaseAuth.instance.currentUser?.uid;
  final _user = FirebaseAuth.instance.currentUser;

  UsuarioData?               _yo;
  List<Map<String, dynamic>> _resultados = [];
  Timer?                     _resultadosTimer;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _resultadosTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _cargarResultados());
  }

  @override
  void dispose() {
    _resultadosTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    // Asegurar que el usuario tiene documento en Firestore
    await AuthService.asegurarAdminExiste();
    _yo = await AuthService.usuarioActual();
    if (mounted) setState(() {});
    await _cargarResultados();
  }

  Future<void> _cargarResultados() async {
    if (!mounted) return;
    try {
      final hoy    = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day);
      final fin    = inicio.add(const Duration(days: 1));
      final snap   = await FirebaseFirestore.instance
          .collection('resultados')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .get();
      if (!mounted) return;
      setState(() {
        _resultados = snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Stream<QuerySnapshot> get _streamTicketsHoy {
    final hoy    = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin    = inicio.add(const Duration(days: 1));
    // Admin ve todos; banca solo los suyos
    var q = FirebaseFirestore.instance
        .collection('tickets')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin));
    if (_yo?.esBanca == true) {
      q = q.where('uid', isEqualTo: _uid);
    }
    return q.snapshots();
  }

  Stream<QuerySnapshot> get _streamResultadosHoy {
    final hoy    = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin    = inicio.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('resultados')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = _yo?.esAdmin ?? false;
    final size    = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    // Tarjetas según rol
    final tarjetas = <Map<String, dynamic>>[
      {
        'icon':  Icons.people_outline,
        'label': 'Clientes',
        'sub':   'Ver tickets',
        'color': const Color(0xFF4F46E5),
        'screen': () => const ClientesScreen(),
      },
      {
        'icon':  Icons.confirmation_number_outlined,
        'label': 'Vender',
        'sub':   'Nuevo ticket',
        'color': const Color(0xFFD97706),
        'screen': () => const VenderNumeroScreen(),
      },
      {
        'icon':  Icons.print_outlined,
        'label': 'Impresora',
        'sub':   'Bluetooth',
        'color': const Color(0xFF0891B2),
        'screen': () => const ImpresoraScreen(),
      },
      {
        'icon':  Icons.bar_chart_rounded,
        'label': 'Reportes',
        'sub':   esAdmin ? 'Ver vendedores' : 'Mi ganancia',
        'color': const Color(0xFF7C3AED),
        'screen': () => const ReportesScreen(),
      },
      // Solo admin
      if (esAdmin) ...[
        {
          'icon':  Icons.grid_view_rounded,
          'label': 'Números',
          'sub':   'Publicar resultados',
          'color': const Color(0xFF059669),
          'screen': () => const ListaNumerosScreen(),
        },
        {
          'icon':  Icons.schedule_rounded,
          'label': 'Horarios',
          'sub':   'Cambiar horario',
          'color': const Color(0xFFE11D48),
          'screen': () => const AdminHorariosScreen(),
        },
        {
          'icon':  Icons.manage_accounts_outlined,
          'label': 'Usuarios',
          'sub':   'Gestionar vendedores',
          'color': const Color(0xFF0891B2),
          'screen': () => const UsuariosScreen(),
        },
      ],
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Dashboard',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined,
                color: Color(0xFF6B7280)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const ImpresoraScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline, color: Color(0xFF6B7280)),
            tooltip: 'Cambiar contraseña',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const CambiarContrasenaDialog(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Bienvenida + badge de rol
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmall ? 14 : 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF4F46E5).withOpacity(0.3)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: isSmall ? 20 : 24,
                    backgroundColor:
                        const Color(0xFF4F46E5).withOpacity(0.2),
                    child: Icon(Icons.person,
                        color: const Color(0xFF818CF8),
                        size: isSmall ? 22 : 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                            _yo?.nombre.isNotEmpty == true
                                ? _yo!.nombre
                                : (_user?.email ?? 'Usuario'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: esAdmin
                                  ? const Color(0xFF4F46E5).withOpacity(0.2)
                                  : const Color(0xFF059669).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: esAdmin
                                    ? const Color(0xFF4F46E5).withOpacity(0.5)
                                    : const Color(0xFF059669).withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              esAdmin ? 'ADMIN' : 'BANCA',
                              style: TextStyle(
                                color: esAdmin
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF34D399),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ]),
                        Text(
                          _user?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),

              SizedBox(height: isSmall ? 12 : 16),
              const Text('Tu panel',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: isSmall ? 8 : 12),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isSmall ? 1.2 : 1.0,
                  children: tarjetas.map((t) => _DashboardCard(
                    icon:  t['icon'] as IconData,
                    label: t['label'] as String,
                    sub:   t['sub']   as String,
                    color: t['color'] as Color,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) =>
                                (t['screen'] as Widget Function())())),
                  )).toList(),
                ),
              ),

              // Resumen
              StreamBuilder<QuerySnapshot>(
                stream: _streamResultadosHoy,
                builder: (_, snapRes) {
                  final rv = snapRes.hasData
                      ? snapRes.data!.docs
                          .map((d) => d.data() as Map<String, dynamic>)
                          .toList()
                      : _resultados;
                  return StreamBuilder<QuerySnapshot>(
                    stream: _streamTicketsHoy,
                    builder: (_, snapTix) {
                      double vendido = 0, premios = 0;
                      int    tickets = 0, ganadores = 0;
                      bool   cargando = snapTix.connectionState ==
                          ConnectionState.waiting;
                      if (snapTix.hasData) {
                        for (final doc in snapTix.data!.docs) {
                          final d   = doc.data() as Map<String, dynamic>;
                          final jug = d['jugadas'] as List;
                          final p   = _calcularPremioTicket(jug, rv);
                          vendido += (d['total'] as num).toDouble();
                          tickets++;
                          if (p > 0) { ganadores++; premios += p; }
                        }
                      }
                      return _ResumenCard(
                        vendido: vendido, tickets: tickets,
                        ganadores: ganadores, premios: premios,
                        cargando: cargando,
                        labelVendido: esAdmin ? 'Vendido hoy' : 'Mi venta',
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  final IconData icon; final String label, sub; final Color color;
  final VoidCallback onTap;
  const _DashboardCard({required this.icon, required this.label,
      required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16), onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10)),
            ]),
          ),
        ),
      );
}

class _ResumenCard extends StatelessWidget {
  final double vendido, premios; final int tickets, ganadores;
  final bool cargando; final String labelVendido;
  const _ResumenCard({required this.vendido, required this.tickets,
      required this.ganadores, required this.premios,
      required this.cargando, required this.labelVendido});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ganadores > 0
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : Colors.white.withOpacity(0.06)),
        ),
        child: cargando
            ? const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: Color(0xFF4F46E5))))
            : Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                _Item(label: labelVendido,
                    valor: 'RD\$${vendido.toStringAsFixed(0)}',
                    color: const Color(0xFF34D399)),
                _Div(),
                _Item(label: 'Tickets', valor: '$tickets',
                    color: Colors.white),
                _Div(),
                _Item(label: 'Ganadores', valor: '$ganadores',
                    color: ganadores > 0
                        ? const Color(0xFFEF4444) : Colors.white),
                if (premios > 0) ...[
                  _Div(),
                  _Item(label: 'Premios',
                      valor: 'RD\$${premios.toStringAsFixed(0)}',
                      color: const Color(0xFFEF4444)),
                ],
              ]),
      );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 30, color: Colors.white.withOpacity(0.08));
}

class _Item extends StatelessWidget {
  final String label, valor; final Color color;
  const _Item({required this.label, required this.valor, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(valor, style: TextStyle(color: color, fontSize: 15,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10)),
      ]);
}
