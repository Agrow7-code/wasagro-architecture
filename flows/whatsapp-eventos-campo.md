# Flujo de WhatsApp – Eventos de campo (plaga / insumo / labor / gasto)

Este documento describe el flujo conversacional completo para registrar **eventos de campo** vía WhatsApp en Wasagro.

Se enfoca en cuatro tipos de evento frecuentes:
- **Plaga / enfermedad** (`pest`)
- **Aplicación de insumo** (`input_application`)
- **Avance de labor** (`task_progress`)
- **Gasto / costo** (`expense`)

La lógica está pensada para un **router de complejidad** + **agente estructurador PDR/SR**, pero aquí nos centramos en los textos y estados de conversación.

---

## 1. Principios del flujo

1. **Mínima fricción**: el trabajador habla o escribe como lo haría en un chat normal.
2. **Loop humano activo**: si faltan datos críticos (lote, dosis, fecha), el sistema pregunta de vuelta.
3. **No asumir nivel finca para eventos de campo**: plagas, aplicaciones y labores SIEMPRE deben quedar atadas a un lote, salvo casos explícitamente marcados.
4. **Confirmación transparente**: siempre se devuelve al usuario lo que se registró, para que pueda corregir.

---

## 2. Estados de conversación

Estados específicos para flujo de eventos de campo en `wa_conversations.current_state`:

- `FIELD_EVENT_IDLE` – estado por defecto (ningún flujo activo).
- `FIELD_EVENT_START` – se recibió un mensaje que parece evento de campo.
- `FIELD_EVENT_INTERPRETED` – IA propuso un borrador de evento.
- `FIELD_EVENT_NEEDS_CLARIFICATION` – faltan campos obligatorios.
- `FIELD_EVENT_CONFIRMATION_SENT` – se envió confirmación al usuario.

Además, usamos campos en `events`:

- `completeness_status` – `pending` / `needs_clarification` / `complete`.
- `mandatory_missing` – JSON con lista de campos faltantes (ej. `["id_field","dose"]`).

---

## 3. Inicio del flujo (`FIELD_EVENT_START`)

### 3.1 Trigger

Cualquier mensaje entrante desde un usuario con rol de **campo** (`worker` o `field_manager`) que el router clasifique como pudiendo ser:

- plaga/enfermedad,  
- aplicación de insumo,  
- avance de labor,  
- gasto/costo de campo.

Ejemplos de mensajes:

- "Encontré roya fuerte en el lote 4."
- "Apliqué 5 bombadas de fungicida en el bloque de abajo."
- "Terminamos la deshoja en el Lote 7."
- "Gasté 50 dólares en combustible para la bomba."

### 3.2 Acciones del sistema

1. Guardar mensaje en `raw_messages`.  
2. Ejecutar STT/OCR si aplica → `message_processed`.  
3. Router predice `event_type` y llama al agente estructurador (PDR/SR) para generar un borrador de `event`.

Luego, la conversación pasa a `FIELD_EVENT_INTERPRETED`.

---

## 4. Estado `FIELD_EVENT_INTERPRETED`

En este estado ya existe un borrador de evento con algunos campos propuestos:

- `event_type` (ej. `pest`).
- `id_farm`, `id_user` (por contexto del número). 
- Candidatos para `id_field`, `event_time`, `pest_name`, `severity`, etc.

El backend evalúa qué campos son **obligatorios** según `event_type`:

- Para `pest`, `input_application`, `task_progress`:
  - `id_field` (lote),  
  - `event_time` (al menos fecha aproximada).
- Para `input_application` además:
  - insumo, dosis, unidad, superficie.
- Para `expense`:
  - monto, moneda, tipo de gasto.

Si *no* faltan campos críticos → pasar directo a confirmación (`FIELD_EVENT_CONFIRMATION_SENT`).  
Si *sí* faltan → llenar `mandatory_missing` y pasar a `FIELD_EVENT_NEEDS_CLARIFICATION`.

No se envía mensaje al usuario todavía; se prepara la pregunta adecuada.

---

## 5. Estado `FIELD_EVENT_NEEDS_CLARIFICATION`

En este estado el sistema sabe qué falta. Se generan preguntas **mínimas y concretas**, en el idioma del usuario.

### 5.1 Ejemplo: falta lote (`id_field`)

`mandatory_missing = ["id_field"]`

Mensaje al usuario:

> Wasagro:  
> Para registrar bien esto, necesito saber **en qué lote fue**.  
>  
> ¿En qué lote viste eso?

