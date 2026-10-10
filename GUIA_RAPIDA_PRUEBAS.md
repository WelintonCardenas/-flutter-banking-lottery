# Guía Rápida de Pruebas - Banca de Lotería

## 🚀 Inicio Rápido

### Verificar que todo compile:
```bash
cd C:\Users\Welinton\Desktop\Programas\Practicas_Flutter\app_para_practicar\banca_loteria
flutter clean
flutter pub get
flutter analyze
```

### Ejecutar pruebas unitarias:
```bash
flutter test test/jugada_test.dart
```

**Resultado esperado:** `All tests passed! (20 tests)`

---

## 📋 Pruebas Funcionales - Escenarios

### ESCENARIO 1: Impresión Simple (Sin Liga)

**Objetivo:** Verificar impresión de un solo toque sin duplicados

**Pasos:**
1. Iniciar la app
2. Ir a "Nueva venta"
3. Seleccionar lotería (ej: Nacional)
4. Ingresar número: "14"
5. Tocar ENTER
6. Ingresar monto: "100"
7. Tocar ENTER
8. Tocar botón "Guardar" (una sola vez)
9. **Verificación:** Se debe imprimir exactamente 1 ticket

**Resultado esperado:**
- ✅ 1 jugada agregada (14, Nacional, 100 RD$)
- ✅ Botón dice "Guardando..." mientras se procesa
- ✅ Ticket se imprime SIN duplicados
- ✅ Al terminar, aparece mensaje "Ticket guardado e impreso"
- ✅ Tabla se limpia

---

### ESCENARIO 2: Evitar Duplicados por Múltiples Pulsaciones

**Objetivo:** Verificar que pulsaciones rápidas no crean duplicados

**Pasos:**
1. Repetir ESCENARIO 1 hasta el paso 7
2. Tocar botón "Guardar" 3 veces muy rápido
3. **Verificación:** Solo se imprime 1 ticket (no 3)

**Resultado esperado:**
- ✅ Mensaje "Operación en curso..." aparece en intentos 2 y 3
- ✅ En Firestore solo existe 1 ticket
- ✅ Impresora imprime 1 solo ticket

---

### ESCENARIO 3: Ligado de Pale (6 Jugadas)

**Objetivo:** Verificar generación correcta de ligas sin duplicados

**Pasos:**
1. Ir a "Nueva venta"
2. Seleccionar lotería (ej: Nacional)
3. Ingresar número: "1425./" (nótese el ./)
4. Tocar ENTER (detector debe mostrar "Pale ligado")
5. Ingresar monto: "100"
6. Tocar ENTER

**Verificación de Resultados:**

| Combinación | Cantidad | Monto Total |
|-------------|----------|------------|
| 14          | ✅ 1     | 100 RD$    |
| 25          | ✅ 1     | 100 RD$    |
| 12          | ✅ 1     | 100 RD$    |
| 45          | ✅ 1     | 100 RD$    |
| 15          | ✅ 1     | 100 RD$    |
| 42          | ✅ 1     | 100 RD$    |
| **TOTAL**   | **6**    | **600 RD$** |

**Resultado esperado:**
- ✅ 6 jugadas en la tabla
- ✅ Todas con `ligada: true` en Firestore
- ✅ Monto total = 600 RD$
- ✅ Sin duplicados
- ✅ Ticket impreso con todas las 6 jugadas

---

### ESCENARIO 4: Ligado de Tripleta (6 Jugadas)

**Objetivo:** Verificar ligas para tripletas

**Pasos:**
1. Ir a "Nueva venta"
2. Ingresar número: "142536./"
3. Tocar ENTER (detector debe mostrar "Tripleta ligada")
4. Ingresar monto: "100"
5. Tocar ENTER

**Verificación:**
- ✅ 6 jugadas agregadas (combinaciones de 2 en 2)
- ✅ Monto total = 600 RD$
- ✅ Combinaciones: ["14", "25", "36", "1425", "1436", "2536"]

---

### ESCENARIO 5: Super Pale (12 Jugadas)

**Nota:** La UI actual no tiene un botón específico para super pale. Se debe:
1. Usar el modal de edición de jugada
2. O agregar manualmente modificando el código

**Para prueba manual de super pale:**
```dart
// En test/jugada_test.dart ya está probado
// El resultado de generarSuperPale('1425') = 12 permutaciones
```

**Verificación en Firestore:**
Si agrega jugadas con super pale, debería ver:
- 12 jugadas por pale
- Todas las permutaciones únicas (14, 12, 15, 41, 42, 45, 21, 24, 25, 51, 52, 54)

---

### ESCENARIO 6: Múltiples Loterías

**Objetivo:** Verificar que los números se asocian correctamente a cada lotería

**Pasos:**
1. Ir a "Nueva venta"
2. Seleccionar "Nacional"
3. Agregar número "14" monto 50
4. Cambiar lotería a "Leidsa"
5. Agregar número "25" monto 75
6. Cambiar lotería a "Fantasía"
7. Agregar número "14" monto 100
8. Guardar

**Verificación en Firestore:**
```json
{
  "tickets": {
    "T-20261010-XXXX": {
      "jugadas": [
        {"numero": "14", "loteria": "Nacional", "monto": 50},
        {"numero": "25", "loteria": "Leidsa", "monto": 75},
        {"numero": "14", "loteria": "Fantasía", "monto": 100}
      ],
      "total": 225
    }
  }
}
```

