// ─── services/bluetooth_printer_service.dart ─────────────────────────────────

import 'dart:async';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class BluetoothPrinterService {
  static BluetoothInfo? _dispositivo;
  static Timer?         _keepAliveTimer;
  static bool           _reconectando = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  static BluetoothInfo? get dispositivoActual => _dispositivo;
  static bool           get conectado         => _dispositivo != null;

  // ── Keep-alive ────────────────────────────────────────────────────────────
  // Verifica la conexión cada 20 segundos y reconecta si se perdió
  static void _iniciarKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_dispositivo == null || _reconectando) return;
      final sigue = await estaConectado();
      if (!sigue) {
        await _reconectar();
      }
    });
  }

  static void _detenerKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  static Future<void> _reconectar() async {
    if (_dispositivo == null || _reconectando) return;
    _reconectando = true;
    try {
      // Intentar reconectar hasta 3 veces
      for (int i = 0; i < 3; i++) {
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 600));

        final ok = await PrintBluetoothThermal.connect(
          macPrinterAddress: _dispositivo!.macAdress,
        ).timeout(const Duration(seconds: 8), onTimeout: () => false);

        if (ok) break; // reconectado exitosamente
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (_) {
      // Si falla 3 veces no hace nada — el usuario verá el estado desconectado
    } finally {
      _reconectando = false;
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  static Future<bool> bluetoothHabilitado() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BluetoothInfo>> obtenerPareados() async {
    try {
      if (!await bluetoothHabilitado()) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> conectar(BluetoothInfo dispositivo) async {
    try {
      // Limpiar conexión previa
      _detenerKeepAlive();
      if (_dispositivo != null) {
        try { await PrintBluetoothThermal.disconnect; } catch (_) {}
        _dispositivo = null;
      }

      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: dispositivo.macAdress,
      ).timeout(const Duration(seconds: 8), onTimeout: () => false);

      if (ok) {
        _dispositivo = dispositivo;
        _iniciarKeepAlive(); // ← iniciar keep-alive al conectar
      }
      return ok;
    } catch (_) {
      _dispositivo = null;
      return false;
    }
  }

  static Future<void> desconectar() async {
    _detenerKeepAlive(); // ← detener keep-alive al desconectar
    try { await PrintBluetoothThermal.disconnect; } catch (_) {}
    _dispositivo = null;
  }

  static Future<bool> estaConectado() async {
    try {
      final status = await PrintBluetoothThermal.connectionStatus;
      if (!status && _dispositivo != null) {
        // Estado inconsistente — limpiar sin cancelar keep-alive
        // (el keep-alive se encargará de reconectar)
      }
      return status;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> imprimir(String textoTicket) async {
    try {
      // Si no está conectado intentar reconectar una vez antes de imprimir
      if (!await estaConectado()) {
        if (_dispositivo == null) return false;
        await _reconectar();
        if (!await estaConectado()) return false;
      }

      final bytes = <int>[];
      for (final linea in textoTicket.split('\n')) {
        bytes.addAll(_encodearLinea(linea));
        bytes.add(0x0A);
      }
      // Corte de papel
      bytes.addAll([0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x41, 0x00]);

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  static List<int> _encodearLinea(String linea) {
    final out = <int>[];
    for (final cp in linea.runes) {
      if (cp == 0x2550)      { out.add(0xCD); }
      else if (cp == 0x2500) { out.add(0xC4); }
      else if (cp == 0x2501) { out.add(0xC4); }
      else if (cp <= 127)    { out.add(cp);   }
      else                   { out.add(0x3F); }
    }
    return out;
  }
}
