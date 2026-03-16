# WhatsApp Business API — Decisión de BSP e Infraestructura

Este documento describe la arquitectura de integración con WhatsApp Business API para Wasagro, la decisión de BSP (Business Solution Provider), y las implicaciones operativas y de costo.

> **Necesario antes del primer usuario real.** Los flujos de WhatsApp (máquina de estados, onboarding, drill-down) están documentados en `docs/04-flujos-whatsapp.md`. Este documento cubre la capa de infraestructura que los hace posibles en producción.

---

## 1. Opciones de acceso a WhatsApp Business API

| Opción | Descripción | Costo adicional | Recomendación |
|---|---|---|---|
| **Meta directo (Cloud API)** | Acceso directo a la API de Meta sin intermediario. Requiere cuenta de Meta Business verificada. | Solo costo por conversación de Meta | ✅ Recomendado para MVP en adelante |
| **BSP con markup** (Twilio, Vonage, MessageBird, Infobip) | El BSP cobra un markup sobre el precio de Meta (~$0.005–0.010 extra por conversación) + fee mensual ($50–500/mes) | Markup + fee mensual | ⚠️ Solo si Meta directo no está disponible |
| **BSP LATAM especializado** (GupShup, WatiApp, 360Dialog) | BSPs con presencia en LATAM, soporte en español, integración más rápida. Fee mensual más bajo. | ~$49–149/mes fijo + conversaciones | ⚠️ Para MVP rápido si Meta directo tarda |

### Decisión recomendada

**MVP (0–50 fincas):** usar **360Dialog** o **WatiApp** (BSP LATAM) para velocidad de integración. Costo adicional: ~$49–79/mes fijo. Permite lanzar en días en lugar de semanas.

**v1 (50+ fincas):** migrar a **Meta Cloud API directa** para eliminar el markup del BSP. A 50 fincas, el markup del BSP ya supera el ahorro de tiempo de integración.

---

## 2. Proceso de activación (Meta directo)

1. **Crear cuenta Meta Business Manager** (si no existe).
2. **Verificar el negocio** con Meta — requiere documentos legales de la empresa (RUC, RNC o equivalente). Tiempo: 1–5 días hábiles.
3. **Crear app en Meta for Developers** con el producto WhatsApp Business.
4. **Obtener un número de teléfono dedicado** para Wasagro (no puede ser un número ya registrado en WhatsApp personal).
5. **Verificar el número** vía SMS o llamada.
6. **Configurar webhook** apuntando al endpoint de `whatsapp-bot-service` en GCP.
7. **Crear y enviar a aprobación las plantillas** iniciales (ver sección 4).

---

## 3. Arquitectura de integración en GCP

```text
[Meta WhatsApp Cloud API]
        │
        │  HTTPS webhook (POST)
        ▼
[Cloud Run: whatsapp-bot-service]
  - Recibe webhook de Meta
  - Verifica firma HMAC (X-Hub-Signature-256)
  - Publica mensaje en Cloud Pub/Sub
  - Responde 200 OK a Meta en < 3 segundos
        │
        ▼
[Cloud Pub/Sub: topic wa-inbound]
        │
        ▼
[Cloud Run: message-processor-service]
  - Consume mensajes de Pub/Sub
  - Llama a EXTRACT (STT/OCR)
  - Llama a CATEGORIZE + QUOTE (agente PDR/SR)
  - Guarda evento en PostgreSQL
  - Publica respuesta en topic wa-outbound
        │
        ▼
[Cloud Run: whatsapp-sender-service]
  - Consume wa-outbound
  - Llama a Meta API para enviar respuesta
  - Maneja reintentos con backoff exponencial
  - Registra conversation_id para tracking de costos
```

**Por qué Pub/Sub entre webhook y procesamiento**: Meta requiere que el webhook responda en < 3 segundos o retransmite el mensaje. El procesamiento STT + LLM puede tomar 5–15 segundos. La arquitectura desacoplada resuelve esto: el webhook solo escucha y publica, el procesamiento ocurre async.

---

## 4. Gestión de plantillas

### Plantillas mínimas para MVP

Estas plantillas deben estar aprobadas **antes** de lanzar con el primer usuario:

