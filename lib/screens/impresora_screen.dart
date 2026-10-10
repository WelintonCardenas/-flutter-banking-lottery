// ─── screens/impresora_screen.dart ───────────────────────────────────────────
//
// Usa BluetoothPrinterService (print_bluetooth_thermal).
// Elimina la dependencia de flutter_bluetooth_serial.

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/bluetooth_printer_service.dart';

class ImpresoraScreen extends StatefulWidget {
  const ImpresoraScreen({super.key});

  @override
  State<ImpresoraScreen> createState() => _ImpresoraScreenState();
}

class _ImpresoraScreenState extends State<ImpresoraScreen> {
  List<BluetoothInfo> _dispositivos = [];
  bool _cargando        = false;
  bool _conectando      = false;
  bool _bluetoothActivo = false;
  String _conectandoA   = '';

  // Configuración de impresión
  int  _anchoPapel    = 58;
  bool _cortarPapel   = true;

  @override
  void initState() {
    super.initState();
    _verificarBluetooth();
  }

  Future<void> _verificarBluetooth() async {
    final activo = await BluetoothPrinterService.bluetoothHabilitado();
    if (mounted) setState(() => _bluetoothActivo = activo);
    if (activo) _cargarDispositivos();
  }

  Future<void> _cargarDispositivos() async {
    setState(() => _cargando = true);
    final lista = await BluetoothPrinterService.obtenerPareados();
    if (mounted) setState(() { _dispositivos = lista; _cargando = false; });
  }

  Future<void> _conectarYImprimir(BluetoothInfo dispositivo) async {
    setState(() { _conectando = true; _conectandoA = dispositivo.name; });

    // Si ya hay otra conectada, desconectar primero
    if (BluetoothPrinterService.conectado) {
      await BluetoothPrinterService.desconectar();
    }

    final ok = await BluetoothPrinterService.conectar(dispositivo);
    if (!ok) {
      if (mounted) setState(() { _conectando = false; _conectandoA = ''; });
      _snack('No se pudo conectar a ${dispositivo.name}', error: true);
      return;
    }

    // Imprimir ticket de prueba
    final texto = _textoTicketPrueba();
    final impreso = await BluetoothPrinterService.imprimir(texto);

    if (mounted) setState(() { _conectando = false; _conectandoA = ''; });
    _snack(impreso
        ? 'Ticket impreso en ${dispositivo.name}'
        : 'Conectado pero error al imprimir',
        error: !impreso);
  }

  String _textoTicketPrueba() {
    final ahora  = DateTime.now();
    final fecha  = '${ahora.day.toString().padLeft(2,'0')}/'
        '${ahora.month.toString().padLeft(2,'0')}/${ahora.year}';
    final hora   = '${ahora.hour.toString().padLeft(2,'0')}:'
        '${ahora.minute.toString().padLeft(2,'0')}';
    final ancho  = _anchoPapel == 58 ? 32 : 48;
    final sep    = '=' * ancho;
    final sep2   = '-' * ancho;

    final sb = StringBuffer();
    sb.writeln(sep);
    sb.writeln('     BANCAS EL BATAZO');
    sb.writeln(sep);
    sb.writeln('TICKET DE PRUEBA');
    sb.writeln('Fecha: $fecha  Hora: $hora');
    sb.writeln(sep2);
    sb.writeln('Num.  Loteria   Tipo      Monto');
    sb.writeln(sep2);
    sb.writeln('14    Nacional  Quiniela  RD\$100');
    sb.writeln('25    Leidsa    Quiniela  RD\$50');
    sb.writeln(sep2);
    sb.writeln('TOTAL: RD\$150.00');
    sb.writeln(sep);
    sb.writeln('   Gracias por su compra!');
    sb.writeln(sep);
    if (_cortarPapel) sb.write('\n\n\n');
    return sb.toString();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? const Color(0xFFEF4444) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Impresora Bluetooth',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        actions: [
          // Indicador de conexión activa
          if (BluetoothPrinterService.conectado)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF34D399).withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      BluetoothPrinterService.dispositivoActual?.name ?? '',
                      style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ),
          // Botón refrescar
          IconButton(
            icon: const Icon(Icons.refresh,
                color: Color(0xFF6B7280), size: 22),
            onPressed: _cargando ? null : _cargarDispositivos,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Estado Bluetooth ─────────────────────────────────────────────
            if (!_bluetoothActivo)
              _BannerBluetooth(onActivar: _verificarBluetooth)
            else ...[

              // ── Ajustes de impresión ────────────────────────────────────────
              _CardAjustes(
                anchoPapel:  _anchoPapel,
                cortarPapel: _cortarPapel,
                onAncho:     (v) => setState(() => _anchoPapel = v),
                onCortar:    (v) => setState(() => _cortarPapel = v),
              ),
              const SizedBox(height: 16),

              // ── Lista de impresoras ─────────────────────────────────────────
              Row(children: [
                const Text('Impresoras disponibles',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_cargando)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF818CF8)),
                  ),
              ]),
              const SizedBox(height: 4),
              const Text(
                'La impresora debe estar pareada en Ajustes → Bluetooth',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              const SizedBox(height: 12),

              if (!_cargando && _dispositivos.isEmpty)
                _BannerSinDispositivos(onRefresh: _cargarDispositivos)
              else
                ...(_dispositivos.map((d) {
                  final esActiva = BluetoothPrinterService
                          .dispositivoActual?.macAdress ==
                      d.macAdress;
                  final cargando =
                      _conectando && _conectandoA == d.name;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TarjetaImpresora(
                      dispositivo: d,
                      esActiva:    esActiva,
                      cargando:    cargando,
                      onTap: _conectando
                          ? null
                          : () => _conectarYImprimir(d),
                      onDesconectar: esActiva
                          ? () async {
                              await BluetoothPrinterService.desconectar();
                              setState(() {});
                              _snack('Desconectado');
                            }
                          : null,
                    ),
                  );
                })),

              const SizedBox(height: 16),

              // ── Info ────────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF818CF8), size: 16),
                      SizedBox(width: 6),
                      Text('Cómo usar',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ]),
                    SizedBox(height: 8),
                    _InfoItem(texto: 'Toca una impresora para conectar e imprimir ticket de prueba'),
                    _InfoItem(texto: 'La conexión se mantiene activa para tickets siguientes'),
                    _InfoItem(texto: 'Si la impresora no aparece, paréala primero en Ajustes del teléfono'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _BannerBluetooth extends StatelessWidget {
  final VoidCallback onActivar;
  const _BannerBluetooth({required this.onActivar});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFEF4444).withOpacity(0.3)),
        ),
        child: Column(children: [
          const Icon(Icons.bluetooth_disabled,
              color: Color(0xFFEF4444), size: 32),
          const SizedBox(height: 8),
          const Text('Bluetooth desactivado',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Activa el Bluetooth para usar la impresora',
              style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onActivar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Verificar de nuevo',
                style: TextStyle(color: Colors.white)),
          ),
        ]),
      );
}

