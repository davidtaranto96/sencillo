# 💰 Finanzas App

App mobile de finanzas personales construida con **React Native + Expo**, diseñada para darte control total sobre tu dinero con una experiencia visual limpia y moderna.

> **Filosofía:** Control total + decisiones conscientes + progreso visible

---

## ✨ Características principales

### 🤖 Textbox inteligente con IA
Registrá gastos en lenguaje natural:
- *"gasté 500 en pizza"* → detecta monto, categoría, tipo
- *"taxi 1200 con tarjeta"* → transporte, expense
- *"le presté 3000 a Juan"* → préstamo, persona

**Híbrido:** parser local (reglas + keywords en español) con fallback a **Claude Haiku** cuando la confianza es baja.

### 📊 Dashboard
- Patrimonio total en tiempo real
- Cuentas con saldo (scroll horizontal)
- Progreso de gastos del mes vs. ingresos
- Meta principal con barra de progreso
- Últimos movimientos

### 💸 Movimientos
- Búsqueda en tiempo real
- Filtros: Todos / Gastos / Ingresos / Transferencias
- Lista agrupada por fecha

### 📈 Presupuesto
- Distribución automática del sueldo (editable):
  - 🛡️ 15% Fondo de emergencia
  - 📈 25% Inversiones
  - 🏠 50% Gastos del mes
  - 🎉 10% Disfrute
- Gastos por categoría con progress bars

### 🎯 Objetivos
- Metas de ahorro con nombre, monto, color e ícono
- Progreso visual + días restantes + cuánto necesitás por mes
- Contribuciones manuales

### 👥 Personas y deudas
- Registro de quién te debe y a quién le debés
- Resumen total de deudas activas

### 🛍️ Compras inteligentes (anti-impulso)
- Guardá lo que querés comprar antes de decidir
- Esperá 7 / 15 / 30 días
- La app te pregunta si todavía lo querés

### 📅 Gastos fijos
- Alquiler, servicios, suscripciones
- Alertas de vencimiento
- Marcar como pagado

---

## 🛠️ Stack tecnológico

| Tecnología | Uso |
|------------|-----|
| React Native 0.81 + Expo 54 | Framework mobile |
| Expo Router 6 | Navegación file-based |
| react-native-paper | Material Design 3 (dark theme) |
| SQLite (expo-sqlite v16) | Base de datos local |
| Drizzle ORM | Query builder type-safe |
| Zustand 5 | Estado global |
| React Hook Form + Zod | Formularios y validación |
| MaterialCommunityIcons | Íconos |
| Claude Haiku API | Clasificación IA de gastos |
| date-fns | Manejo de fechas en español |

---

## 📱 Pantallas

```
app/
├── (tabs)/
│   ├── index.tsx          → Dashboard
│   ├── movimientos.tsx    → Lista de transacciones
│   ├── presupuesto.tsx    → Presupuesto y distribución de sueldo
│   ├── objetivos.tsx      → Metas de ahorro
│   └── mas.tsx            → Más opciones
├── transaction/
│   ├── new.tsx            → Nueva transacción (inteligente + manual)
│   └── [id].tsx           → Detalle de transacción
├── account/[id].tsx       → Detalle de cuenta
├── goal/[id].tsx          → Detalle de objetivo
├── personas/index.tsx     → Personas y deudas
├── compras/index.tsx      → Compras inteligentes
└── gastos-fijos/index.tsx → Gastos recurrentes
```

---

## 🗄️ Base de datos

18 tablas SQLite con Drizzle ORM:
`accounts`, `categories`, `transactions`, `recurring_expenses`, `salary_rules`, `emergency_funds`, `goals`, `persons`, `shared_expenses`, `shared_expense_participants`, `debt_records`, `credit_cards`, `wishlist_items`, `month_closures`, `achievements`

---

## 🚀 Cómo correr el proyecto

### Requisitos
- Node.js 18+
- Expo CLI
- Android Studio (para emulador/dispositivo Android)

### Instalación

```bash
git clone https://github.com/davidtaranto96/finanzas-app.git
cd finanzas-app
npm install
```

### Configuración IA (opcional)
Creá un archivo `.env.local` con tu API key de Anthropic:
```env
EXPO_PUBLIC_ANTHROPIC_API_KEY=sk-ant-...
```
Sin la key, el clasificador local funciona igual para la mayoría de los casos.

### Ejecutar

```bash
# Expo Dev Server (QR para Expo Go)
npm start

# Android (requiere emulador o dispositivo con USB debug)
npm run android

# Web (browser)
npm run web
```

### Abrir en Android Studio (modo nativo)
```bash
npx expo prebuild --platform android
# Luego abrir la carpeta android/ en Android Studio
```

---

## 📦 Estructura del proyecto

```
src/
├── components/
│   ├── SmartExpenseInput.tsx   → Textbox IA para registrar gastos
│   ├── cards/
│   │   ├── AccountCard.tsx
│   │   ├── GoalCard.tsx
│   │   └── TransactionItem.tsx
│   └── ui/
│       ├── FilterChips.tsx
│       ├── ProgressBar.tsx
│       └── ...
├── db/
│   ├── schema.ts              → Schema Drizzle ORM
│   ├── migrations.ts          → Migraciones SQL
│   ├── seeds.ts               → Datos iniciales
│   └── client.ts              → Cliente SQLite
├── services/
│   ├── accountService.ts
│   ├── transactionService.ts
│   ├── categoryService.ts
│   ├── goalService.ts
│   ├── budgetService.ts
│   └── aiClassifier.ts        → Claude Haiku fallback
├── stores/
│   ├── accountStore.ts
│   ├── transactionStore.ts
│   ├── categoryStore.ts
│   └── goalStore.ts
└── lib/
    ├── theme.ts               → Design tokens
    ├── paperTheme.ts          → Material Design 3 theme
    ├── types.ts               → TypeScript interfaces
    ├── utils.ts               → Helpers (formatCurrency, etc.)
    └── expenseParser.ts       → Parser local de gastos en español
```

---

## 🗺️ Roadmap

### MVP 1 ✅ (actual)
- Cuentas, categorías, transacciones
- Dashboard con resumen del mes
- Distribución de sueldo
- Fondo de emergencia
- Objetivos de ahorro
- Gastos fijos recurrentes
- Personas y deudas
- Compras inteligentes (anti-impulso)
- **Textbox IA híbrido**

### MVP 2 🔜
- Logros y desafíos (gamificación)
- Cierre de mes automático
- Tarjetas de crédito (cierres, vencimientos)
- Exportar a PDF / Excel
- Reportes y gráficos avanzados

### MVP 3 🔮
- Sincronización con bancos
- Score de salud financiera
- Recomendaciones IA personalizadas
- Simulaciones financieras

---

## 📄 Licencia

MIT — libre para uso personal y educativo.

---

*Construido con ❤️ y Claude Code*
