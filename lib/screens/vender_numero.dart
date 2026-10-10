// ─── screens/vender_numero_screen.dart ───────────────────────────────────────
// Solo contiene: estado, lógica de negocio y coordinación entre widgets.
// UI delegada a: VenderTabla, VenderPanel, SelectorLoteria

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/jugada.dart';
import '../services/ticket_service.dart';
import '../services/horario_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../utils/ticket_formatter.dart';
import '../widgets/tabla_widgets.dart';
import '../widgets/ticket_modals.dart';
import '../widgets/vender_tabla.dart';
import '../widgets/vender_panel.dart';
import '../widgets/selector_copiar_loterias.dart';

class VenderNumeroScreen extends StatefulWidget {
  const VenderNumeroScreen({super.key});

  @override
  State<VenderNumeroScreen> createState() => _VenderNumeroScreenState();
}

class _VenderNumeroScreenState extends State<VenderNumeroScreen> {
  // ── Controladores ──────────────────────────────────────────────────────────
  final _numeroCtrl = TextEditingController();
  final _montoCtrl  = TextEditingController();
  final _montoFocus = FocusNode();

  // ── Estado ─────────────────────────────────────────────────────────────────
  String? _loteria;
  List<String> _loteriasMultiples = [];
  String  _combDetectada = '---';
  bool    _modoLiga      = false;
  bool    _guardando     = false;
  bool    _imprimiendo   = false;
  List<Jugada> _jugadas  = [];

  // ── Horarios ───────────────────────────────────────────────────────────────
  Map<String, HorarioLoteria> _horarios = {};
  StreamSubscription<Map<String, HorarioLoteria>>? _horarioSub;
  Timer? _clockTimer;

  // ── Estado de impresora ─────────────────────────────────────────────────────
  bool _impresoraConectada = false;
  Timer? _impresoraTimer;

  List<String> get _todasLasLoterias => _horarios.keys.toList()..sort();
  List<String> get _loteriasAbiertas => _todasLasLoterias
      .where((l) => _horarios[l]?.estaAbierta() ?? true)
      .toList();
  double get _total => _jugadas.fold(0, (s, j) => s + j.monto);

  // ── Límite RD$150 por número+lotería ──────────────────────────────────────
  static const double _limiteNumero = 150.0;

  double _montoActual(String numero, String loteria) =>
      _jugadas
          .where((j) => j.numero == numero && j.loteria == loteria)
          .fold(0.0, (s, j) => s + j.monto);

  String? _validarLimite(String numero, String loteria, double montoNuevo) {
    final acumulado  = _montoActual(numero, loteria);
    final totalFinal = acumulado + montoNuevo;
    if (totalFinal > _limiteNumero) {
      final disponible = _limiteNumero - acumulado;
      if (disponible <= 0) {
        return 'El $numero en $loteria ya llegó al límite de RD\$${_limiteNumero.toStringAsFixed(0)}';
      }
      return 'Solo puedes agregar RD\$${disponible.toStringAsFixed(0)} más al $numero en $loteria (límite RD\$${_limiteNumero.toStringAsFixed(0)})';
    }
    return null;
  }

