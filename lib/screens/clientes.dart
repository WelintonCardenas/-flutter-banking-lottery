// ─── screens/clientes_screen.dart ────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/jugada.dart';
import '../models/resultado.dart';
import '../utils/ticket_formatter.dart';
import '../services/horario_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../widgets/bluetooth_modal.dart';
import '../widgets/clientes_widgets.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  bool            _soloHoy             = true;
  List<Resultado> _resultados          = [];
  Timer?          _resultadosTimer;
  DateTime        _ultimaActualizacion = DateTime.now();
  bool            _cargandoResultados  = false;

  // Filtro de fecha para ganadores (null = sin filtro)
  DateTime? _filtroFecha;

  Map<String, HorarioLoteria> _horarios = {};
  StreamSubscription<Map<String, HorarioLoteria>>? _horarioSub;

  @override
  void initState() {
    super.initState();
    _cargarResultados();
    _resultadosTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _cargarResultados());
    _horarioSub = HorarioService.streamHorarios()
        .listen((h) { if (mounted) setState(() => _horarios = h); });
  }

  @override
  void dispose() {
    _resultadosTimer?.cancel();
    _horarioSub?.cancel();
    super.dispose();
  }

  // ── Cargar resultados ──────────────────────────────────────────────────────
  Future<void> _cargarResultados() async {
    if (!mounted) return;
    setState(() => _cargandoResultados = true);
    try {
      final fecha  = _filtroFecha ?? DateTime.now();
      final inicio = DateTime(fecha.year, fecha.month, fecha.day);
      final fin    = inicio.add(const Duration(days: 1));
      final snap   = await FirebaseFirestore.instance
          .collection('resultados')
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .get();
      if (!mounted) return;
      setState(() {
        _resultados          = snap.docs
            .map((d) => Resultado.fromMap(d.data()))
            .toList();
        _ultimaActualizacion = DateTime.now();
        _cargandoResultados  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoResultados = false);
    }
  }

  // ── Stream sin orderBy (evita índice compuesto) ────────────────────────────
  Stream<QuerySnapshot> _streamTickets() {
    var q = FirebaseFirestore.instance
        .collection('tickets')
        .where('uid', isEqualTo: _uid);

    // Si hay filtro de fecha, usar esa fecha; si no, hoy o todos
    if (_filtroFecha != null) {
      final inicio = DateTime(
          _filtroFecha!.year, _filtroFecha!.month, _filtroFecha!.day);
      final fin = inicio.add(const Duration(days: 1));
      q = q
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin));
    } else if (_soloHoy) {
      final hoy    = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day);
      final fin    = inicio.add(const Duration(days: 1));
      q = q
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin));
    }
    return q.snapshots();
  }

  // ── Filtrar por fecha de ganadores ────────────────────────────────────────
  Future<void> _filtrarGanadoresPorFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _filtroFecha ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFBBF24),
            surface: Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (fecha == null || !mounted) return;

    setState(() {
      _filtroFecha = fecha;
      _soloHoy     = false;
    });
    // Recargar resultados de esa fecha para calcular premios
    await _cargarResultados();
  }

  void _limpiarFiltro() {
    setState(() {
      _filtroFecha = null;
      _soloHoy     = true;
    });
    _cargarResultados();
  }

  // ── Reglas borrado ─────────────────────────────────────────────────────────
  bool _puedeBorrar(Map<String, dynamic> data) {
    final fechaTicket = data['fecha'] != null
        ? (data['fecha'] as Timestamp).toDate()
        : null;
    if (fechaTicket == null) return false;

    final hoy   = DateTime.now();
    final esHoy = fechaTicket.year  == hoy.year  &&
                  fechaTicket.month == hoy.month &&
                  fechaTicket.day   == hoy.day;
    if (!esHoy) return false;

    final loterias = (data['jugadas'] as List)
        .map((j) => (j['loteria'] as String? ?? '').trim())
        .toSet();
    for (final l in loterias) {
      if (!(_horarios[l]?.estaAbierta() ?? true)) return false;
    }
    return true;
  }

  String _motivoNoBorrar(Map<String, dynamic> data) {
    final fechaTicket = data['fecha'] != null
        ? (data['fecha'] as Timestamp).toDate()
        : null;
    if (fechaTicket == null) return 'Ticket sin fecha';
    final hoy   = DateTime.now();
    final esHoy = fechaTicket.year  == hoy.year  &&
                  fechaTicket.month == hoy.month &&
                  fechaTicket.day   == hoy.day;
    if (!esHoy) return 'Solo se pueden borrar tickets del día de hoy';
    return 'No se puede borrar: la lotería ya cerró';
  }

  // ── Imprimir ───────────────────────────────────────────────────────────────
  Future<void> _imprimir(Map<String, dynamic> data) async {
    final jugadas  = (data['jugadas'] as List)
        .map((j) => Jugada.fromMap(Map<String, dynamic>.from(j as Map)))
        .toList();
    final total    = (data['total'] as num).toDouble();
    final ticketId = data['ticketId'] as String? ?? '';
    final texto    = formatearTicket(ticketId, jugadas, total);

    if (BluetoothPrinterService.conectado &&
        await BluetoothPrinterService.estaConectado()) {
      _snack('Imprimiendo...');
      final ok = await BluetoothPrinterService.imprimir(texto);
      _snack(ok ? 'Ticket impreso' : 'Error al imprimir', error: !ok);
      return;
    }
    if (!mounted) return;
    imprimirConBluetooth(
      context:     context,
      textoTicket: texto,
      onSnack:     _snack,
    );
  }

  // ── Borrar ─────────────────────────────────────────────────────────────────
  Future<void> _borrarTicket(
      Map<String, dynamic> data, String docId) async {
    if (!_puedeBorrar(data)) {
      _snack(_motivoNoBorrar(data), error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Borrar ticket',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('¿Seguro que deseas borrar este ticket?',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: Text(data['ticketId'] ?? '',
                style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 8),
          const Text('Esta acción no se puede deshacer.',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Borrar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(docId)
          .delete();
      _snack('Ticket eliminado');
    } catch (_) {
      _snack('Error al eliminar', error: true);
    }
  }

  // ── Buscar por últimos 4 dígitos ───────────────────────────────────────────
  void _mostrarBusqueda() {
    final ctrl     = TextEditingController();
    bool  buscando = false;

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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search,
                  color: Color(0xFF818CF8), size: 24),
            ),
            const SizedBox(height: 12),
            const Text('Buscar ticket',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Ingresa los últimos 4 dígitos',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller:   ctrl,
              autofocus:    true,
              keyboardType: TextInputType.number,
              maxLength:    4,
              textAlign:    TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10),
              decoration: InputDecoration(
                counterText: '',
                hintText:    '0000',
                hintStyle:   const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 28,
                    letterSpacing: 10),
                filled:    true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF4F46E5), width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: buscando
                    ? null
                    : () async {
                        final sufijo = ctrl.text.trim();
                        if (sufijo.length != 4) {
                          _snack('Ingresa exactamente 4 dígitos',
                              error: true);
                          return;
                        }
                        setModal(() => buscando = true);
                        try {
                          final snap = await FirebaseFirestore.instance
                              .collection('tickets')
                              .where('uid', isEqualTo: _uid)
                              .get();

                          final coincidencias = snap.docs.where((doc) {
                            final id = (doc.data()['ticketId'] as String? ?? '');
                            final soloNum =
                                id.replaceAll(RegExp(r'[^0-9]'), '');
                            return soloNum.endsWith(sufijo);
                          }).toList();

                          if (!ctx.mounted) return;
                          setModal(() => buscando = false);

                          if (coincidencias.isEmpty) {
                            _snack('Ticket no encontrado', error: true);
                            return;
                          }

                          final doc  = coincidencias.first;
                          final data = doc.data();
                          Navigator.pop(ctx);
                          _verTicket(data, doc.id);
                        } catch (_) {
                          setModal(() => buscando = false);
                          _snack('Error al buscar', error: true);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: buscando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Buscar',
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

  // ── Modal detalle ──────────────────────────────────────────────────────────
  void _verTicket(Map<String, dynamic> data, String docId) {
    final jugadas     = data['jugadas'] as List;
    final total       = (data['total'] as num).toDouble();
    final id          = data['ticketId'] ?? '';
    final fecha       = data['fecha'] != null
        ? (data['fecha'] as Timestamp).toDate()
        : DateTime.now();
    final premio      = calcularPremioTicket(jugadas, _resultados);
    final esGanador   = premio > 0;
    final puedeBorrar = _puedeBorrar(data);
    final motivo      = puedeBorrar ? '' : _motivoNoBorrar(data);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scroll) => Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Cabecera
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: esGanador
                      ? const Color(0xFFEF4444).withOpacity(0.15)
                      : const Color(0xFF4F46E5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  esGanador
                      ? Icons.emoji_events_outlined
                      : Icons.receipt_long,
                  color: esGanador
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF818CF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(id,
                            style: TextStyle(
                                color: esGanador
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF818CF8),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                      ),
                      if (esGanador) ...[
                        const SizedBox(width: 6),
                        BadgeTag(text: 'GANADOR',
                            color: const Color(0xFFEF4444)),
                      ],
                    ]),
                    Text(
                      '${fecha.day.toString().padLeft(2, '0')}/'
                      '${fecha.month.toString().padLeft(2, '0')}/'
                      '${fecha.year}  '
                      '${fecha.hour.toString().padLeft(2, '0')}:'
                      '${fecha.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bluetooth,
                    color: Color(0xFF4F46E5), size: 22),
                onPressed: () {
                  Navigator.pop(ctx);
                  _imprimir(data);
                },
              ),
              if (puedeBorrar)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444), size: 22),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _borrarTicket(data, docId);
                  },
                ),
            ]),
          ),

          // Panel premio
          if (esGanador)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jugado',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                      Text('RD\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                  const Icon(Icons.arrow_forward,
                      color: Color(0xFF6B7280), size: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Premio estimado',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                      Text('RD\$${premio.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                              fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),

          // Motivo no puede borrar
          if (!puedeBorrar && motivo.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF374151).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline,
                    color: Color(0xFF6B7280), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(motivo,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                ),
              ]),
            ),

          if (_resultados.isNotEmpty)
            ResultadosStrip(resultados: _resultados),

          Divider(color: Colors.white.withOpacity(0.06), height: 20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              ColH('Núm.',    flex: 2),
              ColH('Lotería', flex: 3),
              ColH('Tipo',    flex: 3),
              ColH('Monto',   flex: 2),
              ColH('Premio',  flex: 2),
            ]),
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 8),

          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: jugadas.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withOpacity(0.04), height: 1),
              itemBuilder: (_, i) {
                final j     = jugadas[i];
                final comb  = j['comb'] as String;
                final mult  = calcularMultiplicador(
                    Map<String, dynamic>.from(j as Map), _resultados);
                final monto = (j['monto'] as num).toDouble();
                final gana  = monto * mult;
                final esGan = mult > 0;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: esGan
                      ? BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8))
                      : null,
                  child: Row(children: [
                    ColC(j['numero'],
                        flex: 2,
                        color: esGan
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF818CF8),
                        bold: true),
                    ColC(j['loteria'], flex: 3),
                    ColC(comb, flex: 3, color: _colorComb(comb)),
                    ColC('RD\$${monto.toStringAsFixed(0)}',
                        flex: 2,
                        color: const Color(0xFF34D399),
                        bold: true),
                    esGan
                        ? ColC('RD\$${gana.toStringAsFixed(0)}',
                            flex: 2,
                            color: const Color(0xFFEF4444),
                            bold: true)
                        : const ColC('—',
                            flex: 2, color: Color(0xFF374151)),
                  ]),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.06))),
            ),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${jugadas.length} jugadas',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('RD\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                      if (esGanador)
                        Text(
                          '🏆 Premio: RD\$${premio.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (puedeBorrar) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _borrarTicket(data, docId);
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 18),
                      label: const Text('Borrar',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: const Color(0xFFEF4444)
                                .withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: puedeBorrar ? 2 : 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _imprimir(data);
                    },
                    icon: const Icon(Icons.bluetooth,
                        color: Colors.white, size: 20),
                    label: const Text('Imprimir',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: esGanador
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Color _colorComb(String comb) {
    if (comb.contains('Pale'))     return const Color(0xFFFBBF24);
    if (comb.contains('Tripleta')) return const Color(0xFFF87171);
    if (comb.contains('Quiniela')) return const Color(0xFF818CF8);
    return const Color(0xFF6B7280);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? const Color(0xFFEF4444) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _horaCorta(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tituloFiltro = _filtroFecha != null
        ? '${_filtroFecha!.day.toString().padLeft(2, '0')}/'
          '${_filtroFecha!.month.toString().padLeft(2, '0')}/'
          '${_filtroFecha!.year}'
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tickets vendidos',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: _cargandoResultados
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF34D399),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _cargandoResultados
                    ? 'Actualizando...'
                    : 'Actualizado ${_horaCorta(_ultimaActualizacion)}',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 10),
              ),
            ]),
          ],
        ),
        actions: [
          // Buscar por 4 dígitos
          IconButton(
            icon: const Icon(Icons.search,
                color: Color(0xFF818CF8), size: 22),
            onPressed: _mostrarBusqueda,
          ),
          // Botón Hoy / Todos (solo si no hay filtro de fecha activo)
          if (_filtroFecha == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() => _soloHoy = !_soloHoy),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _soloHoy
                        ? const Color(0xFF4F46E5).withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _soloHoy
                          ? const Color(0xFF4F46E5).withOpacity(0.5)
                          : Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    _soloHoy ? 'Hoy' : 'Todos',
                    style: TextStyle(
                      color: _soloHoy
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          // Botón limpiar filtro de fecha
          if (_filtroFecha != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _limpiarFiltro,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFBBF24).withOpacity(0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events,
                        color: Color(0xFFFBBF24), size: 13),
                    const SizedBox(width: 4),
                    Text(tituloFiltro ?? '',
                        style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.close,
                        color: Color(0xFFFBBF24), size: 12),
                  ]),
                ),
              ),
            ),
        ],
      ),
      body: Column(children: [

        // ── Barra de filtro de ganadores por fecha ────────────────────────
        Container(
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _filtrarGanadoresPorFecha,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _filtroFecha != null
                        ? const Color(0xFFFBBF24).withOpacity(0.1)
                        : const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _filtroFecha != null
                          ? const Color(0xFFFBBF24).withOpacity(0.4)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.emoji_events_outlined,
                        color: _filtroFecha != null
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF6B7280),
                        size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _filtroFecha != null
                          ? 'Ganadores del $tituloFiltro'
                          : 'Ver ganadores por fecha',
                      style: TextStyle(
                        color: _filtroFecha != null
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: _filtroFecha != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (_filtroFecha == null) ...[
                      const Spacer(),
                      const Icon(Icons.calendar_today,
                          color: Color(0xFF374151), size: 14),
                    ],
                  ]),
                ),
              ),
            ),
            if (_filtroFecha != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _limpiarFiltro,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      color: Color(0xFF6B7280), size: 16),
                ),
              ),
            ],
          ]),
        ),

        // ── Lista de tickets ─────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _streamTickets(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF4F46E5)));
              }
              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280))));
              }

              // Ordenar en memoria: más reciente primero
              final docs = (snap.data?.docs ?? [])
                ..sort((a, b) {
                  final fa = (a.data() as Map)['fecha'];
                  final fb = (b.data() as Map)['fecha'];
                  if (fa == null || fb == null) return 0;
                  return (fb as Timestamp).compareTo(fa as Timestamp);
                });

              double totalDia     = 0;
              double totalPremios = 0;
              int    ganadores    = 0;

              final enriched = docs.map((doc) {
                final d      = doc.data() as Map<String, dynamic>;
                final jug    = d['jugadas'] as List;
                final premio = calcularPremioTicket(jug, _resultados);
                if (premio > 0) ganadores++;
                totalPremios += premio;
                totalDia     += (d['total'] as num).toDouble();
                return {
                  'data':   d,
                  'premio': premio,
                  'docId':  doc.id,
                };
              }).toList();

              // Con filtro de fecha: TODOS los tickets de ese día,
              // pero ganadores primero (para que se vean arriba).
              // Sin filtro: orden normal (más reciente primero).
              final lista = _filtroFecha != null
                  ? ([
                      ...enriched.where((e) => (e['premio'] as double) > 0),
                      ...enriched.where((e) => (e['premio'] as double) == 0),
                    ])
                  : enriched;

              return Column(children: [
                if (_resultados.isNotEmpty)
                  ResultadosStrip(resultados: _resultados),

                ResumenCard(
                  soloHoy:      _filtroFecha != null ? false : _soloHoy,
                  totalDia:     totalDia,
                  totalTickets: docs.length,
                  ganadores:    ganadores,
                  totalPremios: totalPremios,
                ),

                // Aviso cuando filtro activo pero sin ganadores
                if (_filtroFecha != null && ganadores == 0 && lista.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF6B7280), size: 14),
                      SizedBox(width: 6),
                      Text('Ningún ticket ganó este día',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                    ]),
                  ),

                if (lista.isEmpty)
                  Expanded(child: EmptyState(soloHoy: _soloHoy))
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item = lista[i];
                        final d   = item['data']  as Map<String, dynamic>;
                        final p   = item['premio'] as double;
                        final id  = item['docId']  as String;
                        return TicketCard(
                          data:        d,
                          premio:      p,
                          puedeBorrar: _puedeBorrar(d),
                          onTap:       () => _verTicket(d, id),
                          onImprimir:  () => _imprimir(d),
                          onBorrar:    () => _borrarTicket(d, id),
                        );
                      },
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
