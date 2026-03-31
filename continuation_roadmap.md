# 🛣️ Roadmap de Handoff — Finanzas App (Flutter)

Este documento sirve como guía técnica para continuar el desarrollo, especialmente diseñado para ser consumido por un asistente de IA (Claude Code) o un desarrollador senior.

---

## 📍 Estado Actual (Snapshot)
- **UI & UX:** 100% Maquetada con estilo **AstroPay (Glassmorphism + Dark Mode)**.
- **Interactividad:** Implementada mediante *Long Press* (Gestión) y *FABs* (Creación).
- **Navegación:** `GoRouter` configurado con todas las rutas activas (`/`, `/accounts`, `/budgets`, `/goals`, `/wishlist`, etc.).
- **Persistencia (Capa Base):** `Drift` (SQLite) está configurado en `lib/core/database/`, pero la UI **todavía consume MockDataProviders**.
- **Wishlist:** Fase de reactividad completada (Lógica de compras descuenta del banner superior en memoria).

---

## 🏗️ Arquitectura del Proyecto
Sigue un patrón **Feature-First**:
- `domain/models/`: Entidades puras y `Equatable`.
- `presentation/pages/`: UI principal.
- `presentation/widgets/`: Componentes reutilizables (especialmente los `Add...BottomSheet`).
- `presentation/providers/`: Actualmente contienen `mockData` cargados manualmente.

---

## 🛠️ Lo que FALTA (Fase 8: Integración Real)

El objetivo es eliminar los Mocks y usar el `AppDatabase` de Drift. Pasos técnicos sugeridos:

### 1. Migración de Providers
- Reemplazar `mock_data_provider.dart` por providers que llamen a la instancia de `AppDatabase`.
- Ejemplo: `final budgetStreamProvider = StreamProvider((ref) => ref.watch(databaseProvider).watchAllBudgets());`

### 2. Conectar Bottom Sheets a DB
- Actualizar `onPressed` en:
    - `AddBudgetBottomSheet`: llamar a `db.into(db.budgetsTable).insert(...)`.
    - `AddGoalBottomSheet`: llamar a `db.into(db.goalsTable).insert(...)`.
    - `AddWishlistBottomSheet`: (Agregar tabla de Wishlist a Drift si aún no está, o persistir en memoria local).

### 3. Lógica de "Comprar" (Wishlist)
- Cuando se marque como "Comprado", debe:
    1. Restar el saldo de la `Account` seleccionada en la DB.
    2. Insertar una `Transaction` de tipo egreso.
    3. Eliminar el ítem de la tabla de Wishlist.

---

## 💡 Instrucciones para Claude Code
Para continuar, podés darle este prompt:
> "Claude, estoy en un punto donde la UI de esta app de finanzas está terminada pero usa datos mock. Necesito que me ayudes a implementar la **Fase 8: Integración de Base de Datos Real**. Ya tengo Drift configurado en `lib/core/database`. Empecemos reemplazando el `mockBudgetsProvider` por un `StreamProvider` real que consuma la base de datos y haciendo que el `AddBudgetBottomSheet` guarde datos de verdad."

---

## 🏁 Últimos Ajustes Realizados
- Corregidos todos los warnings de compilación (deprecated members, unused variables).
- Limpieza de `analysis_output`.
- Sincronización total con `origin/main`.