  // ── Ciclo de vida ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _montoFocus.addListener(() => setState(() {}));
    _horarioSub = HorarioService.streamHorarios().listen((h) {
      if (!mounted) return;
      setState(() { _horarios = h; _ajustarLoteriaActual(); });
    });
    _clockTimer = Timer.periodic(
        const Duration(minutes: 1), (_) { if (mounted) setState(_ajustarLoteriaActual); });
    _verificarImpresora();
    _impresoraTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _verificarImpresora());
  }

  Future<void> _verificarImpresora() async {
    final conectada = BluetoothPrinterService.conectado &&
        await BluetoothPrinterService.estaConectado();
    if (!mounted) return;
    if (conectada != _impresoraConectada) {
      setState(() => _impresoraConectada = conectada);
    }
  }

  void _ajustarLoteriaActual() {
    final abiertas = _loteriasAbiertas;
    if (abiertas.isEmpty) { _loteria = null; return; }
    if (_loteria == null || !abiertas.contains(_loteria)) {
      _loteria = abiertas.first;
      _limpiar();
    }
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _montoCtrl.dispose();
    _montoFocus.dispose();
    _horarioSub?.cancel();
    _clockTimer?.cancel();
    _impresoraTimer?.cancel();
    super.dispose();
  }

  // ── Lógica del teclado ─────────────────────────────────────────────────────
  void _onTecla(String v) {
    if (_loteria == null) return;
    final actual = _numeroCtrl.text;
    switch (v) {
      case '←':     _handleBorrar(actual); return;
      case 'C':     _limpiar();            return;
      case 'Enter': _handleEnter(actual);  return;
      case './':    _handleLiga(actual);   return;
    }
    if (_montoFocus.hasFocus) { _appendMonto(v); return; }
    _appendNumero(actual, v);
  }

  void _handleBorrar(String actual) {
    if (_montoFocus.hasFocus) {
      if (_montoCtrl.text.isNotEmpty)
        setState(() => _montoCtrl.text =
            _montoCtrl.text.substring(0, _montoCtrl.text.length - 1));
    } else if (actual.isNotEmpty) {
      final nuevo = actual.substring(0, actual.length - 1);
      setState(() {
        _numeroCtrl.text = nuevo;
        _modoLiga        = nuevo.contains('./');
        _combDetectada   = detectarComb(
            nuevo.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), ''));
      });
    }
  }

  void _limpiar() {
    setState(() {
      _numeroCtrl.clear();
      _montoCtrl.clear();
      _combDetectada = '---';
      _modoLiga      = false;
    });
    _montoFocus.unfocus();
  }

  void _handleEnter(String actual) {
    if (_montoFocus.hasFocus) {
      _montoFocus.unfocus();
      _agregarJugada();
      return;
    }
    final digitos = actual.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (actual.isEmpty || (!_modoLiga && ![2, 4, 6].contains(digitos.length))) {
      _snack('Número inválido (2, 4 o 6 dígitos)', error: true); return;
    }
    Future.microtask(() => _montoFocus.requestFocus());
  }

  void _handleLiga(String actual) {
    if (!_modoLiga && !_montoFocus.hasFocus) {
      setState(() { _numeroCtrl.text = actual + './'; _modoLiga = true; });
    }
  }

  void _appendMonto(String v) {
    if (!RegExp(r'^[0-9.]$').hasMatch(v)) return;
    if (v == '.' && _montoCtrl.text.contains('.')) return;
    setState(() => _montoCtrl.text += v);
  }

  void _appendNumero(String actual, String v) {
    final solo = actual.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (solo.length >= 6) return;
    final nuevo  = actual + v;
    final digs   = nuevo.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _numeroCtrl.text = nuevo;
      _combDetectada   = _modoLiga ? detectarCombLiga(digs) : detectarComb(digs);
    });
  }

  // ── Jugadas ────────────────────────────────────────────────────────────────
  void _agregarJugada() {
    final entrada = _numeroCtrl.text.trim();
    final monto   = double.tryParse(_montoCtrl.text.trim());

    if (entrada.isEmpty || entrada == './') {
      _snack('Ingresa un número', error: true);
      return;
    }
    if (monto == null || monto <= 0) {
      _snack('Ingresa un monto válido', error: true);
      return;
    }
    if (_loteriasMultiples.isEmpty) {
      _snack('Selecciona al menos una lotería', error: true);
      return;
    }

    if (_modoLiga) {
      _agregarLigadas(entrada, monto);
      return;
    }

    final digitos = entrada.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (![2, 4, 6].contains(digitos.length)) {
      _snack('Número inválido (2, 4 o 6 dígitos)', error: true);
      return;
    }

    // Validar límite para todas las loterías seleccionadas
    for (final loteria in _loteriasMultiples) {
      final errorLimite = _validarLimite(digitos, loteria, monto);
      if (errorLimite != null) {
        _snack(errorLimite, error: true);
        return;
      }
    }

    // Agregar jugada para cada lotería seleccionada
    setState(() {
      for (final loteria in _loteriasMultiples) {
        _jugadas.add(Jugada(
          numero: digitos,
          loteria: loteria,
          comb: detectarComb(digitos),
          forma: 'Fijo',
          monto: monto
        ));
      }
      // Limpiar solo número y monto, mantener loterías seleccionadas
      _numeroCtrl.clear();
      _montoCtrl.clear();
      _combDetectada = '---';
    });
    _snack('${_loteriasMultiples.length} jugada${_loteriasMultiples.length != 1 ? "s" : ""} agregada${_loteriasMultiples.length != 1 ? "s" : ""}');
    Future.microtask(() {
      if (mounted) _numeroCtrl.selection = TextSelection.fromPosition(TextPosition(offset: 0));
    });
  }


  void _agregarLigadas(String entrada, double monto) {
    if (_loteriasMultiples.isEmpty) {
      _snack('Selecciona al menos una lotería', error: true);
      return;
    }

    final combinaciones = generarLigasSoloPales(entrada);

    // Validar límite para todas las loterías seleccionadas
    for (final loteria in _loteriasMultiples) {
      for (final num in combinaciones) {
        final error = _validarLimite(num, loteria, monto);
        if (error != null) { _snack(error, error: true); return; }
      }
    }

    // Agregar pales para cada lotería seleccionada
    setState(() {
      for (final loteria in _loteriasMultiples) {
        for (final num in combinaciones) {
          _jugadas.add(Jugada(
            numero: num,
            loteria: loteria,
            comb: detectarComb(num),
            forma: 'Fijo',
            monto: monto,
            ligada: true,
          ));
        }
      }
      _numeroCtrl.clear();
      _montoCtrl.clear();
      _combDetectada = '---';
      _modoLiga = false;
    });

    final totalJugadas = combinaciones.length * _loteriasMultiples.length;
    _snack('$totalJugadas pale${totalJugadas != 1 ? "s" : ""} agregado${totalJugadas != 1 ? "s" : ""} en ${_loteriasMultiples.length} lotería${_loteriasMultiples.length != 1 ? "s" : ""}');
  }


  void _eliminarJugada(int i) => setState(() => _jugadas.removeAt(i));

  void _editarJugada(int index) {
    final j       = _jugadas[index];
    final numCtrl = TextEditingController(text: j.numero);
    final monCtrl = TextEditingController(text: j.monto.toStringAsFixed(0));
    final disponibles = {..._loteriasAbiertas, j.loteria}.toList()..sort();
    String loteria = disponibles.contains(j.loteria) ? j.loteria : disponibles.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Editar jugada',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(controller: numCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: inputDeco('Número')),
            const SizedBox(height: 12),
            TextField(controller: monCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: inputDeco('Monto RD\$')),
            const SizedBox(height: 12),
            dropdownEdit('Lotería', loteria, disponibles,
                (v) => setModal(() => loteria = v)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final n = numCtrl.text.trim();
                  final m = double.tryParse(monCtrl.text.trim());
                  if (n.isEmpty || m == null || m <= 0) {
                    _snack('Datos inválidos', error: true); return;
                  }
                  // Validar límite en edición
                  final sinActual = List<Jugada>.from(_jugadas)..removeAt(index);
                  final acum = sinActual
                      .where((j) => j.numero == n && j.loteria == loteria)
                      .fold(0.0, (s, j) => s + j.monto);
                  if (acum + m > _limiteNumero) {
                    final disp = _limiteNumero - acum;
                    _snack(
                      disp <= 0
                        ? 'El $n en $loteria ya llegó al límite de RD\$${_limiteNumero.toStringAsFixed(0)}'
                        : 'Solo puedes poner RD\$${disp.toStringAsFixed(0)} al $n en $loteria',
                      error: true,
                    );
                    return;
                  }
                  setState(() {
                    _jugadas[index] = _jugadas[index].copyWith(
                        numero: n, comb: detectarComb(n),
                        loteria: loteria, monto: m);
                  });
                  Navigator.pop(ctx);
                  _snack('Jugada actualizada');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('Guardar cambios',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Copiar jugadas a otra lotería ──────────────────────────────────────────
  void _mostrarDialogoCopiar() {
    if (_jugadas.isEmpty) { _snack('No hay jugadas para copiar', error: true); return; }
    final usadas = _jugadas.map((j) => j.loteria).toSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SelectorCopiarLoterias(
        loteriasAbiertas: _loteriasAbiertas,
        loteriasConJugadas: usadas,
        horarios: _horarios,
        onConfirm: (loterias) => _copiarJugadasA(loterias),
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _copiarJugadasA(List<String> destinos) {
    // Obtener jugadas únicas (número + comb + monto)
    final jugadasUnicas = <String, Jugada>{};
    for (final j in _jugadas) {
      final key = '${j.numero}|${j.comb}|${j.monto}';
      jugadasUnicas[key] = j;
    }

    // Validar límites para todas las combinaciones
    for (final j in jugadasUnicas.values) {
      for (final destino in destinos) {
        final error = _validarLimite(j.numero, destino, j.monto);
        if (error != null) { _snack(error, error: true); return; }
      }
    }

    // Copiar a todas las loterías seleccionadas
    final copias = <Jugada>[];
    for (final j in jugadasUnicas.values) {
      for (final destino in destinos) {
        copias.add(j.copyWith(loteria: destino));
      }
    }

    setState(() => _jugadas.addAll(copias));
    _snack('${copias.length} jugada${copias.length != 1 ? "s" : ""} copiadas a ${destinos.length} ${destinos.length != 1 ? "loterias" : "loteria"}');
    _montoFocus.requestFocus();
  }

  // ── Guardar e imprimir directo ─────────────────────────────────────────────
  Future<void> _guardarTicket() async {
    if (_jugadas.isEmpty) { _snack('Agrega al menos una jugada', error: true); return; }
    if (_guardando || _imprimiendo) { _snack('Operación en curso...', error: true); return; }

    setState(() => _guardando = true);
    try {
      // Guardar en Firestore
      final ticketId    = await TicketService.guardar(_jugadas);
      final jugadasCopy = List<Jugada>.from(_jugadas);
      final totalCopy   = _total;

      if (!mounted) return;
      setState(() => _jugadas = []);

      // Preparar texto para impresión
      final texto = formatearTicket(ticketId, jugadasCopy, totalCopy);

      // Intentar imprimir si impresora está conectada
      if (BluetoothPrinterService.conectado &&
          await BluetoothPrinterService.estaConectado()) {
        setState(() => _imprimiendo = true);
        try {
          final ok = await BluetoothPrinterService.imprimir(texto);
          _snack(ok ? 'Ticket guardado e impreso' : 'Guardado — error al imprimir',
              error: !ok);
        } catch (_) {
          _snack('Guardado — error de impresión', error: true);
        } finally {
          if (mounted) setState(() => _imprimiendo = false);
        }
      } else {
        _snack('Ticket guardado (sin impresora conectada)');
      }
      await _verificarImpresora();
    } catch (_) {
      _snack('Error al guardar ticket', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Confirmación salida ────────────────────────────────────────────────────
  Future<bool> _confirmarSalida() async {
    if (_jugadas.isEmpty) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Salir sin guardar?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Tienes ${_jugadas.length} jugada${_jugadas.length != 1 ? "s" : ""} sin guardar. Si sales, se perderán.',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF818CF8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return salir ?? false;
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH  = MediaQuery.of(context).size.height;
    final tecladoH = screenH < 700 ? 36.0 : 42.0;
    final fontSize = screenH < 700 ? 14.0 : 16.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await _confirmarSalida();
        if (salir && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          elevation: 0,
          titleSpacing: 12,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final salir = await _confirmarSalida();
              if (salir && mounted) Navigator.of(context).pop();
            },
          ),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nueva venta',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            Row(children: [
              Text('BAL. RD\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 11)),
              const SizedBox(width: 8),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _impresoraConectada
                      ? const Color(0xFF34D399)
                      : const Color(0xFFEF4444),
                ),
              ),
            ]),
          ]),
          actions: [
            if (_jugadas.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF818CF8), size: 20),
                tooltip: 'Copiar a otra lotería',
                onPressed: _mostrarDialogoCopiar,
              ),
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 22),
              onPressed: () => mostrarDialogoBuscar(context, _snack),
            ),
            if (_jugadas.isNotEmpty)
              TextButton.icon(
                onPressed: _guardando ? null : _guardarTicket,
                icon: _guardando
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, color: Color(0xFF34D399), size: 18),
                label: Text(_guardando ? '...' : 'Guardar',
                    style: const TextStyle(
                        color: Color(0xFF34D399), fontWeight: FontWeight.w600, fontSize: 13)),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: VenderTabla(
                jugadas:    _jugadas,
                total:      _total,
                onEditar:   _editarJugada,
                onEliminar: _eliminarJugada,
              ),
            ),
            VenderPanel(
              numero:           _numeroCtrl.text,
              montoCtrl:        _montoCtrl,
              montoFocus:       _montoFocus,
              combDetectada:    _combDetectada,
              modoLiga:         _modoLiga,
              loteria:          _loteria,
              loteriasMultiples: _loteriasMultiples,
              horarios:         _horarios,
              tecladoH:         tecladoH,
              fontSize:         fontSize,
              hayJugadas:       _jugadas.isNotEmpty,
              onTecla:          _onTecla,
              onCambiarLoteria: (v) => setState(() => _loteria = v),
              onCambiarLoteriasMultiples: (v) => setState(() => _loteriasMultiples = v),
              onCopiar:         _mostrarDialogoCopiar,
            ),
          ]),
        ),
      ),
    );
  }
}
