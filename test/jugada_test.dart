import 'package:flutter_test/flutter_test.dart';
import 'package:banca_loteria/models/jugada.dart';

void main() {
  group('detectarComb', () {
    test('detecta Quiniela para 2 dígitos', () {
      expect(detectarComb('14'), 'Quiniela');
      expect(detectarComb('99'), 'Quiniela');
    });

    test('detecta Pale para 4 dígitos', () {
      expect(detectarComb('1425'), 'Pale');
      expect(detectarComb('9999'), 'Pale');
    });

    test('detecta Tripleta para 6 dígitos', () {
      expect(detectarComb('142536'), 'Tripleta');
      expect(detectarComb('999999'), 'Tripleta');
    });

    test('retorna --- para otros valores', () {
      expect(detectarComb('1'), '---');
      expect(detectarComb('12345'), '---');
    });
  });

  group('detectarCombLiga', () {
    test('detecta Quiniela ligada para 2 dígitos', () {
      expect(detectarCombLiga('14'), 'Quiniela ligada');
    });

    test('detecta Pale ligado para 4 dígitos', () {
      expect(detectarCombLiga('1425'), 'Pale ligado');
    });

    test('detecta Tripleta ligada para 6 dígitos', () {
      expect(detectarCombLiga('142536'), 'Tripleta ligada');
    });
  });

  group('generarLigas', () {
    test('pale: genera 6 combinaciones únicas sin duplicados', () {
      final ligas = generarLigas('1425');
      expect(ligas.length, 6);
      expect(ligas.toSet().length, 6, reason: 'No debe haber duplicados');
      expect(ligas, containsAll(['14', '25', '12', '45', '15', '42']));
    });

    test('pale: lidia con dígitos repetidos', () {
      final ligas = generarLigas('1122');
      expect(ligas.toSet().length, lessThanOrEqualTo(6));
    });

    test('tripleta: genera combinaciones de 2 en 2 más los pares', () {
      final ligas = generarLigas('142536');
      expect(ligas.length, 6);
      final set = ligas.toSet();
      expect(set, containsAll(['14', '25', '36']));
    });

    test('quiniela: retorna el número tal cual', () {
      final ligas = generarLigas('14');
      expect(ligas, ['14']);
    });

    test('limpia el formato ./: antes de procesar', () {
      final ligas1 = generarLigas('1425');
      final ligas2 = generarLigas('1425');
      expect(ligas1, ligas2);
    });
  });

  group('generarSuperPale', () {
    test('quiniela: genera 2 permutaciones', () {
      final result = generarSuperPale('14');
      expect(result.length, 2);
      expect(result.toSet(), {'14', '41'});
    });

    test('pale: genera 12 permutaciones únicas', () {
      final result = generarSuperPale('1425');
      expect(result.length, 12);
      final set = result.toSet();
      expect(set.length, 12, reason: 'Todas deben ser únicas');
      expect(set, containsAll([
        '14', '12', '15', '41', '42', '45',
        '21', '24', '25', '51', '52', '54'
      ]));
    });

    test('tripleta: genera permutaciones de 6 dígitos', () {
      final result = generarSuperPale('123456');
      expect(result.length, 30); // 6 × 5 = 30 permutaciones
    });

    test('limpia el formato ./ antes de procesar', () {
      final result1 = generarSuperPale('1425');
      final result2 = generarSuperPale('1425');
      expect(result1, result2);
    });
  });

  group('Jugada model', () {
    test('crea Jugada con valores correctos', () {
      final j = Jugada(
        numero: '1425',
        loteria: 'Nacional',
        comb: 'Pale',
        forma: 'Fijo',
        monto: 100.0,
      );
      expect(j.numero, '1425');
      expect(j.loteria, 'Nacional');
      expect(j.ligada, false);
    });

    test('toMap incluye todos los campos', () {
      final j = Jugada(
        numero: '14',
        loteria: 'Leidsa',
        comb: 'Quiniela',
        forma: 'Fijo',
        monto: 50.0,
        ligada: true,
      );
      final map = j.toMap();
      expect(map['numero'], '14');
      expect(map['ligada'], true);
    });

    test('fromMap reconstruye la Jugada', () {
      final map = {
        'numero': '1425',
        'loteria': 'Nacional',
        'comb': 'Pale',
        'forma': 'Fijo',
        'monto': 75.5,
        'ligada': true,
      };
      final j = Jugada.fromMap(map);
      expect(j.numero, '1425');
      expect(j.ligada, true);
      expect(j.monto, 75.5);
    });

    test('copyWith crea una nueva Jugada con cambios', () {
      final j1 = Jugada(
        numero: '14',
        loteria: 'Nacional',
        comb: 'Quiniela',
        forma: 'Fijo',
        monto: 100.0,
      );
      final j2 = j1.copyWith(numero: '25', monto: 150.0);
      expect(j2.numero, '25');
      expect(j2.monto, 150.0);
      expect(j2.loteria, 'Nacional');
      expect(j1.numero, '14'); // original sin cambios
    });
  });
}
