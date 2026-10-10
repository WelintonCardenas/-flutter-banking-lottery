// ─── models/jugada.dart ───────────────────────────────────────────────────────

String detectarComb(String numero) {
  final limpio = numero.replaceAll(RegExp(r'[^0-9]'), '');
  if (limpio.length == 2) return 'Quiniela';
  if (limpio.length == 4) return 'Pale';
  if (limpio.length == 6) return 'Tripleta';
  return '---';
}

String detectarCombLiga(String digitos) {
  if (digitos.length == 2) return 'Quiniela ligada';
  if (digitos.length == 4) return 'Pale ligado';
  if (digitos.length == 6) return 'Tripleta ligada';
  return '---';
}

/// Genera combinaciones para pales (4 dígitos) y tripletas (6 dígitos)
/// Pale XXYY: genera [X, Y, XY', X'Y, XY'', X'Y'] (6 jugadas)
/// Tripleta XXYYZZ: genera todas las combinaciones de 2 en 2, más los pares
List<String> generarLigas(String entrada) {
  final digitos = entrada.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');

  if (digitos.length == 4) {
    final a = digitos.substring(0, 2);
    final b = digitos.substring(2, 4);
    final resultado = <String>{
      a, b,
      '${a[0]}${b[0]}', '${a[1]}${b[1]}',
      '${a[0]}${b[1]}', '${a[1]}${b[0]}',
    };
    return resultado.toList();
  }

  if (digitos.length == 6) {
    final nums = [
      digitos.substring(0, 2),
      digitos.substring(2, 4),
      digitos.substring(4, 6),
    ];
    final combis = <String>{};

    for (int i = 0; i < nums.length; i++) {
      for (int j = i + 1; j < nums.length; j++) {
        combis.add(nums[i] + nums[j]);
      }
    }
    combis.addAll(nums);
    return combis.toList();
  }

  return [digitos];
}

/// Genera SOLO los pales sin números individuales
/// Pale XXYY: genera [XY', X'Y, XY'', X'Y'] (4 pales sin X ni Y individuales)
/// Tripleta XXYYZZ: genera solo combinaciones de 2 en 2 (3 pares)
List<String> generarLigasSoloPales(String entrada) {
  final digitos = entrada.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');

  if (digitos.length == 4) {
    final a = digitos.substring(0, 2);
    final b = digitos.substring(2, 4);
    final resultado = <String>{
      '${a[0]}${b[0]}', '${a[1]}${b[1]}',
      '${a[0]}${b[1]}', '${a[1]}${b[0]}',
    };
    return resultado.toList();
  }

  if (digitos.length == 6) {
    final nums = [
      digitos.substring(0, 2),
      digitos.substring(2, 4),
      digitos.substring(4, 6),
    ];
    final combis = <String>{};

    for (int i = 0; i < nums.length; i++) {
      for (int j = i + 1; j < nums.length; j++) {
        combis.add(nums[i] + nums[j]);
      }
    }
    return combis.toList();
  }

  return [digitos];
}

/// Genera todas las permutaciones de un número para super pale
/// Quiniela XY → super pale genera XY + YX (2 jugadas)
/// Pale XXYY → super pale genera todas las permutaciones de los 4 dígitos (12 jugadas)
/// Tripleta XXYYZZ → super pale genera todas las permutaciones de 6 dígitos
List<String> generarSuperPale(String entrada) {
  final digitos = entrada.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');
  final set = <String>{};
  final d = digitos.split('');

  if (digitos.isEmpty) return [];

  for (int i = 0; i < d.length; i++) {
    for (int j = 0; j < d.length; j++) {
      if (i != j) {
        set.add('${d[i]}${d[j]}');
      }
    }
  }

  return set.toList();
}

class Jugada {
  final String numero;
  final String loteria;
  final String comb;
  final String forma;
  final double monto;
  final bool ligada;

  const Jugada({
    required this.numero,
    required this.loteria,
    required this.comb,
    required this.forma,
    required this.monto,
    this.ligada = false,
  });

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'loteria': loteria,
        'comb': comb,
        'forma': forma,
        'monto': monto,
        'ligada': ligada,
      };

  factory Jugada.fromMap(Map<String, dynamic> m) => Jugada(
        numero: m['numero'] as String,
        loteria: m['loteria'] as String,
        comb: m['comb'] as String,
        forma: m['forma'] as String,
        monto: (m['monto'] as num).toDouble(),
        ligada: (m['ligada'] as bool?) ?? false,
      );

  Jugada copyWith({
    String? numero,
    String? loteria,
    String? comb,
    String? forma,
    double? monto,
    bool? ligada,
  }) =>
      Jugada(
        numero: numero ?? this.numero,
        loteria: loteria ?? this.loteria,
        comb: comb ?? this.comb,
        forma: forma ?? this.forma,
        monto: monto ?? this.monto,
        ligada: ligada ?? this.ligada,
      );
}
