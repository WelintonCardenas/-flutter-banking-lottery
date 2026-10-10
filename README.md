# 🎰 Banca Lotería - App Flutter

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.11+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange?logo=firebase)
![License](https://img.shields.io/badge/License-MIT-green)

Una aplicación profesional de banca y lotería desarrollada en Flutter con funcionalidades completas de ventas, gestión de usuarios y reportes.

[Ver en GitHub](https://github.com/WelintonCardenas/-flutter-banking-lottery) • [Características](#-características) • [Instalación](#-instalación)

</div>

---

## 📋 Descripción

**Banca Lotería** es una aplicación móvil robusta diseñada para facilitar la gestión integral de operaciones de banca y lotería. Cuenta con autenticación segura, gestión de clientes, venta de números, administración de horarios y generación de reportes en tiempo real.

La aplicación está optimizada para dispositivos móviles con interfaces responsivas y soporte para impresoras térmicas Bluetooth para emisión de tickets.

---

## ✨ Características

### 🔐 Autenticación y Seguridad
- ✅ Sistema de login seguro con Firebase Authentication
- ✅ Registro de nuevos usuarios
- ✅ Gestión de contraseñas y cambio de credenciales
- ✅ Control de sesiones

### 💰 Gestión de Ventas
- ✅ Venta de números de lotería con interfaz intuitiva
- ✅ Selector múltiple de loterias
- ✅ Copiar configuración de loterias entre operaciones
- ✅ Panel de venta completo y organizado
- ✅ Generación automática de tickets

### 👥 Gestión de Clientes
- ✅ Registro y administración de clientes
- ✅ Listado de números jugados
- ✅ Historial de transacciones
- ✅ Base de datos con Firestore

### 📊 Reportes y Análisis
- ✅ Reportes detallados de ventas
- ✅ Análisis de ganancias y pérdidas
- ✅ Datos en tiempo real desde Firestore

### 🕐 Administración de Horarios
- ✅ Gestión de horarios de juego
- ✅ Configuración de bandas horarias
- ✅ Visualización con badges informativos

### 👨‍💼 Gestión de Usuarios
- ✅ Control de usuarios del sistema
- ✅ Asignación de roles
- ✅ Edición de perfiles
- ✅ Administración de permisos

### 🖨️ Impresión
- ✅ Soporte para impresoras térmicas Bluetooth
- ✅ Generación de tickets formateados
- ✅ Múltiples formatos de salida
- ✅ Permisos de Bluetooth automáticos

### 📱 Interfaz de Usuario
- ✅ Diseño responsivo y adaptable
- ✅ Teclado personalizado para entrada de datos
- ✅ Modales de información
- ✅ Tablas interactivas
- ✅ Iconos personalizados

---

## 🛠️ Tecnologías

### Frontend
- **Flutter** 3.11+ - Framework de desarrollo multiplataforma
- **Dart** 3.11+ - Lenguaje de programación

### Backend & Servicios
- **Firebase**
  - Firestore - Base de datos en tiempo real
  - Firebase Authentication - Autenticación segura
  - Firebase Core - Configuración central

### Dependencias Clave
`yaml
firebase_core: ^4.7.0
firebase_auth: ^6.4.0
cloud_firestore: ^6.3.0
print_bluetooth_thermal: ^1.2.1
permission_handler: ^11.3.1
path_provider: ^2.1.3
`

---

## 📦 Estructura del Proyecto

`
lib/
├── main.dart                          # Punto de entrada de la aplicación
├── models/                            # Modelos de datos
│   ├── cliente.dart                   # Modelo de cliente
│   ├── jugada.dart                    # Modelo de jugada
│   ├── ticket.dart                    # Modelo de ticket
│   └── resultado.dart                 # Modelo de resultado
├── screens/                           # Pantallas de la aplicación
│   ├── login.dart                     # Pantalla de inicio de sesión
│   ├── registro.dart                  # Pantalla de registro
│   ├── dashboard.dart                 # Panel principal
│   ├── vender_numero.dart             # Venta de números
│   ├── clientes.dart                  # Gestión de clientes
│   ├── usuarios_screen.dart           # Gestión de usuarios
│   ├── reportes_screen.dart           # Reportes
│   ├── admin_horarios_screen.dart     # Administración de horarios
│   ├── lista_numeros.dart             # Listado de números
│   └── impresora_screen.dart          # Gestión de impresora
├── services/                          # Servicios y lógica de negocio
│   ├── auth_service.dart              # Autenticación
│   ├── database_service.dart          # Base de datos Firestore
│   ├── ticket_service.dart            # Servicio de tickets
│   ├── horario_service.dart           # Servicio de horarios
│   └── bluetooth_printer_service.dart # Servicio de impresora Bluetooth
├── widgets/                           # Componentes reutilizables
│   ├── tabla_widgets.dart             # Widgets de tabla
│   ├── teclado_widget.dart            # Teclado personalizado
│   ├── selector_loteria.dart          # Selector de loterias
│   ├── vender_tabla.dart              # Tabla de venta
│   ├── clientes_widgets.dart          # Widgets de cliente
│   ├── bluetooth_modal.dart           # Modal de Bluetooth
│   └── ticket_modals.dart             # Modales de ticket
└── utils/                             # Utilidades
    ├── responsive_utils.dart          # Utilities responsivas
    ├── ticket_formatter.dart          # Formateo de tickets
    └── ticket_formatter_origin.dart   # Formateo alternativo
`

---

## 🚀 Instalación

### Requisitos Previos
- **Flutter** 3.11 o superior ([Descargar](https://flutter.dev/docs/get-started/install))
- **Dart** 3.11 o superior
- **Android Studio** o **Xcode** para emuladores
- Cuenta de **Firebase** configurada

### Pasos de Instalación

1. **Clona el repositorio**
`ash
git clone https://github.com/WelintonCardenas/-flutter-banking-lottery.git
cd banca_loteria
`

2. **Instala las dependencias**
`ash
flutter pub get
`

3. **Configura Firebase**
   - Ve a [Firebase Console](https://console.firebase.google.com/)
   - Crea un nuevo proyecto o usa uno existente
   - Descarga google-services.json (Android) y GoogleService-Info.plist (iOS)
   - Coloca los archivos en las ubicaciones correspondientes:
     - Android: ndroid/app/
     - iOS: ios/Runner/

4. **Genera los iconos**
`ash
flutter pub run flutter_launcher_icons
`

5. **Ejecuta la aplicación**
`ash
# En emulador
flutter run

# En dispositivo conectado
flutter run -d <device_id>
`

---

## 📝 Uso

### Inicio de Sesión
1. Abre la aplicación
2. Ingresa tus credenciales (usuario y contraseña)
3. Presiona "Iniciar Sesión"

### Vender un Número
1. Ve a la sección **"Vender Número"**
2. Selecciona la lotería deseada
3. Ingresa el número
4. Especifica el monto apostado
5. Selecciona el cliente
6. Confirma la venta
7. La impresora generará automáticamente el ticket

### Ver Reportes
1. Accede a **"Reportes"**
2. Filtra por fecha o rango de fechas
3. Visualiza ventas, ganancias y análisis en tiempo real

### Gestionar Clientes
1. Ve a **"Clientes"**
2. Visualiza el listado de clientes registrados
3. Consulta el historial de números jugados
4. Edita información de clientes

---

## 🧪 Testing

Ejecuta las pruebas unitarias:
`ash
flutter test
`

---

## 🔧 Configuración Avanzada

### Permisos Requeridos (Android)
`xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
`

### Variables de Entorno
Configura las credenciales de Firebase en irebase_options.dart según tu proyecto.

---

## 📱 Compatibilidad

- **Android**: 7.0 (API 24) o superior
- **iOS**: 11.0 o superior
- **Web**: Compatible (experimental)
- **Windows**: Disponible

---

## 🤝 Contribuir

Las contribuciones son bienvenidas. Para cambios mayores:

1. Fork el repositorio
2. Crea una rama para tu feature (git checkout -b feature/AmazingFeature)
3. Commit tus cambios (git commit -m 'Add AmazingFeature')
4. Push a la rama (git push origin feature/AmazingFeature)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

---

## 👨‍💻 Autor

**Welinton Cardenas**
- GitHub: [@WelintonCardenas](https://github.com/WelintonCardenas)
- Email: welintoncardenas27@gmail.com

---

## 📞 Soporte

Si encuentras problemas o tienes sugerencias, abre un [Issue](https://github.com/WelintonCardenas/-flutter-banking-lottery/issues) en GitHub.

---

## 🙏 Agradecimientos

- [Flutter](https://flutter.dev/) - Excelente framework
- [Firebase](https://firebase.google.com/) - Backend robusto
- La comunidad de Flutter por sus útiles librerías

---

<div align="center">

**Hecho con ❤️ en Flutter**

⭐ Si te gusta este proyecto, no olvides dejar una estrella en GitHub

</div>
