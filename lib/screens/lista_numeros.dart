// ─── screens/lista_numeros_screen.dart ───────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/horario_service.dart';

// Paleta de colores para loterías — se asigna por índice si no está en el mapa
const _coloresFijos = {
  'Nacional': Color(0xFF4F46E5),
  'Leidsa':   Color(0xFF059669),
  'Real':     Color(0xFFD97706),
  'Loteka':   Color(0xFFDB2777),
  'Anguila':  Color(0xFF0891B2),
  'NY':       Color(0xFF7C3AED),
};

const _coloresExtra = [
  Color(0xFFE11D48), Color(0xFF0EA5E9), Color(0xFF16A34A),
  Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFF06B6D4),
];

Color _colorDe(String nombre, int index) =>
    _coloresFijos[nombre] ?? _coloresExtra[index % _coloresExtra.length];

// ─────────────────────────────────────────────────────────────────────────────

class ListaNumerosScreen extends StatefulWidget {
  const ListaNumerosScreen({super.key});

  @override
  State<ListaNumerosScreen> createState() => _ListaNumerosScreenState();
}

class _ListaNumerosScreenState extends State<ListaNumerosScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // ── Horarios desde Firebase ───────────────────────────────────────────────
  Map<String, HorarioLoteria> _horarios = {};
  StreamSubscription<Map<String, HorarioLoteria>>? _horarioSub;
  Timer? _clockTimer;

  /// Lista dinámica ordenada alfabéticamente
  List<String> get _nombresLoterias =>
      _horarios.keys.toList()..sort();

  // ── Estado ────────────────────────────────────────────────────────────────
  String   _loteriaActiva     = '';
  DateTime _fechaSeleccionada = DateTime.now();

  String get _fechaKey =>
      '${_fechaSeleccionada.year}-'
      '${_fechaSeleccionada.month.toString().padLeft(2, '0')}-'
      '${_fechaSeleccionada.day.toString().padLeft(2, '0')}';

  String get _docId => '$_fechaKey-$_loteriaActiva';

  Stream<DocumentSnapshot> get _streamResultado =>
      FirebaseFirestore.instance
          .collection('resultados')
          .doc(_docId)
          .snapshots();

  // ── Ciclo de vida ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _horarioSub = HorarioService.streamHorarios().listen((h) {
      if (!mounted) return;
      setState(() {
        _horarios = h;
        // Si la lotería activa ya no existe, selecciona la primera disponible
        if (_loteriaActiva.isEmpty || !_horarios.containsKey(_loteriaActiva)) {
          _loteriaActiva = _nombresLoterias.isNotEmpty
              ? _nombresLoterias.first
              : '';
        }
      });
    });

    // Actualizar estado abierta/cerrada cada minuto
    _clockTimer = Timer.periodic(
        const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _horarioSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Guardar resultado ─────────────────────────────────────────────────────
  Future<void> _guardarResultado(
      String primero, String segundo, String tercero) async {
    if (primero.isEmpty) {
      _snack('El primer número es obligatorio', error: true);
      return;
    }
    for (final n in [primero, segundo, tercero]) {
      if (n.isNotEmpty && !RegExp(r'^\d+$').hasMatch(n)) {
        _snack('Solo se permiten dígitos', error: true);
        return;
      }
    }

    // Guardar la fecha como UTC medianoche del día local seleccionado
    final offset      = DateTime.now().timeZoneOffset;
    final inicioLocal = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day);
    final inicioUtc = inicioLocal.subtract(offset);

    await FirebaseFirestore.instance
        .collection('resultados')
        .doc(_docId)
        .set({
      'loteria':   _loteriaActiva,
      'fecha':     Timestamp.fromDate(inicioUtc),
      'fechaKey':  _fechaKey,
      'primero':   primero.trim(),
      'segundo':   segundo.trim(),
      'tercero':   tercero.trim(),
      'publicado': true,
      'uid':       user?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _marcarTicketsGanadores(
        primero.trim(), segundo.trim(), tercero.trim());
    _snack('Resultado publicado');
  }

  Future<void> _marcarTicketsGanadores(
      String primero, String segundo, String tercero) async {
    final fecha = _fechaSeleccionada;

    // ── Construir rango en UTC compensando la zona horaria local ─────────────
    // Los tickets se guardan con serverTimestamp() en UTC.
    // DateTime.now().timeZoneOffset da el offset local (ej: -4h en RD).
    // Para que el rango cubra exactamente el día local correcto en UTC:
    final offset = DateTime.now().timeZoneOffset;
    final inicioLocal = DateTime(fecha.year, fecha.month, fecha.day);
    final finLocal    = inicioLocal.add(const Duration(days: 1));
    // Convertir a UTC: restar el offset (UTC = local - offset)
    final inicioUtc = inicioLocal.subtract(offset);
    final finUtc    = finLocal.subtract(offset);

    final tickets = await FirebaseFirestore.instance
        .collection('tickets')
        .where('uid', isEqualTo: user?.uid)          // ← solo tickets del usuario
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioUtc))
        .where('fecha', isLessThan: Timestamp.fromDate(finUtc))
        .get();

    final ganadores = [primero, segundo, tercero]
        .where((n) => n.isNotEmpty)
        .toSet();

    for (final doc in tickets.docs) {
      final jugadas = doc.data()['jugadas'] as List;
      bool  gano    = false;

      for (final j in jugadas) {
        if ((j['loteria'] as String?) != _loteriaActiva) continue;

        final numero = j['numero'] as String;
        final comb   = j['comb']   as String;

        if (comb.contains('Quiniela')) {
          if (ganadores.contains(numero)) { gano = true; break; }
        } else if (comb.contains('Pale') && numero.length == 4) {
          final a = numero.substring(0, 2);
          final b = numero.substring(2, 4);
          if (ganadores.contains(a) && ganadores.contains(b)) {
            gano = true; break;
          }
        } else if (comb.contains('Tripleta') && numero.length == 6) {
          final a = numero.substring(0, 2);
          final b = numero.substring(2, 4);
          final c = numero.substring(4, 6);
          if (ganadores.contains(a) &&
              ganadores.contains(b) &&
              ganadores.contains(c)) {
            gano = true; break;
          }
        }
      }

      if (gano) await doc.reference.update({'ganador': true});
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4F46E5),
            surface: Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (fecha != null) setState(() => _fechaSeleccionada = fecha);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? const Color(0xFFEF4444) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final nombres = _nombresLoterias;

    // Fallback si aún no cargó nada
    if (_loteriaActiva.isEmpty && nombres.isNotEmpty) {
      _loteriaActiva = nombres.first;
    }

    final idxActiva = nombres.indexOf(_loteriaActiva);
    final color     = idxActiva >= 0
        ? _colorDe(_loteriaActiva, idxActiva)
        : const Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Números ganadores',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        actions: [
          TextButton.icon(
            onPressed: _seleccionarFecha,
            icon: const Icon(Icons.calendar_today,
                color: Color(0xFF6B7280), size: 16),
            label: Text(
              '${_fechaSeleccionada.day.toString().padLeft(2, '0')}/'
              '${_fechaSeleccionada.month.toString().padLeft(2, '0')}/'
              '${_fechaSeleccionada.year}',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13),
            ),
          ),
        ],
      ),
      body: nombres.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF818CF8)))
          : Column(children: [

              // ── Chips de loterías ────────────────────────────────────
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  itemCount: nombres.length,
                  itemBuilder: (_, i) {
                    final nombre  = nombres[i];
                    final activa  = nombre == _loteriaActiva;
                    final c       = _colorDe(nombre, i);
                    final h       = _horarios[nombre];
                    final abierta = h?.estaAbierta() ?? false;
                    final mins    = h?.minutosParaCerrar() ?? 0;
                    final pronto  = abierta && mins <= 15;

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _loteriaActiva = nombre),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: activa
                              ? c.withOpacity(0.2)
                              : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: activa
                                ? c.withOpacity(0.6)
                                : Colors.white.withOpacity(0.08),
                            width: activa ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(nombre,
                                style: TextStyle(
                                    color: activa
                                        ? c
                                        : const Color(0xFF6B7280),
                                    fontSize: 13,
                                    fontWeight: activa
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                            const SizedBox(height: 2),
                            // Estado abierta/cerrada debajo del nombre
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5, height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: abierta
                                        ? pronto
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFF34D399)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  abierta
                                      ? pronto
                                          ? '${mins}m'
                                          : 'Abierta'
                                      : 'Cerrada',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: abierta
                                        ? pronto
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFF34D399)
                                        : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Contenido ────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _streamResultado,
                  builder: (context, snap) {
                    Map<String, dynamic>? resultado;
                    if (snap.hasData && snap.data!.exists) {
                      resultado =
                          snap.data!.data() as Map<String, dynamic>;
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        _CardPublicar(
                          loteria:   _loteriaActiva,
                          color:     color,
                          horario:   _horarios[_loteriaActiva],
                          resultado: resultado,
                          onGuardar: _guardarResultado,
                        ),
                        const SizedBox(height: 20),
                        _ResumenDia(
                          fechaKey: _fechaKey,
                          horarios: _horarios,
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}

// ─── Card publicar resultado ──────────────────────────────────────────────────
class _CardPublicar extends StatefulWidget {
  final String              loteria;
  final Color               color;
  final HorarioLoteria?     horario;   // ← nuevo
  final Map<String, dynamic>? resultado;
  final Future<void> Function(String, String, String) onGuardar;

  const _CardPublicar({
    required this.loteria,
    required this.color,
    required this.horario,
    required this.resultado,
    required this.onGuardar,
  });

  @override
  State<_CardPublicar> createState() => _CardPublicarState();
}

class _CardPublicarState extends State<_CardPublicar> {
  final _primeroCtrl = TextEditingController();
  final _segundoCtrl = TextEditingController();
  final _terceroCtrl = TextEditingController();
  bool _guardando = false;
  bool _editando  = false;

  @override
  void initState() {
    super.initState();
    _llenarControllers();
  }

  @override
  void didUpdateWidget(_CardPublicar old) {
    super.didUpdateWidget(old);
    if (old.loteria != widget.loteria) {
      _editando = false;
      _llenarControllers();
    } else if (old.resultado != widget.resultado && !_editando) {
      _llenarControllers();
    }
  }

  void _llenarControllers() {
    if (widget.resultado != null) {
      _primeroCtrl.text = widget.resultado!['primero'] as String? ?? '';
      _segundoCtrl.text = widget.resultado!['segundo'] as String? ?? '';
      _terceroCtrl.text = widget.resultado!['tercero'] as String? ?? '';
    } else {
      _primeroCtrl.clear();
      _segundoCtrl.clear();
      _terceroCtrl.clear();
    }
  }

  @override
  void dispose() {
    _primeroCtrl.dispose();
    _segundoCtrl.dispose();
    _terceroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yaPublicado = widget.resultado != null && !_editando;
    final h           = widget.horario;
    final abierta     = h?.estaAbierta() ?? true;
    final mins        = h?.minutosParaCerrar() ?? 0;
    final pronto      = abierta && mins <= 15;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: yaPublicado
              ? widget.color.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
          width: yaPublicado ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Encabezado ──────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(widget.loteria.substring(0, 1),
                style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.loteria,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                // Horario de la lotería
                if (h != null)
                  Text(
                    h.horarioTexto,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11),
                  ),
              ],
            ),
          ),

          // Badge estado
          if (h != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: abierta
                    ? (pronto
                        ? const Color(0xFFFBBF24).withOpacity(0.15)
                        : const Color(0xFF34D399).withOpacity(0.12))
                    : const Color(0xFF6B7280).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: abierta
                      ? (pronto
                          ? const Color(0xFFFBBF24).withOpacity(0.4)
                          : const Color(0xFF34D399).withOpacity(0.4))
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: abierta
                        ? pronto
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF34D399)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  abierta
                      ? pronto
                          ? 'Cierra en ${mins}m'
                          : 'Abierta'
                      : 'Cerrada · ${h.proximaApertura()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: abierta
                        ? pronto
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF34D399)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ]),
            ),

          // Botón editar (si ya publicado)
          if (yaPublicado) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _editando = true),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF818CF8), size: 16),
              ),
            ),
          ],
        ]),

        // Badge "Publicado"
        if (yaPublicado) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF059669).withOpacity(0.4)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle,
                  color: Color(0xFF34D399), size: 12),
              SizedBox(width: 4),
              Text('Publicado',
                  style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],

        const SizedBox(height: 20),

        if (yaPublicado) ...[
          Row(children: [
            _NumeroGanador(
                label: '1°',
                numero: widget.resultado!['primero'] ?? '',
                color: widget.color),
            const SizedBox(width: 12),
            _NumeroGanador(
                label: '2°',
                numero: widget.resultado!['segundo'] ?? '',
                color: widget.color.withOpacity(0.7)),
            const SizedBox(width: 12),
            _NumeroGanador(
                label: '3°',
                numero: widget.resultado!['tercero'] ?? '',
                color: widget.color.withOpacity(0.5)),
          ]),
        ] else ...[
          const Text('Ingresa los números ganadores',
              style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _CampoNumero(
                  controller: _primeroCtrl,
                  label: '1°',
                  color: widget.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CampoNumero(
                  controller: _segundoCtrl,
                  label: '2°',
                  color: widget.color.withOpacity(0.7)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CampoNumero(
                  controller: _terceroCtrl,
                  label: '3°',
                  color: widget.color.withOpacity(0.5)),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _guardando
                  ? null
                  : () async {
                      setState(() => _guardando = true);
                      await widget.onGuardar(
                        _primeroCtrl.text,
                        _segundoCtrl.text,
                        _terceroCtrl.text,
                      );
                      if (mounted) {
                        setState(() {
                          _guardando = false;
                          _editando  = false;
                        });
                      }
                    },
              icon: _guardando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.publish,
                      color: Colors.white, size: 18),
              label: Text(
                _guardando ? 'Publicando...' : 'Publicar resultado',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Número ganador display ───────────────────────────────────────────────────
class _NumeroGanador extends StatelessWidget {
  final String label, numero;
  final Color  color;
  const _NumeroGanador(
      {required this.label, required this.numero, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                    color: color.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              numero.isEmpty ? '--' : numero,
              style: TextStyle(
                  color:
                      numero.isEmpty ? const Color(0xFF374151) : color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2),
            ),
          ]),
        ),
      );
}

// ─── Campo número input ───────────────────────────────────────────────────────
class _CampoNumero extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color  color;
  const _CampoNumero(
      {required this.controller,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 2,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2),
            decoration: InputDecoration(
              counterText: '',
              hintText: '00',
              hintStyle: const TextStyle(
                  color: Color(0xFF374151), fontSize: 20),
              filled: true,
              fillColor: const Color(0xFF0D0D0D),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: color, width: 1.5)),
            ),
          ),
        ],
      );
}

