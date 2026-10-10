import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/jugada.dart';
import '../services/ticket_service.dart';
import '../services/horario_service.dart';
import '../utils/ticket_formatter_origin.dart';
import 'tabla_widgets.dart';
import 'bluetooth_modal.dart';

// ─── Vista previa e impresión ─────────────────────────────────────────────────
void mostrarImprimir(
  BuildContext context,
  String ticketId,
  List<Jugada> jugadas,
  double total,
  void Function(String) snack,
) {
  final texto = formatearTicket(ticketId, jugadas, total);

  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.print_outlined, color: Color(0xFF818CF8), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Vista previa del ticket',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Color(0xFF6B7280), size: 20),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Text(texto,
                  style: const TextStyle(
                      color: Colors.black, fontFamily: 'monospace', fontSize: 12, height: 1.6)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: texto));
                  snack('Ticket copiado');
                },
                icon: const Icon(Icons.copy, color: Color(0xFF6B7280), size: 16),
                label: const Text('Copiar', style: TextStyle(color: Color(0xFF6B7280))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  imprimirConBluetooth(context: context, textoTicket: texto, onSnack: snack);
                },
                icon: const Icon(Icons.bluetooth, color: Colors.white, size: 18),
                label: const Text('Imprimir',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
}

// ─── Modal post-guardado ──────────────────────────────────────────────────────
void mostrarOpcionesPostGuardado(
  BuildContext context,
  String ticketId,
  List<Jugada> jugadas,
  double total,
  void Function(String) snack,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Ticket guardado',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4)),
            ),
            child: Text(ticketId,
                style: const TextStyle(
                    color: Color(0xFF818CF8), fontWeight: FontWeight.w700,
                    fontSize: 13, letterSpacing: 1)),
          ),
          const SizedBox(height: 6),
          Text('${jugadas.length} jugadas  ·  RD\$${total.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                final texto = formatearTicket(ticketId, jugadas, total);
                imprimirConBluetooth(context: context, textoTicket: texto, onSnack: snack);
              },
              icon: const Icon(Icons.bluetooth, color: Colors.white, size: 20),
              label: const Text('Imprimir ticket',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.add, color: Color(0xFF34D399), size: 20),
              label: const Text('Nuevo ticket',
                  style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w600, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF34D399).withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ─── Modal resumen / edición de ticket ───────────────────────────────────────
void mostrarResumen(
  BuildContext context,
  String ticketId,
  List<Jugada> jugadas,
  double total,
  void Function(String) snack, {
  bool editable = false,
  String? docId,
  // Loterías abiertas para poder copiar (opcional)
  List<String> loteriasAbiertas = const [],
}) {
  final editables = List<Jugada>.from(jugadas);

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setModal) {
        final totalModal = editables.fold<double>(0, (s, j) => s + j.monto);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scroll) => Column(children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.receipt_long, color: Color(0xFF818CF8), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ticketId,
                        style: const TextStyle(
                            color: Color(0xFF818CF8), fontWeight: FontWeight.w700,
                            fontSize: 13, letterSpacing: 1)),
                    Text('${editables.length} jugadas',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Color(0xFF6B7280), size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(
                        text: formatearTicket(ticketId, editables, totalModal)));
                    snack('Ticket copiado');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bluetooth, color: Color(0xFF4F46E5), size: 20),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final texto = formatearTicket(ticketId, editables, totalModal);
                    imprimirConBluetooth(context: context, textoTicket: texto, onSnack: snack);
                  },
                ),
                if (editable && docId != null)
                  IconButton(
                    icon: const Icon(Icons.save_outlined, color: Color(0xFF34D399), size: 20),
                    onPressed: () async {
                      await TicketService.actualizar(docId, editables);
                      snack('Ticket actualizado');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ]),
            ),

            Divider(color: Colors.white.withOpacity(0.06), height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: const [
                ColHeader('Núm.',    flex: 2),
                ColHeader('Lotería', flex: 3),
                ColHeader('Tipo',    flex: 3),
                ColHeader('Forma',   flex: 2),
                ColHeader('Monto',   flex: 2),
                SizedBox(width: 48),
              ]),
            ),
            Divider(color: Colors.white.withOpacity(0.05), height: 8),

            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: editables.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.white.withOpacity(0.04), height: 1),
                itemBuilder: (_, i) {
                  final j = editables[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      ColCell(j.numero, flex: 2, color: const Color(0xFF818CF8), bold: true),
                      ColCell(j.loteria, flex: 3),
                      ColCell(j.comb, flex: 3, color: colorComb(j.comb)),
                      ColCell(j.forma, flex: 2),
                      ColCell('RD\$${j.monto.toStringAsFixed(0)}',
                          flex: 2, color: const Color(0xFF34D399), bold: true),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (editable)
                          GestureDetector(
                            onTap: () => _editarJugadaModal(
                                context, i, editables, setModal, snack),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.edit_outlined,
                                  color: Color(0xFF4F46E5), size: 15),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => setModal(() => editables.removeAt(i)),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, color: Color(0xFF6B7280), size: 15),
                          ),
                        ),
                      ]),
                    ]),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(color: Color(0xFF6B7280))),
                    Text('RD\$${totalModal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cerrar',
                          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final texto = formatearTicket(ticketId, editables, totalModal);
                        imprimirConBluetooth(context: context, textoTicket: texto, onSnack: snack);
                      },
                      icon: const Icon(Icons.bluetooth, color: Colors.white, size: 18),
                      label: const Text('Imprimir',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        );
      },
    ),
  );
}

