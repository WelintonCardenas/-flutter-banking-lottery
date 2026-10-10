# API de Referencia - Funciones de Ligado

Documentación completa de las funciones de generación de ligas y super pale.

## 📌 Ubicación

Todas las funciones están en: `lib/models/jugada.dart`

---

## Funciones Disponibles

### 1. `detectarComb(String numero) → String`

Detecta el tipo de combinación basada en la longitud del número.

**Parámetros:**
- `numero`: String con dígitos (ej: "14", "1425", "142536")

**Retorna:**
- "Quiniela" → 2 dígitos
- "Pale" → 4 dígitos
- "Tripleta" → 6 dígitos
- "---" → Otro valor

**Ejemplos:**
```dart
print(detectarComb('14'));      // "Quiniela"
print(detectarComb('1425'));    // "Pale"
print(detectarComb('142536'));  // "Tripleta"
print(detectarComb('99'));      // "Quiniela"
```

---

### 2. `detectarCombLiga(String digitos) → String`

Detecta el tipo de COMBINACIÓN LIGADA.

**Parámetros:**
- `digitos`: String con dígitos

**Retorna:**
- "Quiniela ligada" → 2 dígitos
- "Pale ligado" → 4 dígitos
- "Tripleta ligada" → 6 dígitos
- "---" → Otro valor

**Ejemplos:**
```dart
print(detectarCombLiga('14'));      // "Quiniela ligada"
print(detectarCombLiga('1425'));    // "Pale ligado"
print(detectarCombLiga('142536'));  // "Tripleta ligada"
```

---

### 3. `generarLigas(String entrada) → List<String>`

Genera todas las combinaciones ligadas posibles SIN DUPLICADOS.

**Parámetros:**
- `entrada`: String que puede contener "./" para indicar modo liga

**Retorna:**
- `List<String>`: Lista de números generados (sin duplicados)

**Comportamiento por tipo:**

#### Pale (4 dígitos: XXYY)
```dart
final ligas = generarLigas('1425');
// Resultado: ["14", "25", "12", "45", "15", "42"]
// Explicación:
//   "14" = par X
//   "25" = par Y  
//   "12" = X[0]Y[0]
//   "45" = X[1]Y[1]
//   "15" = X[0]Y[1]
//   "42" = X[1]Y[0]
// Total: 6 combinaciones
```

#### Tripleta (6 dígitos: AABBCC)
```dart
final ligas = generarLigas('142536');
// Resultado: ["14", "25", "36", "1425", "1436", "2536"]
// Explicación:
//   Combinaciones de 2 en 2: AB, AC, BC
//   Pares originales: A, B, C
// Total: 6 combinaciones
```

#### Quiniela (2 dígitos: XY)
```dart
final ligas = generarLigas('14');
// Resultado: ["14"]
// Solo retorna el número original
```

#### Con formato "./"
```dart
final ligas1 = generarLigas('1425');
final ligas2 = generarLigas('14./' + '25');
// ligas1 == ligas2 (el "./" se limpia automáticamente)
```

**Características:**
- ✅ Elimina automáticamente "./" de la entrada
- ✅ Usa `Set<String>` para evitar duplicados
- ✅ Válido para 2, 4 y 6 dígitos

---

### 4. `generarSuperPale(String entrada) → List<String>`

Genera TODAS las permutaciones posibles de un número.

**Parámetros:**
- `entrada`: String con 2, 4 o 6 dígitos

**Retorna:**
- `List<String>`: Todas las permutaciones únicas

**Comportamiento por tipo:**

#### Quiniela Super Pale (2 dígitos: XY)
```dart
final superPale = generarSuperPale('14');
// Resultado: ["14", "41"]
// Explicación: Todos los arreglos de 2 dígitos sin repetir
// Total: 2 permutaciones
```

#### Pale Super Pale (4 dígitos: XYZW)
```dart
final superPale = generarSuperPale('1425');
// Resultado: ["14", "12", "15", "41", "42", "45",
//            "21", "24", "25", "51", "52", "54"]
// Explicación: Todas las combinaciones de 2 dígitos sin repetir
//              Fórmula: n × (n-1) = 4 × 3 = 12
// Total: 12 permutaciones
```

