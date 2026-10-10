// ─── screens/reportes_screen.dart ────────────────────────────────────────────
// Admin: ve todos los usuarios con sus ventas del día o del mes.
// Banca: ve solo sus propias ventas del día o del mes.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/resultado.dart';
import '../services/auth_service.dart';

const double _kComision = 0.07;

enum _ModoReporte { dia, mes }

class _VendedorData {
  final String uid;
  final String nombre;
  final String email;
  double ingreso   = 0;
  double egreso    = 0;
  int    tickets   = 0;
  int    ganadores = 0;
  double get ganancia     => ingreso - egreso;
  double get comision     => ingreso * _kComision;
  double get gananciaReal => ganancia - comision;

  _VendedorData({required this.uid, required this.nombre, required this.email});
}

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final _uid    = FirebaseAuth.instance.currentUser?.uid;
  bool          _cargando = true;
  String        _error    = '';

  _ModoReporte  _modo = _ModoReporte.dia;
  late DateTime _dia;
  late DateTime _mes;
  UsuarioData?  _yo;

  // Para admin: lista de vendedores
  List<_VendedorData> _vendedores = [];

  // Para banca: solo sus datos
  _VendedorData? _misDatos;

  // Expandir vendedor en la lista
  final Set<String> _expandido = {};

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _dia = DateTime(hoy.year, hoy.month, hoy.day);
    _mes = DateTime(hoy.year, hoy.month);
    _init();
  }

  Future<void> _init() async {
    _yo = await AuthService.usuarioActual();
    await _cargar();
  }

  void _cambiarModo(_ModoReporte nuevo) {
    if (nuevo == _modo) return;
    setState(() {
      _modo = nuevo;
      _expandido.clear();
    });
    _cargar();
  }

  void _cambiarDia(int delta) {
    setState(() {
      _dia = _dia.add(Duration(days: delta));
      _expandido.clear();
    });
    _cargar();
  }

  void _cambiarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta);
      _expandido.clear();
    });
    _cargar();
  }

  Future<void> _abrirCalendarioDia() async {
    final hoy = DateTime.now();
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      helpText: 'Selecciona un día',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4F46E5),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A2E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A1A2E),
        ),
        child: child!,
      ),
    );
    if (seleccion == null) return;
    setState(() {
      _dia = DateTime(seleccion.year, seleccion.month, seleccion.day);
      _expandido.clear();
    });
    _cargar();
  }

  Future<void> _abrirCalendarioMes() async {
    final hoy = DateTime.now();
    int anioSel = _mes.year;
    int mesSel  = _mes.month;

    final resultado = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Selecciona un mes',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              // Selector de año
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Color(0xFF818CF8)),
                  onPressed: () => setModal(() => anioSel--),
                ),
                Text('$anioSel',
                    style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w700)),
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: anioSel >= hoy.year
                          ? const Color(0xFF374151)
                          : const Color(0xFF818CF8)),
                  onPressed: anioSel >= hoy.year
                      ? null
                      : () => setModal(() => anioSel++),
                ),
              ]),
              const SizedBox(height: 12),

              // Grid de meses
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: List.generate(12, (i) {
                  final m = i + 1;
                  final deshabilitado =
                      anioSel > hoy.year || (anioSel == hoy.year && m > hoy.month);
                  final esActual = m == mesSel;
                  return GestureDetector(
                    onTap: deshabilitado
                        ? null
                        : () => setModal(() => mesSel = m),
                    child: Container(
                      decoration: BoxDecoration(
                        color: esActual
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: esActual
                              ? const Color(0xFF4F46E5)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _nombresMes[m].substring(0, 3),
                        style: TextStyle(
                          color: deshabilitado
                              ? const Color(0xFF374151)
                              : esActual
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, DateTime(anioSel, mesSel)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    if (resultado == null) return;
    setState(() {
      _mes = resultado;
      _expandido.clear();
    });
    _cargar();
  }

  // Rango de fechas (en hora local) según el modo activo
  (DateTime, DateTime) get _rangoLocal {
    if (_modo == _ModoReporte.dia) {
      final inicio = DateTime(_dia.year, _dia.month, _dia.day);
      final fin    = inicio.add(const Duration(days: 1));
      return (inicio, fin);
    }
    final inicio = DateTime(_mes.year, _mes.month, 1);
    final fin    = DateTime(_mes.year, _mes.month + 1, 1);
    return (inicio, fin);
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = ''; });

    try {
      final offset = DateTime.now().timeZoneOffset;
      final (inicioLocal, finLocal) = _rangoLocal;
      final inicio = inicioLocal.subtract(offset);
      final fin    = finLocal.subtract(offset);

      // Cargar resultados del rango
      final snapRes = await FirebaseFirestore.instance
          .collection('resultados')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .get();
      final resultados = snapRes.docs
          .map((d) => Resultado.fromMap(d.data()))
          .toList();

      if (_yo?.esAdmin == true) {
        // ── ADMIN: cargar todos los usuarios y sus tickets ──────────────
        final snapUsuarios = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('creadoPor', isEqualTo: _uid)
            .get();

        // También incluir al propio admin
        final snapAdmin = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_uid)
            .get();
        final allDocs = [...snapUsuarios.docs, if (snapAdmin.exists) snapAdmin];

        final Map<String, _VendedorData> vendedoresMap = {};
        for (final doc in allDocs) {
          final d = doc.data();
          vendedoresMap[doc.id] = _VendedorData(
            uid:    doc.id,
            nombre: d?['nombre'] as String? ?? d?['email'] as String? ?? 'Sin nombre',
            email:  d?['email']  as String? ?? '',
          );
        }

        // Cargar TODOS los tickets del rango
        final snapTix = await FirebaseFirestore.instance
            .collection('tickets')
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha', isLessThan: Timestamp.fromDate(fin))
            .get();

        for (final doc in snapTix.docs) {
          final d       = doc.data();
          final tUid    = d['uid'] as String? ?? '';
          final jugadas = d['jugadas'] as List;
          final total   = (d['total'] as num).toDouble();

          final fechaTicket = d['fecha'] != null
              ? (d['fecha'] as Timestamp).toDate().toLocal()
              : DateTime.now();

          final resDia = resultados.where((r) {
            final fr = r.fecha.toLocal();
            return fr.year  == fechaTicket.year  &&
                   fr.month == fechaTicket.month &&
                   fr.day   == fechaTicket.day;
          }).toList();

          final premio = calcularPremioTicket(jugadas, resDia);

          // Asignar al vendedor correspondiente
          vendedoresMap.putIfAbsent(tUid, () => _VendedorData(
              uid: tUid, nombre: 'Desconocido', email: ''));
          final v = vendedoresMap[tUid]!;
          v.ingreso += total;
          v.egreso  += premio;
          v.tickets++;
          if (premio > 0) v.ganadores++;
        }

        if (!mounted) return;
        setState(() {
          _vendedores = vendedoresMap.values.toList()
            ..sort((a, b) => b.ingreso.compareTo(a.ingreso));
          _cargando   = false;
        });
      } else {
        // ── BANCA: solo sus propios tickets ────────────────────────────
        final snapTix = await FirebaseFirestore.instance
            .collection('tickets')
            .where('uid', isEqualTo: _uid)
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha', isLessThan: Timestamp.fromDate(fin))
            .get();

        final mis = _VendedorData(
          uid:    _uid ?? '',
          nombre: _yo?.nombre ?? '',
          email:  _yo?.email  ?? '',
        );

        for (final doc in snapTix.docs) {
          final d       = doc.data();
          final jugadas = d['jugadas'] as List;
          final total   = (d['total'] as num).toDouble();
          final fechaTicket = d['fecha'] != null
              ? (d['fecha'] as Timestamp).toDate().toLocal()
              : DateTime.now();
          final resDia = resultados.where((r) {
            final fr = r.fecha.toLocal();
            return fr.year  == fechaTicket.year  &&
                   fr.month == fechaTicket.month &&
                   fr.day   == fechaTicket.day;
          }).toList();
          final premio = calcularPremioTicket(jugadas, resDia);
          mis.ingreso += total;
          mis.egreso  += premio;
          mis.tickets++;
          if (premio > 0) mis.ganadores++;
        }

        if (!mounted) return;
        setState(() { _misDatos = mis; _cargando = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = 'Error: $e'; });
    }
  }

  static const _nombresMes = ['','Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

  static const _nombresDiaSemana = ['Lunes','Martes','Miércoles','Jueves',
      'Viernes','Sábado','Domingo'];

  String get _tituloMes => '${_nombresMes[_mes.month]} ${_mes.year}';

  String get _tituloDia {
    final hoy   = DateTime.now();
    final hoyD  = DateTime(hoy.year, hoy.month, hoy.day);
    final ayer  = hoyD.subtract(const Duration(days: 1));
    if (_dia == hoyD)  return 'Hoy';
    if (_dia == ayer)  return 'Ayer';
    final nombreDia = _nombresDiaSemana[_dia.weekday - 1];
    return '$nombreDia ${_dia.day} de ${_nombresMes[_dia.month]}';
  }

  String get _tituloActual =>
      _modo == _ModoReporte.dia ? _tituloDia : _tituloMes;

  bool get _esMesActual {
    final hoy = DateTime.now();
    return _mes.year == hoy.year && _mes.month == hoy.month;
  }

  bool get _esDiaActual {
    final hoy = DateTime.now();
    return _dia.year == hoy.year && _dia.month == hoy.month && _dia.day == hoy.day;
  }

  String _fmt(double v) => 'RD\$${v.toStringAsFixed(0)}';
  Color  _cg(double v)  => v >= 0
      ? const Color(0xFF34D399)
      : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: Text(
          _yo?.esAdmin == true ? 'Reportes — Vendedores' : 'Mi reporte',
          style: const TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: _cargando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF818CF8)))
                : const Icon(Icons.refresh,
                    color: Color(0xFF818CF8), size: 22),
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      body: Column(children: [
        // Tabs Día / Mes
        Container(
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(children: [
            Expanded(
              child: _TabModo(
                label: 'Día',
                seleccionado: _modo == _ModoReporte.dia,
                onTap: _cargando ? null : () => _cambiarModo(_ModoReporte.dia),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabModo(
                label: 'Mes',
                seleccionado: _modo == _ModoReporte.mes,
                onTap: _cargando ? null : () => _cambiarModo(_ModoReporte.mes),
              ),
            ),
          ]),
        ),

        // Selector día o mes
        Container(
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Color(0xFF818CF8)),
              onPressed: _cargando
                  ? null
                  : () => _modo == _ModoReporte.dia
                      ? _cambiarDia(-1)
                      : _cambiarMes(-1),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _cargando
                    ? null
                    : () => _modo == _ModoReporte.dia
                        ? _abrirCalendarioDia()
                        : _abrirCalendarioMes(),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_tituloActual,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_month_outlined,
                      color: Color(0xFF818CF8), size: 17),
                ]),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right,
                  color: (_modo == _ModoReporte.dia ? _esDiaActual : _esMesActual)
                      ? const Color(0xFF374151)
                      : const Color(0xFF818CF8)),
              onPressed: _cargando ||
                      (_modo == _ModoReporte.dia ? _esDiaActual : _esMesActual)
                  ? null
                  : () => _modo == _ModoReporte.dia
                      ? _cambiarDia(1)
                      : _cambiarMes(1),
            ),
          ]),
        ),

        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(
                  color: Color(0xFF4F46E5)))
              : _error.isNotEmpty
                  ? _ErrView(msg: _error, onRetry: _cargar)
                  : _yo?.esAdmin == true
                      ? _buildAdmin()
                      : _buildBanca(),
        ),
      ]),
    );
  }

  // ── Vista ADMIN ────────────────────────────────────────────────────────────
  Widget _buildAdmin() {
    if (_vendedores.isEmpty) {
      return Center(child: Text('Sin ventas en $_tituloActual',
          style: const TextStyle(color: Color(0xFF374151))));
    }

    // Totales generales
    final totalIngreso   = _vendedores.fold(0.0, (s, v) => s + v.ingreso);
    final totalEgreso    = _vendedores.fold(0.0, (s, v) => s + v.egreso);
    final totalComision  = totalIngreso * _kComision;
    final totalNeto      = totalIngreso - totalEgreso - totalComision;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tarjeta resumen total
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: totalNeto >= 0
                  ? const Color(0xFF34D399).withOpacity(0.4)
                  : const Color(0xFFEF4444).withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Column(children: [
            Text(_modo == _ModoReporte.dia
                    ? 'Ganancia total del día'
                    : 'Ganancia total del mes',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12)),
            const SizedBox(height: 8),
            Text(_fmt(totalNeto),
                style: TextStyle(
                    color: _cg(totalNeto),
                    fontSize: 32,
                    fontWeight: FontWeight.w800)),
            const Text('después de premios y comisión',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF374151)),
            const SizedBox(height: 10),
            // Fórmula
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _FItem(label: 'Vendido',  valor: _fmt(totalIngreso),
                  color: const Color(0xFF818CF8)),
              const _Op('−'),
              _FItem(label: 'Premios',  valor: _fmt(totalEgreso),
                  color: const Color(0xFFEF4444)),
              const _Op('−'),
              _FItem(label: 'Comisión', valor: _fmt(totalComision),
                  color: const Color(0xFFF59E0B)),
              const _Op('='),
              _FItem(label: 'Neto', valor: _fmt(totalNeto),
                  color: _cg(totalNeto), bold: true),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        const Row(children: [
          Icon(Icons.people_outline, color: Color(0xFF818CF8), size: 18),
          SizedBox(width: 8),
          Text('Por vendedor',
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),

        // Lista de vendedores
        ..._vendedores.where((v) => v.tickets > 0).map((v) {
          final abierto = _expandido.contains(v.uid);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => abierto
                    ? _expandido.remove(v.uid)
                    : _expandido.add(v.uid)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(children: [
                    // Avatar
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          const Color(0xFF4F46E5).withOpacity(0.15),
                      child: Text(
                        v.nombre.isNotEmpty
                            ? v.nombre[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Color(0xFF818CF8),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nombre + tickets
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.nombre,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('${v.tickets} ticket${v.tickets != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 11)),
                        ],
                      ),
                    ),

                    // Cifras
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text(_fmt(v.ingreso),
                          style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text('Neto: ${_fmt(v.gananciaReal)}',
                          style: TextStyle(
                              color: _cg(v.gananciaReal),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(width: 6),
                    Icon(abierto
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                        color: const Color(0xFF6B7280), size: 18),
                  ]),
                ),
              ),

              // Detalle expandido del vendedor
              if (abierto)
                Container(
                  margin: const EdgeInsets.only(left: 12, bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(children: [
                    _FilaDetalle('Vendido',  _fmt(v.ingreso),
                        const Color(0xFF818CF8)),
                    _FilaDetalle('Premios pagados', _fmt(v.egreso),
                        const Color(0xFFEF4444)),
                    _FilaDetalle('Ganancia bruta', _fmt(v.ganancia),
                        _cg(v.ganancia)),
                    _FilaDetalle('Comisión 7%',   _fmt(v.comision),
                        const Color(0xFFF59E0B)),
                    const Divider(color: Color(0xFF1F2937), height: 14),
                    _FilaDetalle('Ganancia neta', _fmt(v.gananciaReal),
                        _cg(v.gananciaReal), bold: true),
                    _FilaDetalle('Ganadores',
                        '${v.ganadores}',
                        const Color(0xFFEF4444)),
                  ]),
                ),
            ],
          );
        }).toList(),
      ],
    );
  }

  // ── Vista BANCA (sus propios datos) ───────────────────────────────────────
  Widget _buildBanca() {
    final v = _misDatos;
    if (v == null || v.tickets == 0) {
      return Center(child: Text('Sin ventas en $_tituloActual',
          style: const TextStyle(color: Color(0xFF374151))));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Ganancia neta grande
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: v.gananciaReal >= 0
                  ? const Color(0xFF34D399).withOpacity(0.5)
                  : const Color(0xFFEF4444).withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(children: [
            Text(_fmt(v.gananciaReal),
                style: TextStyle(
                    color: _cg(v.gananciaReal),
                    fontSize: 38, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_modo == _ModoReporte.dia
                    ? 'Mi ganancia neta hoy'
                    : 'Mi ganancia neta',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF374151)),
            const SizedBox(height: 12),
            _FilaDetalle('Vendido',       _fmt(v.ingreso),
                const Color(0xFF818CF8)),
            _FilaDetalle('Premios',       _fmt(v.egreso),
                const Color(0xFFEF4444)),
            _FilaDetalle('Comisión 7%',   _fmt(v.comision),
                const Color(0xFFF59E0B)),
            const Divider(color: Color(0xFF374151), height: 14),
            _FilaDetalle('Ganancia neta', _fmt(v.gananciaReal),
                _cg(v.gananciaReal), bold: true),
          ]),
        ),

        const SizedBox(height: 12),

        // Métricas rápidas
        Row(children: [
          Expanded(child: _MiniCard(
              label: 'Tickets', valor: '${v.tickets}',
              color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(child: _MiniCard(
              label: 'Ganadores', valor: '${v.ganadores}',
              color: const Color(0xFFEF4444))),
          const SizedBox(width: 10),
          Expanded(child: _MiniCard(
              label: 'Mi comisión', valor: _fmt(v.comision),
              color: const Color(0xFFF59E0B))),
        ]),
      ]),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _TabModo extends StatelessWidget {
  final String label;
  final bool   seleccionado;
  final VoidCallback? onTap;
  const _TabModo({required this.label, required this.seleccionado, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado
                ? const Color(0xFF4F46E5)
                : const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado
                  ? const Color(0xFF4F46E5)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: seleccionado ? Colors.white : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      );
}

class _FilaDetalle extends StatelessWidget {
  final String label, valor;
  final Color  color;
  final bool   bold;
  const _FilaDetalle(this.label, this.valor, this.color,
      {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 12))),
          Text(valor,
              style: TextStyle(
                  color: color,
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ]),
      );
}

class _MiniCard extends StatelessWidget {
  final String label, valor;
  final Color  color;
  const _MiniCard(
      {required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Text(valor,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10)),
        ]),
      );
}

class _FItem extends StatelessWidget {
  final String label, valor;
  final Color  color;
  final bool   bold;
  const _FItem({required this.label, required this.valor,
      required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(valor,
            style: TextStyle(
                color: color,
                fontSize: bold ? 13 : 11,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 9)),
      ]);
}

class _Op extends StatelessWidget {
  final String text;
  const _Op(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Color(0xFF6B7280),
          fontSize: 14, fontWeight: FontWeight.w300));
}

class _ErrView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: const Color(0xFF4F46E5).withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reintentar',
                style: TextStyle(color: Color(0xFF818CF8))),
          ),
        ]),
      );
}
