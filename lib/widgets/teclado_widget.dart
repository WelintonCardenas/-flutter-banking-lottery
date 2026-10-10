// ─── widgets/teclado_widget.dart ─────────────────────────────────────────────

import 'package:flutter/material.dart';

class TecladoWidget extends StatelessWidget {
  final double altura;
  final bool   modoLiga;
  final bool   montoFocused;
  final bool   bloqueado;
  final void Function(String) onTecla;
  // Callback para el botón copiar — si es null no se muestra
  final VoidCallback? onCopiar;

  const TecladoWidget({
    super.key,
    required this.altura,
    required this.modoLiga,
    required this.montoFocused,
    required this.onTecla,
    this.bloqueado = false,
    this.onCopiar,
  });

  static const _teclas = [
    ['1', '2', '3', '←'],
    ['4', '5', '6', 'Enter'],
    ['7', '8', '9', ''],
    ['./', '0', 'C', 'COPY'],
  ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: bloqueado ? 0.35 : 1.0,
      child: IgnorePointer(
        ignoring: bloqueado,
        child: Column(
          children: _teclas.map((fila) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: fila.map((key) {
                  if (key.isEmpty) return const Expanded(child: SizedBox());

                  final esEnter  = key == 'Enter';
                  final esBorrar = key == '←';
                  final esLiga   = key == './';
                  final esC      = key == 'C';
                  final esCopy   = key == 'COPY';

                  Color bgColor;
                  if (esEnter) {
                    bgColor = montoFocused
                        ? const Color(0xFF059669)
                        : const Color(0xFF1E3A5F);
                  } else if (esBorrar) {
                    bgColor = const Color(0xFF7F1D1D).withOpacity(0.5);
                  } else if (esLiga) {
                    bgColor = modoLiga
                        ? const Color(0xFF34D399)
                        : const Color(0xFF374151);
                  } else if (esC) {
                    bgColor = const Color(0xFF374151);
                  } else if (esCopy) {
                    bgColor = onCopiar != null
                        ? const Color(0xFF4F46E5).withOpacity(0.7)
                        : const Color(0xFF1F2937);
                  } else {
                    bgColor = const Color(0xFF0D1117);
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: SizedBox(
                        height: altura,
                        child: esCopy
                            ? ElevatedButton(
                                onPressed: onCopiar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: bgColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                        color: Colors.white.withOpacity(0.06)),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.copy_all_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () => onTecla(key),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: bgColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                        color: Colors.white.withOpacity(0.06)),
                                  ),
                                ),
                                child: Text(
                                  esEnter
                                      ? (montoFocused ? 'Agregar' : 'Enter')
                                      : key,
                                  style: TextStyle(
                                    fontSize: esEnter ? 11 : 15,
                                    fontWeight: esEnter || esLiga
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: esLiga && modoLiga
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
