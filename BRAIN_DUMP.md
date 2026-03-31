# 🧠 Brain Dump: Finanzas App (Flutter + Drift)

Este documento es una guía de transferencia para que Claude (o cualquier otro asistente) pueda continuar con el desarrollo sin perder contexto.

## 🚀 Estado Actual
La aplicación ha completado la migración de **Mock Data** a una base de datos real impulsada por **Drift (SQLite)**. Todos los flujos críticos (Dashboard, Cuentas, Movimientos) ahora consumen streams de la base de datos.

### Infraestructura Clave
- **Base de Datos**: `lib/core/database/` (Usa Drift).
- **Servicios de Lógica**: `lib/core/logic/`.
    - `AccountService`: Maneja depósitos, retiros y pagos de tarjetas.
    - `TransactionService`: Registro de movimientos.
    - `MonthClosureService`: Lógica de cierre de mes y ciclo de deuda.
- **Providers**: `lib/core/database/database_providers.dart` (Streams reactivos).

## 🛠️ Problemas Técnicos Resueltos
1. **Error de SQLite en Android**: Se corrigió el error de `libsqlite3.so not found` añadiendo `sqlite3_flutter_libs` y un failsafe en `main.dart`. **Nota**: Si el error persiste, ejecutar `flutter clean && flutter run`.
2. **Escapado de Símbolos**: Se corrigieron errores de sintaxis en `AccountsPage` y `PeoplePage` relacionados con el carácter `$`.
3. **Migración de UI**: `HomePage` y `TransactionsPage` ahora muestran datos reales.

## 📋 Pendientes Actuales (Actualizado: 31-Mar-2026)

### RESUELTO EN ESTA SESIÓN ✅
1. **Error crítico SQLite**:
   - Causa: sqlite3_flutter_libs 0.6.0 no empaquetaba libsqlite3.so
   - Solución: Downgrade a 0.5.42 + packagingOptions pickFirst + ABI filters
   - Resultado: libsqlite3.so ahora se incluye en el APK (arm64-v8a, armeabi-v7a, x86_64)

2. **Posicionamiento de UI**:
   - FAB: Aumentado padding de +85 → +120 en Budget, Goals, Accounts, People, Wishlist
   - Bottom sheets: Aumentado padding de +32 → +70 → +100 para no quedar ocultos bajo navbar
   - AppBar MonthlyOverview: Botón "Cerrar Mes" movido a actions para evitar overflow

3. **Home page crash**:
   - Error "Bad state: No element" cuando accounts.isEmpty
   - Solución: Validación de lista vacía al inicio

---

## 📋 Pendientes Pendientes (Backlog para próxima sesión)

### 1. Motor de Ingesta Inteligente (PDFs) - YA IMPLEMENTADO pero pendiente testeo
El usuario quiere que la app "desglose" los resúmenes de tarjeta de forma automática.
- **Archivos de referencia**: `CUENTAS/Resumen8abr2026.pdf` y `CUENTAS/Resumen19mar2026-1.pdf`.
- **Tarea**: Crear un servicio que use Regex o un parser de texto para identificar:
    - Fecha de transacción.
    - Descripción.
    - Monto.
- **Input**: El usuario pegará el texto del PDF o se implementará una carga de archivo.
- **Integración**: Los gastos extraídos deben impactar el balance de la tarjeta correspondiente (`visa_credit` o `mc_credit`).

### 2. Menú de Gastos en Personas (Splitwise-style)
- **Actual**: Solo hay FAB que abre bottom sheet de "Agregar Gasto"
- **Pendiente**: Cambiar a menú contextual tipo Splitwise con opciones:
  - Agregar gasto (mío)
  - Deuda a amigo
  - Me debe dinero
  - Confirmar pago
- **Ubicación**: `lib/features/people/presentation/pages/people_page.dart`

### 3. Testeo completo en dispositivo
- ✅ SQLite: Sin crashes en Home, Movimientos, Personas, Compras Inteligentes
- ⚠️ **PENDIENTE VERIFICAR**:
  - FABs posicionamiento (presupuesto, objetivos, cuentas) con +120
  - Bottom sheets no quedan ocultos con +100 padding
  - Ingresa de PDFs: Seleccionar archivo → parsing → review → import a BD

### 4. Ciclo del Dinero (Logic Check)
- Validar que al "Pagar Resumen" en `AccountsPage`, el movimiento se registre correctamente en el historial.
- Asegurar que el "Presupuesto Seguro" (`safeBudget`) en el Dashboard refleje correctamente el efectivo disponible menos las deudas de TC y gastos fijos ($317.000).

### 5. Pantalla de Carga Estética para PDF Ingestion
- Ya implementada en `lib/shared/widgets/pdf_processing_overlay.dart`
- **Pendiente**: Verificar que funcione correctamente al importar múltiples transacciones

## 📊 Datos del Usuario (Para el Seeder)
- **Deuda Visa**: $511.659
- **Deuda Mastercard**: $1.522.588
- **Saldo Cash ARS**: Debe derivarse de las cuentas bancarias (Nación, etc.).

## 🔧 Comandos Útiles
- Generar código: `dart run build_runner build --delete-conflicting-outputs`
- Limpieza total: `flutter clean; flutter pub get`
