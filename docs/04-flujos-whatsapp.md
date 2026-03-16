# 04 – Flujos de WhatsApp

Este documento describe los flujos conversacionales clave de Wasagro sobre WhatsApp, desde la perspectiva de texto y de máquina de estados.

---

## 4.1 Objetivos de diseño

- Mantener **fricción mínima** para trabajadores y gerentes.  
- Respetar el idioma y jerga local (no forzar lenguaje corporativo).  
- Hacer explícitos los puntos donde la IA necesita **aclarar información** (loop humano activo).  
- Hacer visible que los datos que viajan hacia arriba no se maquillan.

Flujos cubiertos aquí:

1. Onboarding de gerente (mini‑encuesta de preferencias).  
2. Primer informe semanal y drill‑down.  
3. Esqueleto del flujo de captura de evento de plaga.

---

## 4.2 Onboarding de gerente (mini‑encuesta)

### 4.2.1 Texto de ejemplo

Ver README para el detalle del contenido. Resumen:

1. Wasagro se presenta y pide permiso para hacer 5 preguntas.  
2. Pregunta foco principal (kilos, calidad, costos, sanidad, mixto).  
3. Pregunta horizonte de tiempo (día, semana, mes, todo).  
4. Pregunta nivel de detalle (finca, lote, ambos).  
5. Pregunta frecuencia de informes (diario, semanal, quincenal, solo alertas).  
6. Pregunta canales de entrega (solo WA, WA + web, WA + PDF/Excel).  
7. Muestra un resumen de configuración y avisa que será revisada por un humano.

### 4.2.2 Máquina de estados

Estados principales:

- `IDLE`
- `ONBOARDING_START`
- `ONBOARDING_Q1_FOCUS`
- `ONBOARDING_Q2_TIME_HORIZON`
- `ONBOARDING_Q3_DETAIL_LEVEL`
- `ONBOARDING_Q4_FREQUENCY`
- `ONBOARDING_Q5_CHANNEL`
- `ONBOARDING_SUMMARY`

Cada estado espera respuestas específicas (1–5, 1–4, etc.) y actualiza `user_preferences` al final.

---

## 4.3 Primer informe semanal + drill‑down

### 4.3.1 Texto de ejemplo

1. Mensaje A: aviso de que está listo el primer informe.  
2. Mensaje B: resumen semanal con:
   - foco principal,  
   - KPIs clave (producción, calidad, costos, sanidad),  
   - bloque de integridad de datos (cobertura, retraso, alertas abiertas),  
   - link al panel web.
3. Mensaje C: opciones de drill‑down (1: lotes críticos, 2: plagas, 3: costos, 4: nada).

### 4.3.2 Máquina de estados

Estados principales:

- `WEEKLY_REPORT_OPTIONS`: espera “1”–“4”.  
- `WEEKLY_REPORT_LOTS_DETAIL`: permite pedir detalle por lote.  
- `WEEKLY_REPORT_PESTS_DETAIL`: detalle de plagas.  
- `WEEKLY_REPORT_COSTS_DETAIL`: detalle de costos.

Transiciones típicas:

- `WEEKLY_REPORT_OPTIONS` + "1" → enviar lista de lotes críticos → `WEEKLY_REPORT_LOTS_DETAIL`.  
- `WEEKLY_REPORT_OPTIONS` + "4" → mensaje de cierre → `IDLE`.  
- `WEEKLY_REPORT_LOTS_DETAIL` + "menu" → `WEEKLY_REPORT_OPTIONS`.

---

## 4.4 Esqueleto de flujo para captura de evento de plaga

Este flujo aún está en diseño, pero a alto nivel funciona así:

1. Trabajador envía audio o texto describiendo un problema.  
2. IA intenta extraer: tipo de problema, lote, severidad, fecha aproximada.  
3. Si faltan datos obligatorios (ej. lote), el sistema pregunta:

   > "¿En qué lote viste eso?"

4. Una vez completo el mínimo (tipo, lote, fecha, severidad), se confirma el evento:

   > "Registré: plaga **{pest_name}** con severidad **{severity}** en **Lote {n}** el **{fecha_hora}**. Si algo está mal, dímelo para corregirlo."

5. Dependiendo de la severidad y el contexto, se puede disparar un flujo de asistencia (recomendaciones, checklist, avisar a jefe de campo, etc.).

La definición completa de estados para este flujo se añadirá en versiones futuras, pero reutilizará el mismo patrón de `wa_conversations` y campos de `mandatory_missing` en los eventos.
