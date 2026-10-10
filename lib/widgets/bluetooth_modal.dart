// ─── widgets/bluetooth_modal.dart ────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/bluetooth_printer_service.dart';

/// Punto de entrada principal — llama desde cualquier botón "Imprimir"
Future<void> imprimirConBluetooth({
  required BuildContext context,
  required String textoTicket,
  required void Function(String) onSnack,
}) async {
  // Si ya hay conexión activa → imprime directo
  if (BluetoothPrinterService.conectado) {
    final activo = await BluetoothPrinterService.estaConectado();
    if (activo) {
      await _ejecutarImpresion(context, textoTicket, onSnack);
      return;
    }
    // La conexión se perdió aunque _dispositivo no era null — limpiar
    await BluetoothPrinterService.desconectar();
  }

  // Sin conexión → mostrar modal de selección
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ModalSeleccion(
      textoTicket: textoTicket,
      onSnack:     onSnack,
    ),
  );
}

Future<void> _ejecutarImpresion(
  BuildContext context,
  String texto,
  void Function(String) onSnack,
) async {
  onSnack('Imprimiendo…');
  try {
    final ok = await BluetoothPrinterService.imprimir(texto);
    onSnack(ok ? 'Ticket impreso' : 'Error al imprimir — intenta de nuevo');
  } catch (_) {
    onSnack('Error al imprimir');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODAL DE SELECCIÓN
// ═══════════════════════════════════════════════════════════════════════════════

class _ModalSeleccion extends StatefulWidget {
  final String textoTicket;
  final void Function(String) onSnack;

  const _ModalSeleccion({
    required this.textoTicket,
    required this.onSnack,
  });

  @override
  State<_ModalSeleccion> createState() => _ModalSeleccionState();
}

class _ModalSeleccionState extends State<_ModalSeleccion> {
  List<BluetoothInfo> _dispositivos = [];
  bool   _cargando    = true;
  bool   _conectando  = false;
  String _conectandoA = '';
  String _error       = '';

  @override
  void initState() {
    super.initState();
    _cargarDispositivos();
  }

  Future<void> _cargarDispositivos() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = ''; });

    try {
      final habilitado = await BluetoothPrinterService.bluetoothHabilitado();
      if (!mounted) return;

      if (!habilitado) {
        setState(() {
          _cargando = false;
          _error    = 'Bluetooth desactivado.\nActívalo en Ajustes e intenta de nuevo.';
        });
        return;
      }

      final lista = await BluetoothPrinterService.obtenerPareados();
      if (!mounted) return;

      setState(() {
        _dispositivos = lista;
        _cargando     = false;
        if (lista.isEmpty) {
          _error = 'No hay impresoras Bluetooth pareadas.\n'
              'Ve a Ajustes → Bluetooth y paréa tu impresora primero.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error    = 'Error al buscar dispositivos.\nVerifica que el Bluetooth esté activo.';
      });
    }
  }

  Future<void> _seleccionar(BluetoothInfo dispositivo) async {
    if (!mounted) return;
    setState(() { _conectando = true; _conectandoA = dispositivo.name; });

    try {
      final ok = await BluetoothPrinterService.conectar(dispositivo);

      if (!mounted) return;

      if (!ok) {
        setState(() { _conectando = false; _conectandoA = ''; });
        widget.onSnack(
            '${dispositivo.name} no disponible — verifica que esté encendida');
        return;
      }

      // Conectado → imprimir
      bool impreso = false;
      try {
        impreso = await BluetoothPrinterService.imprimir(widget.textoTicket);
      } catch (_) {
        impreso = false;
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSnack(impreso
          ? 'Ticket impreso en ${dispositivo.name}'
          : 'Conectado pero error al imprimir — intenta de nuevo');

    } catch (_) {
      // Cualquier error inesperado — no romper la app
      if (!mounted) return;
      setState(() { _conectando = false; _conectandoA = ''; });
      await BluetoothPrinterService.desconectar();
      widget.onSnack('Error inesperado — intenta de nuevo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),

        // Título
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bluetooth,
                color: Color(0xFF818CF8), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seleccionar impresora',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text('Dispositivos Bluetooth pareados',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh,
                color: Color(0xFF6B7280), size: 20),
            onPressed: (_cargando || _conectando)
                ? null
                : _cargarDispositivos,
          ),
        ]),

        const SizedBox(height: 16),
        Divider(color: Colors.white.withOpacity(0.06)),
        const SizedBox(height: 8),

        // Contenido
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
          )
        else if (_error.isNotEmpty)
          _ErrorBanner(mensaje: _error, onReintentar: _cargarDispositivos)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dispositivos.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.white.withOpacity(0.04), height: 8),
            itemBuilder: (_, i) {
              final d        = _dispositivos[i];
              final esActivo = BluetoothPrinterService
                      .dispositivoActual?.macAdress ==
                  d.macAdress;
              final cargando =
                  _conectando && _conectandoA == d.name;

              return GestureDetector(
                onTap: (_conectando) ? null : () => _seleccionar(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: esActivo
                        ? const Color(0xFF4F46E5).withOpacity(0.12)
                        : const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: esActivo
                          ? const Color(0xFF4F46E5).withOpacity(0.5)
                          : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.print_outlined,
                          color: Color(0xFF818CF8), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(d.macAdress,
                              style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    if (cargando)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF818CF8)),
                      )
                    else if (esActivo)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF34D399)
                                  .withOpacity(0.4)),
                        ),
                        child: const Text('Conectada',
                            style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      )
                    else
                      Opacity(
                        opacity: _conectando ? 0.4 : 1.0,
                        child: const Icon(Icons.chevron_right,
                            color: Color(0xFF374151), size: 18),
                      ),
                  ]),
                ),
              );
            },
          ),
      ]),
    );
  }
}

// ── Banner de error ────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String       mensaje;
  final VoidCallback onReintentar;

  const _ErrorBanner(
      {required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Icon(Icons.bluetooth_disabled,
                  color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(mensaje,
                    style: const TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 13,
                        height: 1.5)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh,
                color: Color(0xFF818CF8), size: 16),
            label: const Text('Reintentar',
                style: TextStyle(color: Color(0xFF818CF8))),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: const Color(0xFF4F46E5).withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      );
}