#### Tripleta Super Pale (6 dígitos: XYZWAB)
```dart
final superPale = generarSuperPale('123456');
// Resultado: 30 elementos
// Explicación: 6 × 5 = 30 permutaciones
// Cada dígito en posición 1, otro en posición 2 (sin repetir)
```

**Fórmula General:**
```
Para n dígitos: n × (n-1) permutaciones
- Quiniela (2): 2 × 1 = 2
- Pale (4):     4 × 3 = 12
- Tripleta (6): 6 × 5 = 30
```

---

## Modelo Jugada

### Estructura Base

```dart
class Jugada {
  final String numero;      // "14", "1425", "142536"
  final String loteria;     // "Nacional", "Leidsa", etc.
  final String comb;        // "Quiniela", "Pale", "Tripleta", etc.
  final String forma;       // "Fijo" (puede extenderse a otros)
  final double monto;       // 50.0, 100.0, etc.
  final bool ligada;        // true si es una jugada ligada

  const Jugada({
    required this.numero,
    required this.loteria,
    required this.comb,
    required this.forma,
    required this.monto,
    this.ligada = false,
  });
}
```

### Métodos Disponibles

#### `toMap() → Map<String, dynamic>`
Convierte la Jugada a mapa para guardar en Firestore.

```dart
final j = Jugada(
  numero: '14',
  loteria: 'Nacional',
  comb: 'Quiniela',
  forma: 'Fijo',
  monto: 100.0,
  ligada: false,
);

final map = j.toMap();
// {
//   'numero': '14',
//   'loteria': 'Nacional',
//   'comb': 'Quiniela',
//   'forma': 'Fijo',
//   'monto': 100.0,
//   'ligada': false,
// }
```

#### `fromMap(Map) → Jugada`
Crea una Jugada desde un mapa de Firestore.

```dart
final map = {
  'numero': '1425',
  'loteria': 'Leidsa',
  'comb': 'Pale ligado',
  'forma': 'Fijo',
  'monto': 150.0,
  'ligada': true,
};

final j = Jugada.fromMap(map);
// Jugada(numero: '1425', loteria: 'Leidsa', ...)
```

#### `copyWith({...}) → Jugada`
Crea una copia con algunos campos modificados.

```dart
final j1 = Jugada(
  numero: '14',
  loteria: 'Nacional',
  comb: 'Quiniela',
  forma: 'Fijo',
  monto: 100.0,
);

// Cambiar número y monto
final j2 = j1.copyWith(numero: '25', monto: 150.0);
// j2: Jugada(numero: '25', loteria: 'Nacional', monto: 150.0, ...)
// j1 sin cambios (immutable)
```

---

## Casos de Uso Comunes

### Caso 1: Agregar Una Jugada Simple

```dart
final nuevaJugada = Jugada(
  numero: '14',
  loteria: 'Nacional',
  comb: detectarComb('14'),  // "Quiniela"
  forma: 'Fijo',
  monto: 100.0,
  ligada: false,
);
```

### Caso 2: Generar Ligadas Automáticamente

```dart
// Usuario ingresa "1425./" monto 100
void procesarLigadas(String entrada, double monto, String loteria) {
  final ligas = generarLigas(entrada);
  final digitos = entrada.replaceAll('./', '').replaceAll(RegExp(r'[^0-9]'), '');
  final combTipo = detectarCombLiga(digitos);
  
  final jugadas = <Jugada>[];
  for (final num in ligas) {
    jugadas.add(Jugada(
      numero: num,
      loteria: loteria,
      comb: combTipo,
      forma: 'Fijo',
      monto: monto,
      ligada: true,
    ));
  }
  
  // Ahora jugadas tiene 6 elementos (si es pale)
  return jugadas;
}
```

### Caso 3: Generar Super Pale

```dart
// Usuario activa super pale (futuro)
void procesarSuperPale(String entrada, double monto, String loteria) {
  final superPerms = generarSuperPale(entrada);
  final digitos = entrada.replaceAll(RegExp(r'[^0-9]'), '');
  final combTipo = detectarCombLiga(digitos);
  
  final jugadas = <Jugada>[];
  for (final num in superPerms) {
    jugadas.add(Jugada(
      numero: num,
      loteria: loteria,
      comb: combTipo,
      forma: 'Fijo',
      monto: monto,
      ligada: true,  // También es ligada
    ));
  }
  
  // Ahora jugadas tiene 12 elementos (si es pale)
  return jugadas;
}
```