// ─── Modal editar jugada ──────────────────────────────────────────────────────
void _editarJugadaModal(
  BuildContext context,
  int index,
  List<Jugada> lista,
  StateSetter setModal,
  void Function(String) snack,
) {
  final j       = lista[index];
  final numCtrl = TextEditingController(text: j.numero);
  final monCtrl = TextEditingController(text: j.monto.toStringAsFixed(0));
  String loteria = j.loteria;
  String forma   = j.forma;

  const loterias = ['Nacional', 'Leidsa', 'Real', 'Loteka', 'Anguila', 'NY'];
  const formas   = ['Fijo', 'Corrido', 'Ambos'];

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Editar jugada',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: numCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: inputDeco('Número'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: monCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: inputDeco('Monto RD\$'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: dropdownEdit('Lotería', loteria, loterias,
                  (v) => setDialog(() => loteria = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: dropdownEdit('Forma', forma, formas,
                  (v) => setDialog(() => forma = v)),
            ),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevoNum   = numCtrl.text.trim();
              final nuevoMonto = double.tryParse(monCtrl.text.trim());
              if (nuevoNum.isEmpty || nuevoMonto == null) return;
              setModal(() {
                lista[index] = lista[index].copyWith(
                  numero:  nuevoNum,
                  comb:    _detectarCombFromModel(nuevoNum),
                  loteria: loteria,
                  forma:   forma,
                  monto:   nuevoMonto,
                );
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

String _detectarCombFromModel(String numero) {
  final limpio = numero.replaceAll(RegExp(r'[^0-9]'), '');
  if (limpio.length == 2) return 'Quiniela';
  if (limpio.length == 4) return 'Pale';
  if (limpio.length == 6) return 'Tripleta';
  return '---';
}

// ─── Dialog buscar ticket + copiar a otra lotería ─────────────────────────────
void mostrarDialogoBuscar(
  BuildContext context,
  void Function(String) snack,
) {
  final ctrl = TextEditingController();

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setDialog) {
        bool buscando = false;

        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Buscar ticket',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Ingresa los últimos 4 dígitos del ticket',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: Colors.white, fontSize: 32,
                  fontWeight: FontWeight.w800, letterSpacing: 12),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '0000',
                hintStyle: const TextStyle(
                    color: Color(0xFF374151), fontSize: 32, letterSpacing: 12),
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
              ),
              onChanged: (v) {
                if (v.length == 4) FocusScope.of(ctx).unfocus();
              },
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: buscando
                  ? null
                  : () async {
                      final sufijo = ctrl.text.trim();
                      if (sufijo.length != 4) {
                        snack('Ingresa exactamente 4 dígitos');
                        return;
                      }
                      setDialog(() => buscando = true);
                      try {
                        final data = await TicketService.buscarPorSufijo(sufijo);
                        if (!ctx.mounted) return;

                        if (data == null) {
                          snack('Ticket no encontrado');
                          setDialog(() => buscando = false);
                          return;
                        }

                        final jugadas = (data['jugadas'] as List)
                            .map((j) => Jugada.fromMap(Map<String, dynamic>.from(j)))
                            .toList();
                        final ticketId = data['id'] as String;
                        final total    = (data['total'] as num).toDouble();

                        // Cerrar diálogo de búsqueda
                        Navigator.pop(ctx);

                        // Mostrar opciones: ver resumen O copiar a lotería
                        _mostrarOpcionesBuscado(
                          context,
                          ticketId: ticketId,
                          jugadas:  jugadas,
                          total:    total,
                          snack:    snack,
                        );
                      } catch (_) {
                        snack('Error al buscar ticket');
                        setDialog(() => buscando = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: buscando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Buscar'),
            ),
          ],
        );
      },
    ),
  );
}

// ─── Opciones tras encontrar el ticket ───────────────────────────────────────
void _mostrarOpcionesBuscado(
  BuildContext context, {
  required String ticketId,
  required List<Jugada> jugadas,
  required double total,
  required void Function(String) snack,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _OpcionesBuscadoSheet(
      ticketId: ticketId,
      jugadas:  jugadas,
      total:    total,
      snack:    snack,
    ),
  );
}

