// ─── screens/admin_horarios_screen.dart ──────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/horario_service.dart';

String _fmt(int n) => n.toString().padLeft(2, '0');

class AdminHorariosScreen extends StatefulWidget {
  const AdminHorariosScreen({super.key});

  @override
  State<AdminHorariosScreen> createState() => _AdminHorariosScreenState();
}

class _AdminHorariosScreenState extends State<AdminHorariosScreen> {
  // ── Estado ────────────────────────────────────────────────────────────────
  Map<String, HorarioLoteria> _firebaseHorarios = {};
  final Map<String, HorarioLoteria> _pendientes  = {};
  final Set<String> _eliminados = {}; // claves eliminadas localmente

  bool _guardando  = false;
  bool _cargando   = true;

  StreamSubscription<Map<String, HorarioLoteria>>? _sub;

  // ── Vista combinada ───────────────────────────────────────────────────────
  Map<String, HorarioLoteria> get _horariosMostrados {
    final merged = Map<String, HorarioLoteria>.from(_firebaseHorarios);
    merged.removeWhere((k, _) => _eliminados.contains(k)); // quita eliminados
    merged.addAll(_pendientes);                             // sobreescribe con pendientes
    return merged;
  }

  bool get _hayPendientes => _pendientes.isNotEmpty;

  // ── Ciclo de vida ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _sub = HorarioService.streamHorarios().listen((data) {
      if (!mounted) return;
      setState(() {
        // Firebase actualiza siempre, pero no pisa eliminados ni pendientes
        _firebaseHorarios = data;
        _cargando = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Acciones ──────────────────────────────────────────────────────────────
  void _marcarPendiente(HorarioLoteria h) {
    setState(() => _pendientes[h.loteria] = h);
  }

  Future<void> _guardarTodo() async {
    if (_pendientes.isEmpty) return;
    setState(() => _guardando = true);
    try {
      await Future.wait(
        _pendientes.values.map((h) => HorarioService.guardarHorario(h)),
      );
      setState(() => _pendientes.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Todos los horarios guardados'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarDialogoNueva() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nueva lotería',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej: Loteka, NY, Anguila...',
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
            filled: true,
            fillColor: const Color(0xFF0D0D0D),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE11D48))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final nombre = ctrl.text.trim();
              if (nombre.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _eliminados.remove(nombre)); // por si se re-agrega
              _marcarPendiente(HorarioLoteria(
                loteria:      nombre,
                abreHora:     9,  abreMinuto:   0,
                cierraHora:   12, cierraMinuto: 30,
              ));
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminar(String loteria) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar lotería',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Eliminar "$loteria"?\nSi es una lotería por defecto volverá con el horario original.',
          style: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 1. Marcar como eliminado localmente → desaparece INMEDIATAMENTE de la UI
    setState(() {
      _eliminados.add(loteria);
      _pendientes.remove(loteria);
    });

    // 2. Borrar en Firebase en segundo plano
    try {
      await HorarioService.eliminarHorario(loteria);
      // 3. Una vez confirmado, quitar también del mapa de Firebase local
      if (mounted) {
        setState(() => _firebaseHorarios.remove(loteria));
      }
    } catch (e) {
      // Si falla, revertir la eliminación local
      if (mounted) {
        setState(() => _eliminados.remove(loteria));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$loteria" eliminada'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final sw       = mq.size.width;
    final sh       = mq.size.height;
    final isSmall  = sh < 700;
    final isNarrow = sw < 360;

    final titleSize = isNarrow ? 14.0 : 17.0;
    final pad       = isSmall  ? 12.0 : 16.0;
    final btnPad    = isSmall  ? 11.0 : 14.0;
    final diaSize   = isNarrow ? 30.0 : 36.0;

    final lista = _horariosMostrados.values.toList()
      ..sort((a, b) => a.loteria.compareTo(b.loteria));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Horarios de Loterías'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: Color(0xFFE11D48)),
            tooltip: 'Nueva lotería',
            onPressed: _mostrarDialogoNueva,
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF818CF8)))
          : Column(children: [

              // ── Aviso pendientes ───────────────────────────────────
              if (_hayPendientes)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  child: Row(children: [
                    const Icon(Icons.edit_note,
                        color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_pendientes.length} cambio${_pendientes.length != 1 ? 's' : ''} sin guardar',
                      style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),

              // ── Lista ──────────────────────────────────────────────
              Expanded(
                child: lista.isEmpty
                    ? const Center(
                        child: Text('No hay loterías',
                            style: TextStyle(color: Color(0xFF6B7280))))
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
                        itemCount: lista.length,
                        itemBuilder: (context, i) => _HorarioCard(
                          key:        ValueKey(lista[i].loteria),
                          horario:    lista[i],
                          isPendiente: _pendientes.containsKey(lista[i].loteria),
                          onChanged:  _marcarPendiente,
                          onEliminar: () => _eliminar(lista[i].loteria),
                          titleSize:  titleSize,
                          pad:        pad,
                          diaSize:    diaSize,
                        ),
                      ),
              ),

              // ── Botón guardar todo ─────────────────────────────────
              SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(pad, 10, pad, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withOpacity(0.08))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_guardando || !_hayPendientes) ? null : _guardarTodo,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_outlined,
                              size: 20),
                      label: Text(
                        _guardando
                            ? 'Guardando...'
                            : _hayPendientes
                                ? 'Guardar ${_pendientes.length} cambio${_pendientes.length != 1 ? 's' : ''} en Firebase'
                                : 'Sin cambios pendientes',
                        style: TextStyle(
                            fontSize: isSmall ? 13 : 15,
                            fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hayPendientes
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF374151),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: btnPad),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }
}

// ─── Card individual ──────────────────────────────────────────────────────────

class _HorarioCard extends StatefulWidget {
  final HorarioLoteria               horario;
  final bool                         isPendiente;
  final ValueChanged<HorarioLoteria> onChanged;
  final VoidCallback                 onEliminar;
  final double titleSize;
  final double pad;
  final double diaSize;