class _CardAjustes extends StatelessWidget {
  final int  anchoPapel;
  final bool cortarPapel;
  final void Function(int)  onAncho;
  final void Function(bool) onCortar;

  const _CardAjustes({
    required this.anchoPapel,
    required this.cortarPapel,
    required this.onAncho,
    required this.onCortar,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configuración',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 14),

            // Ancho de papel
            Row(children: [
              const Icon(Icons.straighten,
                  color: Color(0xFF6B7280), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Ancho del papel',
                    style: TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 13)),
              ),
              _PillSelector(
                opciones: const ['58mm', '80mm'],
                seleccionado: anchoPapel == 58 ? '58mm' : '80mm',
                onChanged: (v) => onAncho(v == '58mm' ? 58 : 80),
              ),
            ]),
            const SizedBox(height: 12),

            // Cortar papel
            Row(children: [
              const Icon(Icons.content_cut,
                  color: Color(0xFF6B7280), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Cortar papel al terminar',
                    style: TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 13)),
              ),
              Switch(
                value:    cortarPapel,
                onChanged: onCortar,
                activeColor: const Color(0xFF4F46E5),
              ),
            ]),
          ],
        ),
      );
}

class _PillSelector extends StatelessWidget {
  final List<String>         opciones;
  final String               seleccionado;
  final void Function(String) onChanged;

  const _PillSelector({
    required this.opciones,
    required this.seleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: opciones.map((o) {
          final activo = o == seleccionado;
          return GestureDetector(
            onTap: () => onChanged(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: activo
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo
                      ? const Color(0xFF4F46E5)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(o,
                  style: TextStyle(
                      color: activo
                          ? Colors.white
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: activo
                          ? FontWeight.w700
                          : FontWeight.w400)),
            ),
          );
        }).toList(),
      );
}

class _TarjetaImpresora extends StatelessWidget {
  final BluetoothInfo   dispositivo;
  final bool            esActiva;
  final bool            cargando;
  final VoidCallback?   onTap;
  final VoidCallback?   onDesconectar;

  const _TarjetaImpresora({
    required this.dispositivo,
    required this.esActiva,
    required this.cargando,
    required this.onTap,
    required this.onDesconectar,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: esActiva
                ? const Color(0xFF4F46E5).withOpacity(0.1)
                : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: esActiva
                  ? const Color(0xFF4F46E5).withOpacity(0.5)
                  : Colors.white.withOpacity(0.06),
              width: esActiva ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: esActiva
                    ? const Color(0xFF4F46E5).withOpacity(0.2)
                    : const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.print_outlined,
                color: esActiva
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF374151),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dispositivo.name,
                      style: TextStyle(
                          color: esActiva
                              ? Colors.white
                              : const Color(0xFFD1D5DB),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(dispositivo.macAdress,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ],
              ),
            ),

            if (cargando)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF818CF8)),
              )
            else if (esActiva) ...[
              // Badge conectada
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF34D399).withOpacity(0.4)),
                ),
                child: const Text('Conectada',
                    style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              if (onDesconectar != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDesconectar,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close,
                        color: Color(0xFF6B7280), size: 16),
                  ),
                ),
              ],
            ] else
              const Icon(Icons.chevron_right,
                  color: Color(0xFF374151), size: 18),
          ]),
        ),
      );
}

class _BannerSinDispositivos extends StatelessWidget {
  final VoidCallback onRefresh;
  const _BannerSinDispositivos({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(children: [
          Icon(Icons.print_disabled,
              color: const Color(0xFF374151).withOpacity(0.6),
              size: 36),
          const SizedBox(height: 10),
          const Text('No hay impresoras pareadas',
              style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Ve a Ajustes → Bluetooth y paréa tu impresora',
            style:
                TextStyle(color: Color(0xFF374151), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh,
                color: Color(0xFF818CF8), size: 16),
            label: const Text('Actualizar lista',
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

class _InfoItem extends StatelessWidget {
  final String texto;
  const _InfoItem({required this.texto});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ',
              style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12)),
          ),
        ]),
      );
}