- Si el usuario responde con un nombre o número de lote ("4", "Lote 4", "bloque de abajo"), el backend:
  - intenta mapearlo a un `id_field` válido de `fields` para esa finca,  
  - si hay `N` candidatos, puede responder:

    > "¿Te refieres a uno de estos?  
    > 1) Lote 4 – Bajo  
    > 2) Lote 4 – Alto  
    > Responde con el número de opción."

- Cuando se resuelve `id_field`, se retira `"id_field"` de `mandatory_missing`.

### 5.2 Ejemplo: falta dosis en aplicación de insumo

`mandatory_missing = ["dose","dose_unit"]`

Mensaje:

> Wasagro:  
> Para registrar la aplicación, necesito la **dosis** que usaste.  
>  
> ¿Cuánto aplicaste y en qué unidad? (por ejemplo: 2 litros por hectárea, 3 bombadas, 1 saco por lote)

Respuesta del usuario se envía al agente estructurador, que actualiza el JSON:

```json
{
  "dose": 2,
  "dose_unit": "L/ha"
}
```

Se retiran `"dose"` y `"dose_unit"` de `mandatory_missing`.

### 5.3 Ejemplo: falta fecha/hora (`event_time`)

`mandatory_missing = ["event_time"]`

Mensaje:

> Wasagro:  
> ¿Cuándo fue esto aproximadamente?  
>  
> Puedes decir "hoy en la mañana", "ayer en la tarde" o una hora aproximada.

La IA interpreta la expresión relativa y la normaliza a un `TIMESTAMPTZ`, ajustando `source_time_confidence`.

### 5.4 Salida de `FIELD_EVENT_NEEDS_CLARIFICATION`

- Mientras `mandatory_missing` no esté vacío, el sistema mantiene la conversación en este estado y formula la siguiente pregunta mínima.  
- Cuando queda vacío, se marca `completeness_status = 'complete'` y se pasa a `FIELD_EVENT_CONFIRMATION_SENT`.

---

## 6. Estado `FIELD_EVENT_CONFIRMATION_SENT`

Una vez que el evento tiene todos los campos mínimos:

1. Se inserta/actualiza el registro en `events` + `event_payloads`.  
2. Se genera un mensaje de confirmación claro para el usuario.

### 6.1 Ejemplos de confirmación

#### Plaga

> Wasagro:  
> Registré: plaga **{pest_name}** con severidad **{severity}** en **Lote {field_name}** el **{fecha_hora_normalizada}**.  
> Si algo está mal, dímelo y lo corrijo ahora.

#### Aplicación de insumo

> Wasagro:  
> Registré: aplicación de **{input_name}** en **Lote {field_name}**,  
> dosis **{dose} {dose_unit}** sobre **{area_ha} ha** el **{fecha_hora_normalizada}**.  
> Si algo está mal, dímelo y lo ajustamos.

#### Avance de labor

> Wasagro:  
> Registré: avance de **{labor_name}** en **Lote {field_name}**,  
> estado **{status_laboral}** el **{fecha_hora_normalizada}**.

#### Gasto

> Wasagro:  
> Registré: gasto de **{amount} {currency}** por **{concepto}** para la finca **{farm_name}** el **{fecha_hora_normalizada}**.

### 6.2 Correcciones

Si el usuario responde algo como “no”, “está mal”, “no fue en ese lote”, el flujo puede:

1. Volver a `FIELD_EVENT_NEEDS_CLARIFICATION` con `mandatory_missing` ajustado (por ejemplo, volver a preguntar solo por lote).  
2. O marcar el evento como `status = 'rejected'` y crear uno nuevo.

---

## 7. Estado `FIELD_EVENT_IDLE`

Es el estado por defecto cuando no hay flujo de evento activo.

Lógica recomendada en el bot:

- Si el usuario envía “configurar” → delegar al flujo de onboarding de gerente.  
- Si el usuario envía “resumen” → delegar al flujo de informes.  
- Si el mensaje parece evento de campo → iniciar `FIELD_EVENT_START` y seguir este flujo.  
- Si es otro tipo de mensaje → manejar con respuestas genéricas o transferir a soporte humano.

---

## 8. Notas de implementación

- El `whatsapp-bot-service` debe consultar y actualizar `wa_conversations` en cada mensaje.  
- El agente estructurador (PDR/SR) y el router de complejidad corren en segundo plano; el bot solo muestra preguntas/respuestas.
- Los textos pueden adaptarse a cada país y jerga (por ejemplo, "lote" vs "parcela" vs "bloque").
