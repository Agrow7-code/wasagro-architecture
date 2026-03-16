# 07 – Costos de infraestructura y modelo económico

Este documento resume las decisiones iniciales de infraestructura, el modelo cuantitativo de unit economics por finca, y las estrategias de optimización de costo.

> Números basados en patrones reales de campo agro. Deben refinarse con uso real en producción, usando LangFuse para medir costo real por tipo de interacción.

---

## 7.1 Infraestructura base (GCP)

Componentes para MVP con ~1.000 usuarios activos:

- Cloud SQL for PostgreSQL + PostGIS (1 instancia).
- GKE (1 clúster zonal, 2 nodos pequeños).
- Cloud Storage (archivos, reportes, adjuntos).
- Servicios de modelos (LLM/STT/OCR) vía APIs externas.
- WhatsApp Business API vía BSP (ver `infra/whatsapp-bsp.md`).

---

## 7.2 WhatsApp Business API — costo real del canal

> ⚠️ Este es el costo más frecuentemente omitido en modelos de unit economics de productos agritech WhatsApp-first. En LATAM puede representar $5–15/finca/mes si no se optimiza — superando el costo de toda la IA.

### 7.2.1 Modelo de precios de Meta (2024–2025)

Meta cobra por **conversación** (ventana de 24 horas), no por mensaje individual. Una conversación abierta permite todos los mensajes que se intercambien en esa ventana a un solo costo.

**Tipos de conversación:**

| Tipo | Quién inicia | Descripción | Restricción |
|---|---|---|---|
| **User-Initiated (UI)** | El usuario | El trabajador escribe primero. Wasagro puede responder libremente durante 24h. | Sin restricción de plantilla |
| **Business-Initiated (BI) — Utility** | Wasagro | Mensajes transaccionales: confirmación de evento registrado, alerta de plaga, recordatorio. | Requiere plantilla pre-aprobada por Meta |
| **Business-Initiated (BI) — Marketing** | Wasagro | Mensajes comerciales: promoción, upsell. | Requiere plantilla + puede ser bloqueado |
| **Business-Initiated (BI) — Authentication** | Wasagro | OTP / verificación de identidad. | Requiere plantilla |

### 7.2.2 Tarifas por país (referencia 2025)

Meta cobra por país **de destino** del número receptor:

| País | UI (user-initiated) | BI Utility | BI Marketing |
|---|---|---|---|
| Ecuador | ~$0.0088 | ~$0.0112 | ~$0.0147 |
| Colombia | ~$0.0110 | ~$0.0140 | ~$0.0184 |
| Honduras | ~$0.0086 | ~$0.0109 | ~$0.0143 |
| Guatemala | ~$0.0083 | ~$0.0105 | ~$0.0138 |
| Costa Rica | ~$0.0150 | ~$0.0190 | ~$0.0250 |
| Perú | ~$0.0107 | ~$0.0136 | ~$0.0178 |