// ─── Resumen todos los resultados del día ─────────────────────────────────────
class _ResumenDia extends StatelessWidget {
  final String                      fechaKey;
  final Map<String, HorarioLoteria> horarios; // ← recibe horarios para colores

  const _ResumenDia({required this.fechaKey, required this.horarios});

  @override
  Widget build(BuildContext context) {
    final nombres = horarios.keys.toList()..sort();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('resultados')
          .where('fechaKey', isEqualTo: fechaKey)
          .where('publicado', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withOpacity(0.06)),
            ),
            child: const Center(
              child: Text('Sin resultados publicados hoy',
                  style: TextStyle(
                      color: Color(0xFF374151), fontSize: 14)),
            ),
          );
        }

        final docs = snap.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resultados del día',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final d       = doc.data() as Map<String, dynamic>;
              final loteria = d['loteria'] as String;
              final primero = d['primero'] as String? ?? '--';
              final segundo = d['segundo'] as String? ?? '--';
              final tercero = d['tercero'] as String? ?? '--';
              final idx     = nombres.indexOf(loteria);
              final color   = _colorDe(loteria, idx >= 0 ? idx : 0);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 72,
                    child: Text(loteria,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                  const Spacer(),
                  _PillNumero(numero: primero, color: color),
                  const SizedBox(width: 8),
                  _PillNumero(
                      numero: segundo, color: color.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  _PillNumero(
                      numero: tercero, color: color.withOpacity(0.5)),
                ]),
              );
            }),
          ],
        );
      },
    );
  }
}

class _PillNumero extends StatelessWidget {
  final String numero;
  final Color  color;
  const _PillNumero({required this.numero, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          numero.isEmpty ? '--' : numero,
          style: TextStyle(
              color: numero.isEmpty
                  ? const Color(0xFF374151)
                  : color,
              fontWeight: FontWeight.w800,
              fontSize: 14),
        ),
      );
}
