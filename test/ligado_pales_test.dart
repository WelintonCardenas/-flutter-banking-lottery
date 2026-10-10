import 'package:flutter_test/flutter_test.dart';
import 'package:banca_loteria/models/jugada.dart';

void main() {
  group('Generación de ligados de pales', () {
    test('Pale ligado (4 dígitos) - Solo genera pales sin números individuales', () {
      // Arrange: entrada para pale "1234" (1,2,3,4)
      final entrada = '1234';

      // Act: generar solo pales
      final resultado = generarLigasSoloPales(entrada);

      // Assert: debe generar SOLO 4 pales (no los números individuales 12 y 34)
      expect(resultado.length, 4, reason: 'Debe generar exactamente 4 pales');
      // Las combinaciones cruzadas son: 13, 14, 23, 24
      expect(resultado.toSet(), containsAll(['13', '14', '23', '24']),
          reason: 'Los 4 pales deben ser las combinaciones cruzadas');
      expect(resultado.contains('12'), false, reason: 'No debe contener el número 12 individual');
      expect(resultado.contains('34'), false, reason: 'No debe contener el número 34 individual');
    });

    test('Pale ligado (4 dígitos) - Compara con generarLigas (que SÍ incluye individuales)', () {
      final entrada = '1234';

      final conIndividuales = generarLigas(entrada);
      final soloPales = generarLigasSoloPales(entrada);

      // generarLigas incluye números individuales (12, 34 + 4 pales = 6)
      expect(conIndividuales.length, 6, reason: 'generarLigas debe generar 6 jugadas (2 individuales + 4 pales)');

      // generarLigasSoloPales NO incluye números individuales (solo 4 pales)
      expect(soloPales.length, 4, reason: 'generarLigasSoloPales debe generar 4 pales sin individuales');
    });

    test('Tripleta ligada (6 dígitos) - Solo genera combinaciones de 2 en 2', () {
      final entrada = '123456';

      final resultado = generarLigasSoloPales(entrada);

      // Con 3 números (12, 34, 56), se generan C(3,2) = 3 combinaciones
      expect(resultado.length, 3, reason: 'Debe generar exactamente 3 pales');

      // Las 3 combinaciones deben ser: 1234, 1256, 3456
      expect(resultado.toSet(), containsAll(['1234', '1256', '3456']),
          reason: 'Las 3 combinaciones deben ser todas las parejas de los 3 números');

      // NO debe contener los números individuales
      expect(resultado.contains('12'), false, reason: 'No debe contener 12 individual');
      expect(resultado.contains('34'), false, reason: 'No debe contener 34 individual');
      expect(resultado.contains('56'), false, reason: 'No debe contener 56 individual');
    });

    test('detectarComb identifica correctamente los tipos de jugada', () {
      expect(detectarComb('12'), 'Quiniela');
      expect(detectarComb('1234'), 'Pale');
      expect(detectarComb('123456'), 'Tripleta');
    });

    test('detectarCombLiga identifica correctamente los tipos de ligada', () {
      expect(detectarCombLiga('12'), 'Quiniela ligada');
      expect(detectarCombLiga('1234'), 'Pale ligado');
      expect(detectarCombLiga('123456'), 'Tripleta ligada');
    });

    test('Validación: ligado con 3 números (12.25.38) genera SOLO 3 pales', () {
      final digitos = '123456'; // 6 dígitos para tripleta
      final pales = generarLigasSoloPales(digitos);

      // Debe haber exactamente 3 combinaciones
      expect(pales.length, 3);

      // La suma debe ser 3, no 6 (que sería si incluyera los números individuales)
      final totalJugadas = pales.length;
      expect(totalJugadas, 3, reason: 'Debe haber exactamente 3 pales sin números individuales');
    });
  });

  group('Modelo Jugada', () {
    test('Jugada con ligada=true se marca correctamente', () {
      final jugada = Jugada(
        numero: '12',
        loteria: 'Nacional',
        comb: 'Pale ligado',
        forma: 'Fijo',
        monto: 1.00,
        ligada: true,
      );

      expect(jugada.ligada, true);
      expect(jugada.numero, '12');
      expect(jugada.toMap()['ligada'], true);
    });

    test('fromMap recrear Jugada correctamente incluyendo ligada', () {
      final data = {
        'numero': '1234',
        'loteria': 'Nacional',
        'comb': 'Pale',
        'forma': 'Fijo',
        'monto': 1.00,
        'ligada': true,
      };

      final jugada = Jugada.fromMap(data);

      expect(jugada.numero, '1234');
      expect(jugada.ligada, true);
      expect(jugada.comb, 'Pale');
    });
  });
}