// ─── Sheet de opciones del ticket encontrado ─────────────────────────────────
class _OpcionesBuscadoSheet extends StatefulWidget {
  final String ticketId;
  final List<Jugada> jugadas;
  final double total;
  final void Function(String) snack;

  const _OpcionesBuscadoSheet({
    required this.ticketId,
    required this.jugadas,
    required this.total,
    required this.snack,
  });

  @override
  State<_OpcionesBuscadoSheet> createState() => _OpcionesBuscadoSheetState();
}

class _OpcionesBuscadoSheetState extends State<_OpcionesBuscadoSheet> {
  Map<String, HorarioLoteria> _horarios = {};
  String? _loteriaDestino;
  bool _copiando = false;

  List<String> get _loteriasAbiertas =>
      _horarios.entries
          .where((e) => e.value.estaAbierta())
          .map((e) => e.key)
          .toList()
        ..sort();

  @override
  void initState() {
    super.initState();
    _cargarHorarios();
  }

  Future<void> _cargarHorarios() async {
    final h = await HorarioService.cargarHorarios();
    if (!mounted) return;
    final abiertas = h.entries
        .where((e) => e.value.estaAbierta())
        .map((e) => e.key)
        .toList()
      ..sort();
    setState(() {
      _horarios        = h;
      _loteriaDestino  = abiertas.isNotEmpty ? abiertas.first : null;
    });
  }

  Future<void> _copiar() async {
    if (_loteriaDestino == null) return;
    setState(() => _copiando = true);
    try {
      // Duplicar jugadas con la nueva lotería
      final nuevasJugadas = widget.jugadas
          .map((j) => j.copyWith(loteria: _loteriaDestino!))
          .toList();

      // Guardar como ticket nuevo
      await TicketService.guardar(nuevasJugadas);

      if (!mounted) return;
      Navigator.pop(context);
      widget.snack('Ticket copiado a $_loteriaDestino');
    } catch (_) {
      widget.snack('Error al copiar ticket');
    } finally {
      if (mounted) setState(() => _copiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final abiertas = _loteriasAbiertas;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20, right: 20, top: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Encabezado ticket encontrado
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long,
                    color: Color(0xFF818CF8), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    widget.ticketId,
                    style: const TextStyle(
                        color: Color(0xFF818CF8), fontWeight: FontWeight.w700,
                        fontSize: 13, letterSpacing: 1),
                  ),
                  Text(
                    '${widget.jugadas.length} jugada${widget.jugadas.length != 1 ? 's' : ''} · '
                    'RD\$${widget.total.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
                ]),
              ),
              // Loterías únicas del ticket
              Wrap(
                spacing: 4,
                children: widget.jugadas.map((j) => j.loteria).toSet().map((l) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(l,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ).toList(),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Selector lotería destino
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Copiar a lotería',
                style: TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),

          if (_horarios.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Color(0xFF818CF8)),
              ),
            )
          else if (abiertas.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF374151).withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.lock_clock, color: Color(0xFF6B7280), size: 18),
                SizedBox(width: 8),
                Text('No hay loterías abiertas ahora',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _loteriaDestino,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280), size: 18),
                  items: abiertas.map((nombre) {
                    final h    = _horarios[nombre];
                    final mins = h?.minutosParaCerrar() ?? 999;
                    final pronto = mins <= 15;
                    return DropdownMenuItem(
                      value: nombre,
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pronto
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF34D399),
                          ),
                        ),
                        Expanded(
                          child: Text(nombre,
                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                        if (h != null)
                          Text(
                            pronto
                                ? 'cierra en ${mins}m'
                                : 'hasta ${h.cierraHora.toString().padLeft(2,'0')}:${h.cierraMinuto.toString().padLeft(2,'0')}',
                            style: TextStyle(
                                fontSize: 11,
                                color: pronto
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF6B7280)),
                          ),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) { if (v != null) setState(() => _loteriaDestino = v); },
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Botones
          Row(children: [
            // Ver resumen
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  mostrarResumen(
                    context,
                    widget.ticketId,
                    widget.jugadas,
                    widget.total,
                    widget.snack,
                    editable: true,
                    docId: widget.ticketId,
                  );
                },
                icon: const Icon(Icons.visibility_outlined,
                    color: Color(0xFF818CF8), size: 16),
                label: const Text('Ver ticket',
                    style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Copiar
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: (abiertas.isEmpty || _copiando) ? null : _copiar,
                icon: _copiando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.copy_all_rounded, color: Colors.white, size: 18),
                label: Text(
                  _copiando
                      ? 'Copiando...'
                      : _loteriaDestino != null
                          ? 'Copiar a $_loteriaDestino'
                          : 'Copiar',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: abiertas.isEmpty
                      ? const Color(0xFF374151)
                      : const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