| Plantilla | Tipo | Uso | Variables |
|---|---|---|---|
| `wasagro_alerta_plaga` | BI Utility | Notificar al gerente cuando se detecta plaga crítica | nombre, finca, plaga, lote, severidad |
| `wasagro_informe_semanal` | BI Utility | Enviar resumen semanal al gerente | nombre, finca, periodo, resumen_url |
| `wasagro_recordatorio_registro` | BI Utility | Recordar al trabajador registrar si no ha reportado en el día | nombre, día |
| `wasagro_bienvenida` | BI Utility | Onboarding del primer mensaje a nuevo usuario | nombre, instrucciones_cortas |
| `wasagro_escalamiento` | BI Utility | Notificar escalamiento de evento sin confirmar (SLA vencido) | nombre_gerente, evento, tiempo_sin_confirmar |

### Reglas para aprobación de plantillas

- Deben estar en el idioma del mercado (español para LATAM).
- No pueden contener lenguaje promocional en plantillas de tipo Utility.
- Los parámetros variables (`{{1}}`, `{{2}}`...) deben estar en posiciones definidas.
- Evitar palabras que disparen rechazo automático: "gratis", "oferta", "descuento", "gana", "únicamente por hoy".
- Tiempo de aprobación: 1–7 días hábiles. Rechazadas se pueden re-enviar corregidas.

---

## 5. Política de 24 horas y su impacto en los flujos

### La regla

Cuando un usuario envía un mensaje, se abre una **ventana de servicio de 24 horas** durante la cual Wasagro puede responder con **cualquier tipo de mensaje** (texto libre, botones, listas) sin usar plantilla.

Cuando esa ventana expira, solo se pueden enviar mensajes usando **plantillas aprobadas**.

### Impacto en diseño de flujos

| Situación | Estado de ventana | Tipo de mensaje permitido |
|---|---|---|
| Trabajador envía audio de campo | Ventana UI activa (24h) | Respuesta libre — confirmación, pregunta de aclaración |
| Gerente consulta dashboard y responde en WA | Ventana UI activa | Respuesta libre |
| Wasagro detecta plaga y notifica (nadie escribió primero) | Sin ventana activa | Solo plantilla aprobada |
| Wasagro envía informe semanal (programado) | Sin ventana activa | Solo plantilla aprobada |
| Worker no reportó en todo el día, recordatorio automático | Sin ventana activa | Solo plantilla aprobada |

**Diseño clave**: estructurar flujos para maximizar que el trabajador inicie la conversación. Un simple mensaje de "reporta tu día" por plantilla por la mañana abre la ventana para todas las respuestas siguientes del día — reduciendo el costo de conversaciones BI durante el día laboral.

---

## 6. Límites de mensajes (Message Tiers)

Meta impone límites que crecen con el historial de envíos:

| Tier | Conversaciones BI/24h | Cómo avanzar |
|---|---|---|
| Tier 1 (nuevo) | 250 | Enviar mensajes exitosos, mantener quality rating |
| Tier 2 | 1.000 | Automático tras historial positivo (~7 días) |
| Tier 3 | 10.000 | Automático |
| Tier 4 | 100.000+ | Automático |

Para Wasagro: con 50 fincas y ~10 workers por finca, el máximo de conversaciones BI/día es ~500 (alertas + informes). El Tier 2 es suficiente para el MVP.

**Quality Rating**: si los usuarios bloquean el número o reportan spam, Meta baja el tier. Mantener mensajes relevantes y esperados por el usuario es crítico para no perder capacidad de envío.

---

## 7. Tracking de costos de WhatsApp en producción

Agregar a la tabla `raw_messages` o a una tabla separada:

```sql
CREATE TABLE wa_conversation_costs (
  id_cost          BIGSERIAL PRIMARY KEY,
  conversation_id  VARCHAR(100) NOT NULL,  -- ID de conversación de Meta
  id_farm          INT REFERENCES farms(id_farm),
  conversation_type VARCHAR(20),           -- 'user_initiated','business_utility','business_marketing'
  country_code     VARCHAR(5),
  cost_usd         NUMERIC(8,5),
  opened_at        TIMESTAMPTZ,
  recorded_at      TIMESTAMPTZ DEFAULT now()
);
```

Con esto, el dashboard de LangFuse + Meta Business Manager + esta tabla da el costo total real por finca/mes: WhatsApp + IA + STT + GCP.
