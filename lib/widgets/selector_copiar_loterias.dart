import 'package:flutter/material.dart';
import '../services/horario_service.dart';

class SelectorCopiarLoterias extends StatefulWidget {
  final List<String> loteriasAbiertas;
  final Set<String> loteriasConJugadas;
  final Map<String, HorarioLoteria> horarios;
  final void Function(List<String>) onConfirm;
  final VoidCallback onCancel;

  const SelectorCopiarLoterias({
    super.key,
    required this.loteriasAbiertas,
    required this.loteriasConJugadas,
    required this.horarios,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SelectorCopiarLoterias> createState() => _SelectorCopiarLoteriasState();
}

class _SelectorCopiarLoteriasState extends State<SelectorCopiarLoterias> {
  late List<String> _seleccionadas;
  late List<String> _disponibles;

  @override
  void initState() {
    super.initState();
    _seleccionadas = [];
    // Mostrar solo loterías que no tienen las mismas jugadas
    _disponibles = widget.loteriasAbiertas
        .where((l) => !widget.loteriasConJugadas.contains(l))
        .toList();
  }

  static String _fmtHora(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  void _toggleLoteria(String loteria) {
    setState(() {
      if (_seleccionadas.contains(loteria)) {
        _seleccionadas.remove(loteria);
      } else {
        _seleccionadas.add(loteria);
      }
    });
  }

  void _seleccionarTodas() {
    setState(() => _seleccionadas = List.from(_disponibles));
  }

  void _limpiarSeleccion() {
    setState(() => _seleccionadas.clear());
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.copy_all_rounded,
                    color: Color(0xFF818CF8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Copiar jugadas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _disponibles.isEmpty
                            ? 'No hay loterías disponibles'
                            : 'Selecciona dónde copiar',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mensaje si no hay loterías disponibles
            if (_disponibles.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6B7280).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF9CA3AF),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Todas las loterías abiertas ya tienen estas jugadas',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Opciones de seleccionar/limpiar
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _seleccionarTodas,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        child: Text(
                          'Seleccionar todas',
                          style: TextStyle(
                            color: const Color(0xFF818CF8),
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '•',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _limpiarSeleccion,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        child: Text(
                          'Limpiar',
                          style: TextStyle(
                            color: const Color(0xFFEF4444),
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                height: 1,
                color: Colors.white.withOpacity(0.08),
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),

              // Lista de loterías
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 300,
                  minWidth: double.infinity,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loterías disponibles
                      ..._disponibles.map((loteria) {

                        final seleccionada = _seleccionadas.contains(loteria);
                        final h = widget.horarios[loteria];
                        final minutos = h?.minutosParaCerrar() ?? 999;
                        final pronto = minutos <= 15;

                        return GestureDetector(
                          onTap: () => _toggleLoteria(loteria),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 0,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: seleccionada
                                        ? const Color(0xFF4F46E5)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: seleccionada
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF6B7280),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: seleccionada
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loteria,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmall ? 12 : 13,
                                          fontWeight: seleccionada
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (h != null)
                                        Text(
                                          pronto
                                              ? 'cierra en ${minutos}m'
                                              : 'hasta ${_fmtHora(h.cierraHora, h.cierraMinuto)}',
                                          style: TextStyle(
                                            color: pronto
                                                ? const Color(0xFFFBBF24)
                                                : const Color(0xFF6B7280),
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: pronto
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // Separador
                      if (widget.loteriasConJugadas.isNotEmpty)
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.08),
                          margin: const EdgeInsets.symmetric(vertical: 12),
                        ),

                      // Loterías con jugadas ya incluidas (deshabilitadas)
                      ...widget.loteriasConJugadas.toList().map((loteria) {
                        final h = widget.horarios[loteria];
                        final minutos = h?.minutosParaCerrar() ?? 999;
                        final pronto = minutos <= 15;

                        return GestureDetector(
                          onTap: null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 0,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34D399)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFF34D399)
                                          .withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Color(0xFF34D399),
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loteria,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: isSmall ? 12 : 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'ya incluida',
                                        style: TextStyle(
                                          color: const Color(0xFF34D399)
                                              .withOpacity(0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: pronto
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Botones
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A2E),
                      foregroundColor: const Color(0xFF818CF8),
                      side: BorderSide(
                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _seleccionadas.isEmpty ? null : () {
                      Navigator.pop(context);
                      widget.onConfirm(_seleccionadas);
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    label: Text(
                      'Copiar a ${_seleccionadas.isEmpty ? "..." : _seleccionadas.length} ${_seleccionadas.length != 1 ? "loterías" : "lotería"}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF4F46E5).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