  const _HorarioCard({
    super.key,
    required this.horario,
    required this.isPendiente,
    required this.onChanged,
    required this.onEliminar,
    required this.titleSize,
    required this.pad,
    required this.diaSize,
  });

  @override
  State<_HorarioCard> createState() => _HorarioCardState();
}

class _HorarioCardState extends State<_HorarioCard> {
  late HorarioLoteria _h;
  static const _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _h = widget.horario;
  }

  @override
  void didUpdateWidget(_HorarioCard old) {
    super.didUpdateWidget(old);
    if (!widget.isPendiente) _h = widget.horario;
  }

  void _update(HorarioLoteria nuevo) {
    setState(() => _h = nuevo);
    widget.onChanged(nuevo);
  }

  Future<void> _seleccionarHora({required bool esApertura}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour:   esApertura ? _h.abreHora   : _h.cierraHora,
        minute: esApertura ? _h.abreMinuto : _h.cierraMinuto,
      ),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    _update(esApertura
        ? _h.copyWith(abreHora: picked.hour, abreMinuto: picked.minute)
        : _h.copyWith(cierraHora: picked.hour, cierraMinuto: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final abierta     = _h.estaAbierta();
    final statusColor = !_h.activo
        ? Colors.grey
        : abierta ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    final statusText  = !_h.activo
        ? 'Deshabilitada'
        : abierta ? 'Abierta ahora' : 'Cerrada';

    return Card(
      margin: EdgeInsets.only(bottom: widget.pad * 0.75),
      elevation: 2,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isPendiente
            ? const BorderSide(color: Color(0xFFF59E0B), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(_h.loteria,
                      style: TextStyle(
                          fontSize: widget.titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  if (widget.isPendiente) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('pendiente',
                          style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(statusText,
                      style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444), size: 20),
              tooltip: 'Eliminar',
              onPressed: widget.onEliminar,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            Column(children: [
              const Text('Activa',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _h.activo,
                  activeColor: const Color(0xFF2ECC71),
                  onChanged: (v) => _update(_h.copyWith(activo: v)),
                ),
              ),
            ]),
          ]),

          SizedBox(height: widget.pad * 0.6),
          Divider(height: 1, color: Colors.white.withOpacity(0.08)),
          SizedBox(height: widget.pad * 0.6),

          Row(children: [
            Expanded(
              child: _HoraTile(
                label: 'Apertura',
                hora:  '${_fmt(_h.abreHora)}:${_fmt(_h.abreMinuto)}',
                color: const Color(0xFF2ECC71),
                onTap: () => _seleccionarHora(esApertura: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HoraTile(
                label: 'Cierre',
                hora:  '${_fmt(_h.cierraHora)}:${_fmt(_h.cierraMinuto)}',
                color: const Color(0xFFE74C3C),
                onTap: () => _seleccionarHora(esApertura: false),
              ),
            ),
          ]),

          SizedBox(height: widget.pad * 0.75),

          const Text('Días activos',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(7, (i) {
              final dia    = i + 1;
              final activo = _h.diasSemana.contains(dia);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      final nuevos = List<int>.from(_h.diasSemana);
                      activo ? nuevos.remove(dia) : nuevos.add(dia);
                      nuevos.sort();
                      _update(_h.copyWith(diasSemana: nuevos));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: widget.diaSize,
                      decoration: BoxDecoration(
                        color: activo
                            ? const Color(0xFFE11D48)
                            : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(_dias[i],
                          style: TextStyle(
                              fontSize: widget.diaSize * 0.36,
                              fontWeight: FontWeight.bold,
                              color: activo ? Colors.white : Colors.grey)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

// ─── Tile de hora ─────────────────────────────────────────────────────────────

class _HoraTile extends StatelessWidget {
  final String label, hora;
  final Color color;
  final VoidCallback onTap;

  const _HoraTile({
    required this.label, required this.hora,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final horaSize = MediaQuery.of(context).size.width < 360 ? 15.0 : 18.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.access_time, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(hora,
                    style: TextStyle(
                        fontSize: horaSize,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