### Caso 4: Guardar en Firestore y Recuperar

```dart
// Guardar
final jugadas = [
  Jugada(numero: '14', loteria: 'Nacional', ...),
  Jugada(numero: '25', loteria: 'Nacional', ...),
];

final ticketId = await TicketService.guardar(jugadas);
// En Firestore:
// tickets/{ticketId}/jugadas: [
//   {'numero': '14', 'loteria': 'Nacional', ...},
//   {'numero': '25', 'loteria': 'Nacional', ...},
// ]

// Recuperar
final doc = await FirebaseFirestore.instance
    .collection('tickets')
    .doc(ticketId)
    .get();

final datos = doc.data() as Map<String, dynamic>;
final jugadasRecuperadas = (datos['jugadas'] as List)
    .map((j) => Jugada.fromMap(j as Map<String, dynamic>))
    .toList();
```

### Caso 5: Validar Que No Haya Duplicados

```dart
// Verificar que generarLigas no genera duplicados
final ligas = generarLigas('1425');
final liasSet = ligas.toSet();

if (ligas.length != ligasSet.length) {
  print('ERROR: Hay duplicados!');
} else {
  print('OK: ${ligas.length} combinaciones únicas');
}
// Salida: "OK: 6 combinaciones únicas"
```

---

## Integración con UI

### En vender_numero.dart

```dart
// Cuando usuario presiona Enter en número con "./"
void _agregarLigadas(String entrada, double monto) {
  final combinaciones = generarLigas(entrada);
  
  for (final num in combinaciones) {
    final error = _validarLimite(num, _loteria!, monto);
    if (error != null) {
      _snack(error, error: true);
      return;
    }
  }
  
  final nuevas = combinaciones.map((num) => Jugada(
      numero: num,
      loteria: _loteria!,
      comb: detectarComb(num),
      forma: 'Fijo',
      monto: monto,
      ligada: true,
  )).toList();
  
  setState(() {
    _jugadas.addAll(nuevas);
  });
  
  _snack('${nuevas.length} jugadas ligadas agregadas');
}
```

### En ticket_formatter.dart

```dart
// Ya implementado - agrupa jugadas por lotería y tipo
String formatearTicket(String ticketId, List<Jugada> jugadas, double total) {
  // Ordena por lotería
  final jugadasOrdenadas = List<Jugada>.from(jugadas)
    ..sort((a, b) => a.loteria.compareTo(b.loteria));
  
  // Itera mostrando agrupadas
  String? loteriaActual;
  for (final j in jugadasOrdenadas) {
    if (j.loteria != loteriaActual) {
      sb.writeln(_B1 + j.loteria + _B0);  // Encabezado de lotería
      loteriaActual = j.loteria;
    }
    // Imprime jugada con su tipo
  }
}
```

---

## Limitaciones y Consideraciones

1. **Longitud máxima de entrada:**
   - 2 dígitos: Quiniela → 2 permutaciones (super pale)
   - 4 dígitos: Pale → 6 combinaciones (ligado), 12 (super pale)
   - 6 dígitos: Tripleta → 6 combinaciones (ligado), 30 (super pale)

2. **Performance:**
   - Las funciones son rápidas (millones de operaciones/segundo)
   - El cuello de botella es Bluetooth/Firestore, no la lógica de ligado

3. **Manejo de errores:**
   - Entrada vacía o inválida retorna lista vacía o [digitos]
   - No lanza excepciones (válidas para la lógica de negocio)

4. **Futuras extensiones:**
   - Agregar "Doble Pale" (8 dígitos)
   - Sistema de variantes (Fijo, Vueltico, etc.)
   - Bonificaciones por tipo de jugada

---

## Testing

Ver `test/jugada_test.dart` para 20 pruebas unitarias completas:

```bash
flutter test test/jugada_test.dart --verbose
```

Cada función está testeada en múltiples escenarios:
- Entrada válida
- Entrada con formato "./"
- Entrada con dígitos repetidos
- Validación de ausencia de duplicados
- Casos límite
