// ─── widgets/vender_panel.dart ────────────────────────────────────────────────
// Panel inferior: display de número/monto + selector de lotería + teclado

import 'package:flutter/material.dart';
import '../services/horario_service.dart';
import 'teclado_widget.dart';
import 'tabla_widgets.dart';
import 'selector_loterias_multiple.dart';

class VenderPanel extends StatelessWidget {
  final String   numero;
  final TextEditingController montoCtrl;   // ← controller real
  final FocusNode             montoFocus;  // ← focus real
  final String   combDetectada;
  final bool     modoLiga;
  final String?  loteria;
  final List<String> loteriasMultiples;
  final Map<String, HorarioLoteria> horarios;
  final double   tecladoH;
  final double   fontSize;
  final bool     hayJugadas;

  final void Function(String) onTecla;
  final void Function(String) onCambiarLoteria;
  final void Function(List<String>) onCambiarLoteriasMultiples;
  final VoidCallback?          onCopiar;

  const VenderPanel({
    super.key,
    required this.numero,
    required this.montoCtrl,
    required this.montoFocus,
    required this.combDetectada,
    required this.modoLiga,
    required this.loteria,
    required this.loteriasMultiples,
    required this.horarios,
    required this.tecladoH,
    required this.fontSize,
    required this.hayJugadas,
    required this.onTecla,
    required this.onCambiarLoteria,
    required this.onCambiarLoteriasMultiples,
    this.onCopiar,
  });

  List<String> get _todasLasLoterias => horarios.keys.toList()..sort();

  List<String> get _loteriasAbiertas => _todasLasLoterias
      .where((l) => horarios[l]?.estaAbierta() ?? true)
      .toList();

  @override
  Widget build(BuildContext context) {
    final abiertas = _loteriasAbiertas;
    final cerradas = _todasLasLoterias.where((l) => !abiertas.contains(l)).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.15)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      child: Column(children: [
        if (abiertas.isEmpty)
          _BannerSinLoterias(horarios: horarios)
        else ...[
          _InputRow(
            numero:        numero,
            montoCtrl:     montoCtrl,
            montoFocus:    montoFocus,
            combDetectada: combDetectada,
            modoLiga:      modoLiga,
            fontSize:      fontSize,
          ),
          const SizedBox(height: 8),
          _SelectorRow(
            loteria:          loteria,
            loteriasMultiples: loteriasMultiples,
            abiertas:         abiertas,
            cerradas:         cerradas,
            horarios:         horarios,
            onCambiarLoteria: onCambiarLoteria,
            onCambiarLoteriasMultiples: onCambiarLoteriasMultiples,
          ),
          const SizedBox(height: 8),
          TecladoWidget(
            altura:       tecladoH,
            modoLiga:     modoLiga,
            montoFocused: montoFocus.hasFocus,
            onTecla:      onTecla,
            onCopiar:     hayJugadas ? onCopiar : null,
          ),
        ],
      ]),
    );
  }
}

// ── Display número + monto ────────────────────────────────────────────────────
class _InputRow extends StatelessWidget {
  final String numero, combDetectada;
  final TextEditingController montoCtrl;
  final FocusNode             montoFocus;
  final bool   modoLiga;
  final double fontSize;

  const _InputRow({
    required this.numero,
    required this.montoCtrl,
    required this.montoFocus,
    required this.combDetectada,
    required this.modoLiga,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        // Display número
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: modoLiga
                      ? const Color(0xFF34D399).withOpacity(0.6)
                      : const Color(0xFF4F46E5).withOpacity(0.5),
                ),
              ),
              child: Text(
                numero.isEmpty ? '#' : numero,
                style: TextStyle(
                  color: numero.isEmpty
                      ? const Color(0xFF374151)
                      : modoLiga
                          ? const Color(0xFF34D399)
                          : Colors.white,
                  fontSize: fontSize + 4,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(children: [
              Flexible(
                child: _Badge(text: combDetectada, color: colorComb(combDetectada)),
              ),
              if (modoLiga) ...[
                const SizedBox(width: 4),
                const _Badge(text: 'LIGA', color: Color(0xFF34D399)),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        // Campo monto — TextField real con el FocusNode del screen
        Expanded(
          flex: 3,
          child: TextField(
            controller:   montoCtrl,
            focusNode:    montoFocus,
            keyboardType: TextInputType.none, // teclado custom
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: montoFocus.hasFocus ? FontWeight.w700 : FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText:  'RD\$0.00',
              hintStyle: const TextStyle(color: Color(0xFF374151)),
              filled:    true,
              fillColor: const Color(0xFF0D0D0D),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF34D399), width: 1.5)),
            ),
          ),
        ),
      ]);
}

// ── Selector de lotería + chip cerradas ───────────────────────────────────────
class _SelectorRow extends StatelessWidget {
  final String?  loteria;
  final List<String> loteriasMultiples;
  final List<String> abiertas;
  final int      cerradas;
  final Map<String, HorarioLoteria> horarios;
  final void Function(String) onCambiarLoteria;
  final void Function(List<String>) onCambiarLoteriasMultiples;

  const _SelectorRow({
    required this.loteria,
    required this.loteriasMultiples,
    required this.abiertas,
    required this.cerradas,
    required this.horarios,
    required this.onCambiarLoteria,
    required this.onCambiarLoteriasMultiples,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: SelectorLoteriasMultiple(
          valoresSeleccionados: loteriasMultiples,
          opciones: abiertas,
          horarios: horarios,
          onChange: onCambiarLoteriasMultiples,
        ),
      ),
      if (cerradas > 0) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 11),
            const SizedBox(width: 4),
            Text('$cerradas',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
    ]);
  }
}

// ── Banner sin loterías ───────────────────────────────────────────────────────
class _BannerSinLoterias extends StatelessWidget {
  final Map<String, HorarioLoteria> horarios;
  const _BannerSinLoterias({required this.horarios});

  @override
  Widget build(BuildContext context) {
    String proxima = '';
    int menorDiff  = 9999;
    for (final e in horarios.entries) {
      final h     = e.value;
      final ahora = DateTime.now();
      final abre  = h.abreHora * 60 + h.abreMinuto;
      final now   = ahora.hour * 60 + ahora.minute;
      final diff  = abre > now ? abre - now : (24 * 60 - now + abre);
      if (diff < menorDiff) {
        menorDiff = diff;
        proxima   = '${e.key} abre a las '
            '${h.abreHora.toString().padLeft(2, '0')}:'
            '${h.abreMinuto.toString().padLeft(2, '0')}';
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_clock, color: Color(0xFF6B7280), size: 26),
        ),
        const SizedBox(height: 12),
        const Text('No hay loterías disponibles',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          proxima.isNotEmpty ? proxima : 'Revisa los horarios',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color  color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}
