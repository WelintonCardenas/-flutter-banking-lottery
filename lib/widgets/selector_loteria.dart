// ─── widgets/selector_loteria.dart ───────────────────────────────────────────

import 'package:flutter/material.dart';
import '../services/horario_service.dart';

class SelectorLoteria extends StatelessWidget {
  final String       valor;
  final List<String> opciones;
  final Map<String, HorarioLoteria> horarios;
  final void Function(String) onChange;

  const SelectorLoteria({
    super.key,
    required this.valor,
    required this.opciones,
    required this.horarios,
    required this.onChange,
  });

  static String _fmtHora(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:         opciones.contains(valor) ? valor : opciones.first,
          isExpanded:    true,
          dropdownColor: const Color(0xFF1A1A2E),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF6B7280), size: 16),

          items: opciones.map((nombre) {
            final h       = horarios[nombre];
            final minutos = h?.minutosParaCerrar() ?? 999;
            final pronto  = minutos <= 15;
            return DropdownMenuItem<String>(
              value: nombre,
              child: Row(children: [
                Container(
                  width: 7, height: 7,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: pronto
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF34D399),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                if (h != null)
                  Text(
                    pronto
                        ? 'cierra en ${minutos}m'
                        : 'hasta ${_fmtHora(h.cierraHora, h.cierraMinuto)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: pronto
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF6B7280),
                    ),
                  ),
              ]),
            );
          }).toList(),

          selectedItemBuilder: (_) => opciones.map((nombre) {
            final h       = horarios[nombre];
            final minutos = h?.minutosParaCerrar() ?? 999;
            final pronto  = minutos <= 15;
            return Row(children: [
              Container(
                width: 7, height: 7,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: pronto
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF34D399),
                  shape: BoxShape.circle,
                ),
              ),
              Text(nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              if (pronto) ...[
                const SizedBox(width: 4),
                Text('${minutos}m',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10)),
              ],
            ]);
          }).toList(),

          onChanged: (v) { if (v != null) onChange(v); },
        ),
      ),
    );
  }
}
