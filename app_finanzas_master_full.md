# MASTER DOCUMENT — App Finanzas Personales (Flutter)

## 1. VISIÓN GENERAL
App de finanzas personales moderna que combina:
- control total del dinero
- planificación del sueldo
- objetivos de ahorro
- gastos compartidos
- préstamos entre personas
- decisiones de compra inteligentes
- análisis mensual
- IA para carga rápida

Filosofía:
“Control total + decisiones conscientes + progreso visible”

---

## 2. STACK OBLIGATORIO
- Flutter (obligatorio)
- Riverpod (estado)
- go_router (navegación)
- Drift + SQLite (persistencia)
- Material 3 + design system propio

---

## 3. ARQUITECTURA

Feature-first + capas:

lib/
  app/
  core/
  shared/
  features/

Cada feature:
- presentation/
- application/
- domain/
- data/

Regla:
La lógica de negocio NO debe estar en widgets.

---

## 4. NAVEGACIÓN

Tabs:
- Home
- Movimientos
- Presupuesto
- Objetivos
- Más

Más:
- Mes
- Personas
- Compras inteligentes
- Reportes
- Configuración

---

## 5. HOME (pantalla principal)

Debe mostrar:
- saldo total
- disponible
- presupuesto
- fondo de emergencia
- objetivo principal
- alertas
- accesos rápidos
- cierres de tarjeta

Botón flotante (+):
- gasto
- ingreso
- compartido
- préstamo
- compra

---

## 6. MÓDULO MES

Pantalla secundaria (NO principal)

Tabs:
- Resumen
- Detalle
- Compartidos
- Préstamos
- Métricas
- Notas

Incluye:
- ingresos
- gastos fijos
- extraordinarios
- compartidos
- balance
- ahorro
- inversión

---

## 7. REGLA CRÍTICA

Separar SIEMPRE:

- monto pagado
- gasto real
- monto a recuperar
- recuperado
- pendiente

Ejemplo:
60.000 pagado → 20.000 real → 40.000 recuperar

---

## 8. GASTOS COMPARTIDOS

Cada gasto:
- puede tener personas
- puede tener grupo
- impacta en mes
- genera deuda

Campos:
- total
- parte propia
- parte ajena
- recuperado
- pendiente

---

## 9. PERSONAS Y SALDOS

Vista:
- quién me debe
- cuánto debo
- historial
- saldo total

Diferenciar:
- gastos compartidos
- préstamos

---

## 10. PRÉSTAMOS

Distinto de compartidos.

- préstamo directo
- devolución
- pendiente

---

## 11. GRUPOS

Ejemplos:
- Viaje
- Lolla 2026
- Casa
- Sin grupo

Cada gasto puede pertenecer a grupo.

---

## 12. MÉTRICAS

- gasto total
- gasto real
- adelantado
- recuperado
- pendiente
- top categoría
- top persona
- top grupo

---

## 13. IA INPUT

Ejemplo:
“Pagué 45 mil sushi con Juan y Sofi dividir en 3”

Debe inferir:
- monto
- personas
- grupo
- categoría
- cuenta
- tipo
- deuda

---

## 14. COMPONENTES UI

- SummaryCard
- GoalCard
- AccountCard
- DebtCard
- FloatingActionButton
- ProgressBar
- Chips filtros
- Cards de grupo/persona

---

## 15. FEATURES

dashboard
transactions
budget
goals
monthly_overview
shared_expenses
people
loans
wishlist
credit_cards
alerts
reports

---

## 16. FASES

Fase 1:
- base app
- cuentas
- transacciones

Fase 2:
- presupuesto
- objetivos

Fase 3:
- compartidos
- personas
- préstamos
- mes

Fase 4:
- IA
- métricas
- alertas

---

## 17. RESULTADO ESPERADO

Una app:
- rápida
- clara
- escalable
- lista para producción
- con arquitectura sólida

NO quiero ideas sueltas.
Quiero implementación real.
