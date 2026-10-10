// ─── utils/ticket_formatter.dart ─────────────────────────────────────────────

import '../models/jugada.dart';

const int _W = 32;

const String _B1 = '\x1B\x45\x01';
const String _B0 = '\x1B\x45\x00';
const String _S2 = '\x1D\x21\x11';
const String _S1 = '\x1D\x21\x01';
const String _S0 = '\x1D\x21\x00';

String _sep() => '--------------------------------';

String _centrar(String t) {
  if (t.length >= _W) return t;
  final p = (_W - t.length) ~/ 2;
  return ' ' * p + t;
}

String _cols(String izq, String der) {
  final gap = _W - izq.length - der.length;
  return izq + ' ' * (gap > 0 ? gap : 1) + der;
}

String _diaSemana(DateTime dt) {
  const d = ['LUNES','MARTES','MIERCOLES','JUEVES',
              'VIERNES','SABADO','DOMINGO'];
  return d[dt.weekday - 1];
}

String _tipoLetra(String comb) {
  if (comb.contains('Pale'))     return 'P';
  if (comb.contains('Tripleta')) return 'T';
  if (comb.contains('Quiniela')) return 'Q';
  return '-';
}

String formatearTicket(
  String ticketId,
  List<Jugada> jugadas,
  double total,
) {
  final ahora = DateTime.now();
  final sb    = StringBuffer();

  final fecha =
      '${ahora.year}-'
      '${ahora.month.toString().padLeft(2, '0')}-'
      '${ahora.day.toString().padLeft(2, '0')}';
  final hora =
      '${ahora.hour.toString().padLeft(2, '0')}:'
      '${ahora.minute.toString().padLeft(2, '0')}:'
      '${ahora.second.toString().padLeft(2, '0')}';
  final dia = _diaSemana(ahora);

  final serial      = ahora.millisecondsSinceEpoch.toString();
  final sn          = serial.substring(serial.length - 8);
  final ticketNum   = ticketId.replaceAll(RegExp(r'[^0-9]'), '');
  // Los últimos 4 dígitos son el sufijo exacto del docId (T-YYYYMMDD-XXXX)
  final ticketCorto = ticketNum.length >= 4
      ? ticketNum.substring(ticketNum.length - 4)
      : ticketNum;

  // Ordenar jugadas por lotería para que el agrupado funcione correctamente
  final jugadasOrdenadas = List<Jugada>.from(jugadas)
    ..sort((a, b) => a.loteria.compareTo(b.loteria));

  // ── ENCABEZADO ───────────────────────────────────────────────────────────
  sb.writeln(_B1 + _S1 + _centrar('BANCAS EL BATAZO') + _S0 + _B0);
  final encFecha = '$fecha $dia';
  sb.writeln(_cols(encFecha, hora));
  sb.writeln(_B1 + 'Ticket #$ticketCorto' + _B0);
  sb.writeln('S/N:$sn');
  sb.writeln(_sep());

  // Encabezado columnas
  sb.writeln('Números'.padRight(9) + 'Comb Forma'.padRight(14) + 'Monto');
  sb.writeln(_sep());

  // ── JUGADAS agrupadas por lotería ─────────────────────────────────────────
  String? loteriaActual;

  for (final j in jugadasOrdenadas) {
    if (j.loteria != loteriaActual) {
      // Separador ENTRE loterías (no antes de la primera)
      if (loteriaActual != null) {
        sb.writeln(_sep());
      }

      // Nombre de la lotería en negrita
      sb.writeln(_B1 + j.loteria + _B0);

      loteriaActual = j.loteria;
    }

    final tipo  = _tipoLetra(j.comb);
    final monto = 'RD\$${j.monto.toStringAsFixed(2)}';

    final numVis = j.numero.length == 4
        ? '${j.numero.substring(0, 2)}-${j.numero.substring(2, 4)}'
        : j.numero;

    // Layout: _S2 número (5×2=10 cols) + tipo (14) + monto (8) = 32 ✓
    final numPad   = numVis.padRight(5);
    final tipoPad  = tipo.padRight(14);
    final montoPad = monto.padLeft(8);

    sb.writeln(
      _B1 + _S2 + numPad + _S0 + _B0 +
      tipoPad +
      montoPad,
    );
  }

  sb.writeln(_sep());

  // ── TOTAL en negrita, alineado a la derecha ───────────────────────────────
  final totalStr = 'Total: RD\$${total.toStringAsFixed(2)}';
  sb.writeln(_B1 + totalStr.padLeft(_W) + _B0);

  final items = '${jugadas.length} Item${jugadas.length != 1 ? 's' : ''}';
  sb.writeln(items);

  sb.writeln(_sep());

  // ── PIE ──────────────────────────────────────────────────────────────────
  sb.writeln('Revise su ticket al recibirlo.');
  sb.writeln('Pagamos de inmediato salen los');
  sb.writeln('premios.');
  sb.writeln('S/N:$sn');
  sb.writeln('');

  return sb.toString();
}
