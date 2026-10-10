import 'package:flutter/material.dart';
import '../services/horario_service.dart';

class SelectorLoteriasMultiple extends StatefulWidget {
  final List<String> valoresSeleccionados;
  final List<String> opciones;
  final Map<String, HorarioLoteria> horarios;
  final void Function(List<String>) onChange;

  const SelectorLoteriasMultiple({
    super.key,
    required this.valoresSeleccionados,
    required this.opciones,
    required this.horarios,
    required this.onChange,
  });

  @override
  State<SelectorLoteriasMultiple> createState() => _SelectorLoteriasMultipleState();
}

class _SelectorLoteriasMultipleState extends State<SelectorLoteriasMultiple> {
  late List<String> _seleccionadas;
  bool _desplegado = false;

  @override
  void initState() {
    super.initState();
    _seleccionadas = List.from(widget.valoresSeleccionados);
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
    widget.onChange(_seleccionadas);
  }

  void _seleccionarTodas() {
    setState(() => _seleccionadas = List.from(widget.opciones));
    widget.onChange(_seleccionadas);
  }

  void _limpiarSeleccion() {
    setState(() => _seleccionadas.clear());
    widget.onChange(_seleccionadas);
  }

  String _obtenerResumen() {
    if (_seleccionadas.isEmpty) return 'Seleccionar loterías';
    if (_seleccionadas.length == 1) return _seleccionadas.first;
    if (_seleccionadas.length == widget.opciones.length) return 'Todas las loterías';
    return '${_seleccionadas.length} loterías';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _desplegado
              ? const Color(0xFF4F46E5)
              : Colors.white.withOpacity(0.08),
          width: _desplegado ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _desplegado = !_desplegado),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 10 : 12,
                vertical: isSmall ? 10 : 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _obtenerResumen(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _desplegado
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF6B7280),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_desplegado) ...[
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isSmall ? 8 : 10,
                isSmall ? 8 : 10,
                isSmall ? 8 : 10,
                isSmall ? 8 : 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      const Text('•',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          )),
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
                    constraints: BoxConstraints(
                      maxHeight: 250,
                      minWidth: double.infinity,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.opciones.map((loteria) {
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
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
