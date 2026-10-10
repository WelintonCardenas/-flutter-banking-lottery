// ─── widgets/clientes_widgets.dart ───────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/resultado.dart';

// ── Franja de resultados ──────────────────────────────────────────────────────

class ResultadosStrip extends StatelessWidget {
  final List<Resultado> resultados;
  const ResultadosStrip({super.key, required this.resultados});

  static const _colores = {
    'nacional': Color(0xFF4F46E5),
    'leidsa':   Color(0xFF059669),
    'real':     Color(0xFFD97706),
    'loteka':   Color(0xFFDB2777),
    'anguila':  Color(0xFF0891B2),
    'ny':       Color(0xFF7C3AED),
  };

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        color: const Color(0xFF0D0D1F),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: resultados.length,
          separatorBuilder: (_, __) => Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withOpacity(0.08),
          ),
          itemBuilder: (_, i) {
            final r     = resultados[i];
            final color = _colores[r.loteria] ?? const Color(0xFF6B7280);
            return Row(children: [
              Text(r.loteriaDisplay,
                  style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              _NumPos(num: r.primero, pos: '1°', color: const Color(0xFFFBBF24)),
              if (r.segundo != null && r.segundo!.isNotEmpty) ...[
                const SizedBox(width: 4),
                _NumPos(num: r.segundo!, pos: '2°', color: const Color(0xFF818CF8)),
              ],
              if (r.tercero != null && r.tercero!.isNotEmpty) ...[
                const SizedBox(width: 4),
                _NumPos(num: r.tercero!, pos: '3°', color: const Color(0xFF34D399)),
              ],
            ]);
          },
        ),
      );
}

class _NumPos extends StatelessWidget {
  final String num, pos;
  final Color  color;
  const _NumPos({required this.num, required this.pos, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(pos,
              style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w600)),
          Text(num,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ],
      );
}

// ── Card resumen ──────────────────────────────────────────────────────────────

class ResumenCard extends StatelessWidget {
  final bool   soloHoy;
  final double totalDia;
  final int    totalTickets, ganadores;
  final double totalPremios;

  const ResumenCard({
    super.key,
    required this.soloHoy,
    required this.totalDia,
    required this.totalTickets,
    required this.ganadores,
    required this.totalPremios,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(soloHoy ? 'Vendido hoy' : 'Total vendido',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('RD\$${totalDia.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          _Div(),
          _Stat(label: 'Tickets', value: '$totalTickets', color: Colors.white),
          _Div(),
          _Stat(
            label: 'Ganadores',
            value: '$ganadores',
            color: ganadores > 0 ? const Color(0xFFEF4444) : Colors.white,
          ),
          if (totalPremios > 0) ...[
            _Div(),
            _Stat(
              label: 'Premios',
              value: 'RD\$${totalPremios.toStringAsFixed(0)}',
              color: const Color(0xFFEF4444),
              small: true,
            ),
          ],
        ]),
      );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 40,
      color: Colors.white.withOpacity(0.08),
      margin: const EdgeInsets.symmetric(horizontal: 10));
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color  color;
  final bool   small;
  const _Stat({required this.label, required this.value,
               required this.color, this.small = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: small ? 13 : 18,
                  fontWeight: FontWeight.w700)),
        ),
      ]);
}

// ── TicketCard ────────────────────────────────────────────────────────────────

class TicketCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final double       premio;
  final bool         puedeBorrar;
  final VoidCallback onTap;
  final VoidCallback onImprimir;
  final VoidCallback onBorrar;
  /// Permite forzar estado ganador desde fuera — útil para tickets históricos
  /// marcados con ganador:true en Firestore pero sin monto calculado en memoria.
  /// Si es null, se calcula internamente como premio > 0.
  final bool?        esGanador;

  const TicketCard({
    super.key,
    required this.data,
    required this.premio,
    required this.puedeBorrar,
    required this.onTap,
    required this.onImprimir,
    required this.onBorrar,
    this.esGanador,
  });

  @override
  Widget build(BuildContext context) {
    final id           = data['ticketId'] ?? '';
    final total        = (data['total'] as num).toDouble();
    final jugadasCount = (data['jugadas'] as List).length;
    final fecha        = data['fecha'] != null
        ? (data['fecha'] as Timestamp).toDate()
        : DateTime.now();

    // Usar valor externo si se provee, si no calcular por premio
    final esGan = esGanador ?? premio > 0;

    final hoy   = DateTime.now();
    final esHoy = fecha.year  == hoy.year  &&
                  fecha.month == hoy.month &&
                  fecha.day   == hoy.day;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: esGan
              ? const Color(0xFF7F1D1D).withOpacity(0.45)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: esGan
                ? const Color(0xFFEF4444).withOpacity(0.7)
                : Colors.white.withOpacity(esHoy ? 0.08 : 0.04),
            width: esGan ? 2 : 1,
          ),
        ),
        child: Row(children: [

          // Ícono
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: esGan
                  ? const Color(0xFFEF4444).withOpacity(0.25)
                  : const Color(0xFF4F46E5).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              esGan ? Icons.emoji_events : Icons.confirmation_number_outlined,
              color: esGan ? const Color(0xFFEF4444) : const Color(0xFF818CF8),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Texto
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(id,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  if (esGan)
                    BadgeTag(text: 'GANADOR',
                        color: const Color(0xFFEF4444), small: true),
                  if (!esHoy)
                    BadgeTag(text: 'HISTÓRICO',
                        color: const Color(0xFF6B7280), small: true),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$jugadasCount jugada${jugadasCount != 1 ? 's' : ''}  ·  '
                '${fecha.day.toString().padLeft(2, '0')}/'
                '${fecha.month.toString().padLeft(2, '0')}  '
                '${fecha.hour.toString().padLeft(2, '0')}:'
                '${fecha.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                    color: esGan
                        ? const Color(0xFFEF4444).withOpacity(0.7)
                        : const Color(0xFF6B7280),
                    fontSize: 11),
              ),
              // Mostrar premio solo si se calculó correctamente (> 0)
              if (esGan && premio > 0) ...[
                const SizedBox(height: 3),
                Text('Premio: RD\$${premio.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ]),
          ),

          // Monto + botones rápidos
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('RD\$${total.toStringAsFixed(2)}',
                style: TextStyle(
                    color: esGan
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF34D399),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: onImprimir,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.bluetooth,
                      color: Color(0xFF818CF8), size: 14),
                ),
              ),
              if (puedeBorrar) ...[
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: onBorrar,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Color(0xFFEF4444), size: 14),
                  ),
                ),
              ],
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ── Widgets pequeños ──────────────────────────────────────────────────────────

class BadgeTag extends StatelessWidget {
  final String text;
  final Color  color;
  final bool   small;
  const BadgeTag({super.key, required this.text,
                  required this.color, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 5 : 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: small ? 8 : 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)));
}

class EmptyState extends StatelessWidget {
  final bool soloHoy;
  const EmptyState({super.key, required this.soloHoy});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined,
              color: const Color(0xFF374151).withOpacity(0.5), size: 48),
          const SizedBox(height: 12),
          Text(
            soloHoy ? 'Sin tickets hoy' : 'Sin tickets registrados',
            style: const TextStyle(color: Color(0xFF374151), fontSize: 15)),
        ]),
      );
}

class ColH extends StatelessWidget {
  final String text;
  final int    flex;
  const ColH(this.text, {super.key, required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)));
}

class ColC extends StatelessWidget {
  final String text;
  final int    flex;
  final Color  color;
  final bool   bold;
  const ColC(this.text, {super.key, required this.flex,
             this.color = const Color(0xFFD1D5DB), this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)));
}