> 💡 Fuente: Meta for Developers — WhatsApp Business Platform Pricing (actualizar antes de cotizar clientes: https://developers.facebook.com/docs/whatsapp/pricing).

> ⚠️ Las primeras **1.000 conversaciones UI/mes** son gratuitas por número de teléfono de negocio. Esto cubre el periodo de prueba con primeros usuarios.

### 7.2.3 Mensajes proactivos y plantillas

**Regla crítica**: cualquier mensaje que Wasagro envíe **sin que el usuario haya escrito primero en las últimas 24 horas** requiere una **plantilla aprobada por Meta**.

Esto afecta directamente a Wasagro:

- Informes semanales al gerente → **requieren plantilla**.
- Alertas de plaga proactivas → **requieren plantilla**.
- Recordatorios de registro pendiente → **requieren plantilla**.
- Confirmación de evento registrado (respuesta inmediata al audio del trabajador) → **NO requiere plantilla** (ventana UI activa).

**Tiempo de aprobación de plantillas**: 1–7 días hábiles. Las plantillas se aprueban una vez y se reutilizan. Deben estar redactadas en el idioma exacto del mercado y no pueden contener contenido variable en posiciones no definidas.

Ejemplo de plantilla aprobada para alerta de plaga:
```
Hola {{1}}, Wasagro detectó una alerta en tu finca {{2}}:
⚠️ {{3}} en {{4}} — severidad {{5}}.
Revisa el panel o responde a este mensaje para más detalles.
```

Los parámetros `{{1}}`...`{{5}}` se llenan dinámicamente en cada envío.

---

## 7.3 Modelos de IA y costos

### 7.3.1 STT (voz → texto) — el costo dominante de IA

> ⚠️ El STT representa ~75% del costo total de IA en Wasagro. La primera optimización de costo debe ser el modelo STT, no el LLM.

| Opción | Costo estimado | Notas |
|---|---|---|
| Whisper API (OpenAI) | $0.006/minuto | Más fácil de integrar, más caro |
| Whisper self-hosted GCP (medium) | ~$0.001/minuto | Ahorro ~83% vs API — recomendado desde v1 |
| Voxtral (Mistral) | A evaluar | Mejor WER en español latinoamericano con acento centroamericano, benchmarks 2025 |

**Post-corrección STT con LLM**: enviar transcript crudo al LLM con vocabulario agro esperado para corregir jerga antes de estructurar. Costo marginal, impacto muy alto.

### 7.3.2 LLMs por tipo de interacción

| Tipo de interacción | Tokens input | Tokens output | Modelo sugerido | Costo est. | % del volumen |
|---|---|---|---|---|---|
| Audio corto campo (30–60s) | ~600 | ~200 | Gemini Flash | $0.0001 | 55% |
| Foto + texto (OCR + estructuración) | ~800 + imagen | ~300 | GPT-4o-mini vision | $0.0008 | 20% |
| Consulta agronómica con RAG | ~2.500 | ~500 | GPT-4o-mini + RAG | $0.002 | 15% |
| Evento crítico (plaga/dosis alta) | ~5.000 | ~800 | GPT-4o / Claude Sonnet | $0.058 | 5% |
| Informe semanal gerente (batch) | ~8.000 | ~1.500 | Claude Sonnet batch (−50%) | $0.07/informe | 5% |

---

## 7.4 Unit economics por finca/mes (completo con WhatsApp)

**Finca mediana de referencia:** 8 trabajadores, 1 supervisor, 1 gerente — 20 días laborables/mes.

### Volumen de actividad estimado

| Tipo | Cantidad |
|---|---|
| Eventos campo/día (8 trabajadores × 3 eventos) | 24/día → 480/mes |
| Consultas agronómicas | 60/mes |
| Eventos críticos | 5/mes |
| Informes semanales (gerente) | 4/mes |
| Alertas proactivas (plagas + recordatorios) | ~20/mes |
| Conversaciones UI activas/día | ~12 (los trabajadores ya reportan activamente) |
| Audio promedio por evento | ~45s |
| Total audio/mes | ~360 minutos |

### Desglose de costo mensual por componente

| Componente | Cálculo | Costo/mes |
|---|---|---|
| **WhatsApp — conversaciones UI** | 240 conv/mes (trabajadores reportan) → 240 conv × $0.009 | **$2.16** |
| **WhatsApp — BI Utility (alertas + informes)** | 24 conv BI × $0.011 | **$0.26** |
| *Subtotal WhatsApp* | | *$2.42/mes* |
| STT (Whisper self-hosted) | 360 min × $0.001/min | $0.36 |
| STT (Whisper API, sin optimizar) | 360 min × $0.006/min | ($2.16) |
| Tokens eventos campo | 480 × $0.0001 | $0.048 |
| Tokens foto+texto | 96 × $0.0008 | $0.077 |
| Tokens consultas agronómicas | 60 × $0.002 | $0.12 |
| Tokens eventos críticos | 5 × $0.058 | $0.29 |
| Tokens informes semanales | 4 × $0.07 | $0.28 |
| *Subtotal IA + STT (optimizado)* | | *$1.18/mes* |
| Infra GCP (prorrateada, 50 fincas) | | ~$3–5/mes |
| **TOTAL COSTO/FINCA/MES** | | **~$6.60–10.60/mes** |

> ⚠️ El costo de WhatsApp ($2.42/mes) supera el costo de toda la IA + STT optimizados ($1.18/mes). Ignorar este componente en el modelo de costos es uno de los errores más comunes en startups WhatsApp-first.

> 💡 Optimización clave: maximizar que los trabajadores inicien la conversación (UI) en lugar de que Wasagro la inicie (BI). Cada reporte de campo enviado por el trabajador abre una ventana de 24h donde todos los mensajes de respuesta de Wasagro son UI — **no requieren plantilla y cuestan menos**.

---

## 7.5 Rangos de precio viables por finca/mes

| Plan | Precio sugerido | Costo total est. | Gross margin |
|---|---|---|---|
| Básico (captura + alertas) | $49–79/mes | ~$7–11/mes | ~85–90% |
| Pro (informes + RAG agronómico) | $99–149/mes | ~$9–13/mes | ~85–90% |
| Enterprise (multi-finca + API ERP) | $299+/mes | ~$15–25/mes | ~90%+ |

Gross margin real incluyendo WhatsApp API + IA + GCP: **85–90%**.

> Break-even al precio básico ($49): cubierto incluso en uso intensivo con WhatsApp incluido.

---

## 7.6 Estrategias de optimización de costo (actualizado)

Ordenadas por impacto esperado:

1. **Maximizar UI vs BI en WhatsApp** — nuevo #1: diseñar flujos para que el trabajador siempre inicie la conversación. Ahorro: ~30–40% en costo WhatsApp.
2. **Whisper self-hosted** (−83% del componente STT).
3. **Post-corrección STT con LLM** (calidad sin costo significativo).
4. **Prompt caching** del system prompt por finca (−60% input tokens repetitivos).
5. **Workspace-as-memory** (−70–80% tokens multi-turn).
6. **RAG + routing de complejidad** (−80% uso de LLM grande).
7. **LLMLingua-2** en prompts largos.
8. **Destilación del clasificador** (v1): −99% costo de clasificación.

---

## 7.7 Cómo medir costos reales en producción

Ver `docs/09-observabilidad-evals.md` para la estrategia completa de observabilidad.

- **LangFuse**: trazar LLM + STT con costo por tipo de evento.
- **Meta Business Manager**: monitorear conversaciones UI vs BI, costo real por país.
- Dashboard unificado: costo WhatsApp + IA + STT por finca/mes, visible desde el primer día en producción.
