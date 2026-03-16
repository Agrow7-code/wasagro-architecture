# 11 – Loop humano activo: SLAs y matriz de escalamiento

Este documento define los SLAs del loop humano activo en Wasagro y la lógica de escalamiento automático para eventos sin confirmación.

> **Por qué es crítico**: el loop humano mal diseñado se convierte en el cuello de botella que destruye la experiencia del trabajador de campo. Una plaga sin confirmar 4 horas ya puede haber causado daño irreversible. La respuesta automática cuando el humano no responde en tiempo es lo que separa a Wasagro de un bot de captura básico.

---

## 11.1 Principios del loop humano

1. **El humano confirma, no captura**: el sistema captura automáticamente el evento desde el campo. El humano solo interviene cuando el riesgo lo requiere.
2. **SLA explícito**: cada tipo de evento tiene un tiempo máximo sin confirmación humana, pasado el cual el sistema actúa automáticamente.
3. **Escalamiento transparente**: el trabajador de campo sabe en segundos si su reporte fue registrado. El gerente sabe en minutos si hay algo crítico sin atender.
4. **No bloquear la operación**: si el humano no responde, el sistema escala (no se detiene).

---

## 11.2 Matriz de SLA por tipo de evento

| Tipo de evento | Riesgo | SLA máximo sin confirmación | Acción automática al vencer SLA | Receptor del escalamiento |
|---|---|---|---|---|
| `pest` — severidad alta | Crítico | **2 horas** | Alerta push a gerente + notificación WhatsApp | `farm_manager` → `advisor` |
| `pest` — severidad media | Alto | 8 horas | Alerta en panel web | `farm_manager` |
| `pest` — severidad baja | Medio | 24 horas | Registro como pendiente en próximo informe | `field_manager` |
| `input_application` — dosis alta o producto restringido | Crítico | **1 hora** | Bloqueo de recomendación + alerta gerente | `farm_manager` → `advisor` |
| `input_application` — dosis normal | Bajo | 48 horas | Auto-aprobado sin confirmación | — |
| `task_progress` | Bajo | 72 horas | Auto-aprobado | — |
| `expense` | Bajo | 72 horas | Auto-aprobado | — |
| Evento con `completeness_status = needs_clarification` | Variable | **30 minutos** | Re-envío automático de la pregunta mínima | mismo usuario |

---

## 11.3 Flujo de escalamiento

```text
Evento registrado
      │
      ▼
¿Requiere confirmación humana?
  │ Sí (riesgo alto/crítico)
  ▼
Notificar a receptor primario (WhatsApp + panel)
      │
      ▼
¿Confirmación dentro del SLA?
  ├── Sí → evento confirmado, continuar flujo normal
  └── No → escalar al receptor siguiente en la cadena
           │
           ▼
        ¿Confirmación dentro de SLA extendido?
          ├── Sí → evento confirmado con nota de retraso
          └── No → marcar evento como 'escalated_unresolved'
                     Registrar en log de auditoría
                     Incluir en reporte semanal como brecha
```

---

## 11.4 Tablas de base de datos requeridas

### 11.4.1 `escalation_rules` (nueva tabla)

Define las reglas de escalamiento por tipo de evento y nivel de riesgo:

```sql
CREATE TABLE escalation_rules (
  id_rule          SERIAL PRIMARY KEY,
  event_type       VARCHAR(50) NOT NULL,
  risk_level       VARCHAR(20),           -- 'low','medium','high','critical'
  max_hours        NUMERIC NOT NULL,       -- SLA máximo en horas
  escalate_to_role INT REFERENCES roles(id_role),
  action_on_breach VARCHAR(100),           -- 'auto_approve','alert_manager','block_recommendation'
  active           BOOLEAN DEFAULT TRUE
);
```

### 11.4.2 Campos adicionales en `events`

```sql
ALTER TABLE events
  ADD COLUMN escalated_at     TIMESTAMPTZ,  -- cuándo se escaló el evento
  ADD COLUMN escalated_to     INT REFERENCES users(id_user),  -- a quién se escaló
  ADD COLUMN escalation_note  TEXT;         -- razón del escalamiento
```

### 11.4.3 Job de verificación de SLAs

Un cron job (cada 15 minutos) ejecuta:

```sql
-- Detectar eventos que vencieron su SLA y no tienen confirmación
SELECT e.id_event, e.event_type, e.risk_level, e.created_at,
       er.max_hours, er.escalate_to_role, er.action_on_breach
FROM events e
JOIN escalation_rules er
  ON er.event_type = e.event_type
 AND er.risk_level = e.risk_level
WHERE e.status IN ('pending_review')
  AND e.escalated_at IS NULL
  AND e.created_at < now() - (er.max_hours * INTERVAL '1 hour');
```

El resultado alimenta el servicio de escalamiento que envía notificaciones y actualiza `escalated_at`.

---

## 11.5 Experiencia del usuario

### Para el trabajador de campo

Despues de enviar un evento crítico:

> Wasagro:  
> Registré: plaga **sigatoka negra** severidad **alta** en **Lote 7** hoy a las 07:15.  
> **Tu jefe de campo será notificado en los próximos minutos.** Si algo está mal, dímelo.

### Para el gerente (cuando vence SLA sin confirmar)

> Wasagro ⚠️:  
> Alerta no atendida: **sigatoka negra alta** en **Lote 7** — reportada hace **2h 15min** por **[nombre]**.  
> El jefe de campo aún no ha confirmado acción.  
> ¿Quieres que yo envíe una alerta directa a [nombre del jefe]?  
> 1) Sí, notifícalo ahora  
> 2) Yo me encargo

---

## 11.6 Por qué esto genera confianza real en el gerente

El problema del Excel maquillado no es solo de captura — es de **visibilidad del problema en tiempo real**. Un gerente que sabe que el sistema le avisará automáticamente si un evento crítico no fue atendido en 2 horas, tiene una razón concreta para confiar en Wasagro como sistema de gestión operativa, no solo como bot de registro.