- ✅ Números correctos para cada lotería
- ✅ Montos separados por lotería
- ✅ Total correcto: 225 RD$
- ✅ Ticket impreso agrupa por lotería

---

## 📱 Ticket Impreso - Formato Esperado

```
════════════════════════════════════
      BANCAS EL BATAZO
════════════════════════════════════
2026-10-10 VIERNES                 14:30:15
                          Ticket #4891
                               S/N:4891234
────────────────────────────────────
Números   Comb Forma      Monto
────────────────────────────────────

NACIONAL
14-25     P    Fijo      RD$100.00

LEIDSA
14        Q    Fijo       RD$50.00

────────────────────────────────────
                    Total: RD$150.00
                              2 Items
────────────────────────────────────
Revise su ticket al recibirlo.
Pagamos de inmediato salen los
premios.
                               S/N:4891234


════════════════════════════════════
```

**Verificar:**
- ✅ Nombre de empresa correcto
- ✅ Fecha y hora correctas
- ✅ Números formateados (14-25 para pales)
- ✅ Loterías agrupadas
- ✅ Tipos correctos (P=Pale, Q=Quiniela, T=Tripleta)
- ✅ Total correcto
- ✅ Cantidad de items correcta

---

## 🧪 Pruebas de Regresión

Después de cambios, verificar que:

1. **Impresión regular (sin liga):**
   - [ ] Se imprime 1 ticket
   - [ ] Datos correctos en Firestore
   - [ ] Formato correcto

2. **Ligado de pales:**
   - [ ] Generarligas devuelve 6 combinaciones
   - [ ] Sin duplicados
   - [ ] Monto correcto (6 × monto individual)

3. **Límite por número/lotería (150 RD$):**
   - [ ] Agregar 14 @ Nacional 100 RD$
   - [ ] Agregar 14 @ Nacional 50 RD$
   - [ ] Agregar 14 @ Nacional 10 RD$ → DEBE RECHAZAR
   - [ ] Mensaje: "Solo puedes agregar RD$50 más..."

4. **Edición de jugada:**
   - [ ] Cambiar número
   - [ ] Cambiar monto
   - [ ] Cambiar lotería
   - [ ] Verificar que se actualiza en tabla
   - [ ] Verificar que se guarda bien en Firestore

5. **Copia a otra lotería:**
   - [ ] Agregar jugadas a Nacional
   - [ ] Botón "Copiar" lleva a modal
   - [ ] Seleccionar Leidsa
   - [ ] Verificar que se duplican correctamente

---

## 🐛 Debugging

### Ver logs de impresión:
```dart
// En bluetooth_printer_service.dart, agregar:
debugPrint('Intentando imprimir: ${bytes.length} bytes');
debugPrint('Conectado: $conectado');
```

### Ver datos guardados en Firestore:
```
Firebase Console → Firestore → tickets
Buscar por ticketId o fecha
```

### Verificar estado de impresora:
```dart
// En vender_numero.dart:
print('Impresora: ${BluetoothPrinterService.conectado}');
print('Estado conexión: ${await BluetoothPrinterService.estaConectado()}');
```

---

## ⚠️ Problemas Comunes y Soluciones

| Problema | Causa | Solución |
|----------|-------|----------|
| No se imprime | Impresora desconectada | Ir a "Impresora Bluetooth" y conectar |
| Duplicados en impresión | Múltiples pulsaciones rápidas | Verificar que banderas _guardando/_imprimiendo funcionan |
| Liga con 5 jugadas en lugar de 6 | Dígitos repetidos | Puede ser correcto si hay permutaciones idénticas |
| No aparecen loterías | Horarios sin datos | Verificar que HorarioService esté inicializado |
| Ticket con formato extraño | Problema con ESC/POS | Verificar ancho de papel (58mm) en impresora_screen |

---

## 📊 Cobertura de Pruebas

```
test/jugada_test.dart
├─ detectarComb
│  ├─ Quiniela ✅
│  ├─ Pale ✅
│  ├─ Tripleta ✅
│  └─ Inválido ✅
├─ detectarCombLiga
│  ├─ Quiniela ligada ✅
│  ├─ Pale ligado ✅
│  └─ Tripleta ligada ✅
├─ generarLigas
│  ├─ Pale (6 combos) ✅
│  ├─ Pale con repetidos ✅
│  ├─ Tripleta (6 combos) ✅
│  ├─ Quiniela (1 combo) ✅
│  └─ Limpieza de formato ✅
├─ generarSuperPale
│  ├─ Quiniela (2 perms) ✅
│  ├─ Pale (12 perms) ✅
│  ├─ Tripleta (30 perms) ✅
│  └─ Limpieza de formato ✅
└─ Jugada Model
   ├─ Creación ✅
   ├─ toMap ✅
   ├─ fromMap ✅
   └─ copyWith ✅

TOTAL: 20/20 PRUEBAS PASADAS ✅
```

---

## 📝 Checklist Final

Antes de declarar como completado:

- [ ] Todas las 20 pruebas unitarias pasan
- [ ] flutter analyze sin errores críticos
- [ ] Impresión sin duplicados (probado 3+ veces)
- [ ] Liga de pale genera 6 combinaciones correctas
- [ ] Liga de tripleta genera 6 combinaciones correctas
- [ ] Super pale funciona (mínimo en pruebas)
- [ ] Ticket impreso con formato correcto
- [ ] Datos guardados en Firestore correctamente
- [ ] UI no se bloquea durante operaciones
- [ ] Mensajes de error claros y útiles
