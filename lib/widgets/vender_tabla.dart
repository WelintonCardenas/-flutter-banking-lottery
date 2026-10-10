// ─── widgets/vender_tabla.dart ────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/jugada.dart';
import 'tabla_widgets.dart';

class VenderTabla extends StatelessWidget {
  final List<Jugada>   jugadas;
  final double         total;
  final void Function(int) onEditar;
  final void Function(int) onEliminar;

  const VenderTabla({
    super.key,
    required this.jugadas,
    required this.total,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Cabecera ──────────────────────────────────────────────────────
      Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: const Row(children: [
          ColHeader('Núm.',    flex: 2),
          ColHeader('Lotería', flex: 3),
          ColHeader('Tipo',    flex: 4),
          ColHeader('Monto',   flex: 2),
          SizedBox(width: 40),
        ]),
      ),
      Divider(color: Colors.white.withOpacity(0.06), height: 1),

      // ── Filas ─────────────────────────────────────────────────────────
      Expanded(
        child: jugadas.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: const Color(0xFF374151).withOpacity(0.4),
                        size: 36),
                    const SizedBox(height: 8),
                    const Text('Sin jugadas',
                        style: TextStyle(color: Color(0xFF374151), fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: jugadas.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.white.withOpacity(0.04), height: 1),
                itemBuilder: (_, i) => _Fila(
                  jugada:    jugadas[i],
                  onEditar:  () => onEditar(i),
                  onEliminar: () => onEliminar(i),
                ),
              ),
      ),

      // ── Pie totales ───────────────────────────────────────────────────
      if (jugadas.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              '${jugadas.length} jugada${jugadas.length != 1 ? 's' : ''}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            Text('Total: RD\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }
}

class _Fila extends StatelessWidget {
  final Jugada       jugada;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _Fila({
    required this.jugada,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          ColCell(jugada.numero,
              flex: 2,
              color: jugada.ligada
                  ? const Color(0xFF34D399)
                  : const Color(0xFF818CF8),
              bold: true),
          ColCell(jugada.loteria, flex: 3),
          ColCell(jugada.comb, flex: 4, color: colorComb(jugada.comb)),
          ColCell('RD\$${jugada.monto.toStringAsFixed(0)}',
              flex: 2, color: const Color(0xFF34D399), bold: true),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: onEditar,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined, color: Color(0xFF4F46E5), size: 14),
              ),
            ),
            GestureDetector(
              onTap: onEliminar,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Color(0xFF6B7280), size: 14),
              ),
            ),
          ]),
        ]),
      );
}
