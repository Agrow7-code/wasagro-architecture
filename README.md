# Wasagro – Asistente de Campo AI-First para Agricultura de Exportación

Wasagro es un sistema **AI-first** para capturar, estructurar y usar datos operativos de fincas de exportación en Latinoamérica (banano, cacao, café, palma, etc.), usando como interfaz natural **WhatsApp y voz/foto/texto**.

La hipótesis central:
> El campo ya genera los datos correctos. El problema no es la tecnología, es la **fricción de captura** y la **maquillación de la realidad** en la cadena de reporte.

Wasagro ataca dos fricciones:
- **Captura**: convertir audios, fotos y mensajes sueltos en datos estructurados sin formularios pesados.
- **Gobernanza y entrega (DELIVER)**: asegurar que lo que ve la gerencia es un reflejo honesto de lo que ocurre en lote, no un "Excel maquillado".

---

## Tabla de contenidos

- [1. Problema y contexto](#1-problema-y-contexto)
- [2. Statement AI-First](#2-statement-ai-first)
- [3. Arquitectura de alto nivel](#3-arquitectura-de-alto-nivel)
- [4. Agente PDR/SR — Reflexion Agent](#4-agente-pdrsr--reflexion-agent)
- [5. Modelo de datos (Postgres + PostGIS)](#5-modelo-de-datos-postgres--postgis)
- [6. Flujos de WhatsApp](#6-flujos-de-whatsapp)
- [7. Loop humano activo y SLAs](#7-loop-humano-activo-y-slas)
- [8. RAG agro-exportación](#8-rag-agro-exportación)
- [9. Observabilidad y evals](#9-observabilidad-y-evals)
- [10. Infraestructura WhatsApp Business API](#10-infraestructura-whatsapp-business-api)
- [11. Costos y modelo económico](#11-costos-y-modelo-económico)
- [12. Gobernanza de datos e IA](#12-gobernanza-de-datos-e-ia)
- [13. Roadmap](#13-roadmap)

---

## 1. Problema y contexto

En fincas agrícolas de exportación en LATAM, una parte significativa de la operación diaria **no llega** a un sistema digital: se queda en libretas, audios de WhatsApp, Excel impresos o simplemente en memoria.

El flujo típico de "realidad endulzada":

1. **Campo**: el trabajador observa una plaga o problema crítico y lo reporta.
2. **Supervisor**: transmite una versión parcial ("hay un desafío, pero lo estamos manejando").
3. **Sub-Gerente**: convierte el reporte en gráficos y lo re-etiqueta como "oportunidad de mejora".
4. **Gerente**: asegura al CEO que todo está bajo control.
5. **CEO/Junta**: reporta que se logrará un año récord.

El choque con la realidad ocurre en el **puerto de destino**: los kilos no aparecen, la calidad no cumple, la confianza se erosiona.

**Principio de diseño**: el único dato que representa la realidad es el que se captura en campo tal como es. Wasagro debe reducir la fricción para decir la verdad y hacerla visible de forma responsable a todos los niveles.

Más detalle en [`docs/01-problema-y-contexto.md`](docs/01-problema-y-contexto.md).

---

## 2. Statement AI-First

En lugar de construir formularios y GUIs que fuerzan al humano a pensar como la máquina, Wasagro adopta una arquitectura **AI-first** donde la IA actúa como **Agente Estructurador Inteligente**:

- **La IA es la interfaz de ingestión**, no un dashboard posterior.
- Toma audios, fotos y texto natural (con jerga local como "bombadas", "canecas", "qq") y los convierte en **eventos de base de datos** (JSON estructurado).
- Si falta información crítica (lote, dosis, fecha), la IA **pregunta de vuelta** por WhatsApp — no bloquea la operación.

Capacidades clave del agente:

| Capacidad | Descripción |
|---|---|
| Entendimiento multimodal | Voz con jerga local, fotos de libretas/plagas, texto libre |
| Estructuración autónoma | Inputs narrativos → JSON sin formularios |
| Loop humano activo | Pregunta de vuelta solo cuando hay ambigüedad crítica |
| Conciencia agro-contextual | Entiende "bombada", sabe que si llovió después de fumigar hay que preguntar re-aplicación |

Detalle arquitectónico en [`docs/02-arquitectura-ai-first.md`](docs/02-arquitectura-ai-first.md).

---

## 3. Arquitectura de alto nivel

El pipeline tiene 7 capas lógicas:

```text
EXTRACT → CATEGORIZE → QUOTE → ANALYZE → ASSIST → DELIVER → OBSERVE
```

| Capa | Función |
|---|---|
| **EXTRACT** | STT (audio→texto) + post-corrección LLM para jerga agro + OCR (fotos de libretas) |
| **CATEGORIZE** | Router de complejidad: clasifica tipo de evento y decide ruta (base / RAG / premium+multiagentes) |
| **QUOTE** | Agente PDR/SR (Reflexion Agent): genera borrador → auto-crítica → JSON final o pregunta mínima |
| **ANALYZE** | KPIs clásicos + consultas LLM + RAG sobre corpus agro-exportación |
| **ASSIST** | Respuestas en WhatsApp + multiagentes de verificación para eventos críticos |
| **DELIVER** | WhatsApp, panel web, reportes PDF/Excel, APIs hacia ERP |
| **OBSERVE** | LangFuse self-hosted: trazas LLM/STT, dataset de evals, field-level accuracy |

Distribución de volumen por ruta del router:
- **55%** → Modelo base + PDR/SR (audios simples de campo)
- **20%** → Modelo base + OCR vision (fotos + texto)
- **15%** → Modelo base + RAG (consultas agronómicas)
- **5%** → Modelo premium + RAG + multiagentes (eventos críticos)
- **5%** → Batch (informes semanales gerente)

Más detalle en [`docs/02-arquitectura-ai-first.md`](docs/02-arquitectura-ai-first.md).

---

## 4. Agente PDR/SR — Reflexion Agent

El agente estructurador es académicamente un **Reflexion Agent** (Shinn et al., 2023 — arXiv:2303.11366) combinado con el patrón **ReAct** (Yao et al., 2023 — arXiv:2210.03629).

### Flujo en 3 pasos

```text
Mensaje campo (audio/foto/texto)
        ↓
Paso 1 — Borrador (ReAct): genera JSON parcial con lo que entiende
        ↓
Paso 2 — Auto-crítica (Reflexion): evalúa campos faltantes o ambiguos
        ↓
Paso 3 — Refinamiento: produce JSON final O genera pregunta mínima
```

### Workspace-as-memory

Para conversaciones multi-turn (el trabajador da información fragmentada en varios mensajes), **no** se envía el historial completo al LLM. Se envía solo:

```json
{
  "event_type": "input_application",
  "fields_extracted": {
    "id_field": null,
    "input_name": "Round-Up",
    "dose": 0.5,
    "dose_unit": "bombada",
    "area_ha": null
  },
  "mandatory_missing": ["id_field", "area_ha"],
  "pending_question": "¿En qué lote aplicaste el Round-Up?",
  "reflexion_note": "dose_unit 'bombada' requiere normalización a L/ha — preguntar área antes"
}
```

**Resultado**: reducción de tokens multi-turn del **70–80%** vs enviar historial completo. En campo, donde el trabajador da información en 3–5 mensajes fragmentados, esto es la norma.

Protocolo de validación antes de escribir código de producción (costo < $5 en API):
1. Tomar 10–20 audios reales de campo.
2. Testear 3 variantes: single-shot, ReAct 2 pasos, Reflexion 3 pasos.
3. Medir field-level accuracy campo por campo (lote, dosis, unidad, fecha).
4. Elegir la variante con mejor accuracy/costo como prompt base del MVP.

Detalle completo en [`docs/02-arquitectura-ai-first.md`](docs/02-arquitectura-ai-first.md).

---

## 5. Modelo de datos (Postgres + PostGIS)

Wasagro usa **Cloud SQL for PostgreSQL + PostGIS** como base operacional. Esquema completo en [`backend/sql/01-schema-core.sql`](backend/sql/01-schema-core.sql).

### Entidades principales

| Tabla | Descripción |
|---|---|
| `farms` / `fields` | Fincas y lotes con geometría PostGIS |
| `users` | Usuarios con número WhatsApp, rol, finca |
| `raw_messages` | Mensajes crudos entrantes (audio_uri, image_uri, text_raw) |
| `message_processed` | STT transcript + `text_stt_corrected` (post-corrección jerga agro) |
| `events` | Eventos operativos normalizados con `risk_level`, `completeness_status`, `escalated_at` |
| `event_payloads` | Payload JSONB flexible por tipo de evento |
| `workspaces` | `workspace_json` (JSON parcial acumulado) + `reflexion_note` + `turn_number` |
| `router_decisions` | Decisiones del router: modelo usado, need_rag, need_premium |
| `escalation_rules` | SLAs por tipo de evento: `max_hours`, `escalate_to_role`, `action_on_breach` |
| `eval_dataset` / `eval_results` | Pares {mensaje → JSON esperado} y resultados por versión de prompt/modelo |
| `wa_conversation_costs` | Costo real por conversación WhatsApp (UI vs BI, por país) |

---

## 6. Flujos de WhatsApp

### 6.1 Onboarding de gerente

Flujo de mini-encuesta para entender preferencias: foco (kilos/calidad/costos/sanidad), horizonte de tiempo, nivel de detalle, frecuencia de informes. Implementado como máquina de estados en `wa_conversations`.

### 6.2 Captura de eventos de campo

El trabajador envía audio/foto/texto. El agente PDR/SR estructura el evento, confirma al trabajador en segundos, y si falta información crítica hace una sola pregunta mínima.

### 6.3 Informes semanales + drill-down

El gerente recibe un resumen adaptado a sus preferencias con cinta de integridad de datos. Puede hacer drill-down por lote, plaga, costo — todo desde WhatsApp.

Flujos completos en [`flows/whatsapp-onboarding-gerente.md`](flows/whatsapp-onboarding-gerente.md) y [`flows/whatsapp-eventos-campo.md`](flows/whatsapp-eventos-campo.md).

---

## 7. Loop humano activo y SLAs

El loop humano mal diseñado destruye la experiencia. La matriz de SLA define el tiempo máximo sin confirmación humana antes de que el sistema actúe automáticamente:

| Tipo de evento | SLA máximo | Acción automática al vencer |
|---|---|---|
| Plaga — severidad alta | **2 horas** | Alerta push a gerente |
| Dosis alta / producto restringido | **1 hora** | Bloqueo + alerta gerente |
| Clarificación pendiente (campo incompleto) | **30 minutos** | Re-envío automático de pregunta |
| Aplicación normal | 48 horas | Auto-aprobado |
| Avance de labor / gasto | 72 horas | Auto-aprobado |

Implementado en la tabla `escalation_rules` y campo `escalated_at` en `events`. Un cron job cada 15 minutos detecta eventos que vencieron su SLA.

> Lo que distingue a Wasagro de un bot de captura básico: el gerente sabe que si algo crítico no se atendió en 2 horas, el sistema le avisa. Eso genera confianza operativa real.

Detalle completo en [`docs/11-loop-humano-slas.md`](docs/11-loop-humano-slas.md).

---

## 8. RAG agro-exportación

El corpus RAG es el **moat real de Wasagro**. Ningún bot genérico puede replicar un corpus agro-exportación con MRLs de la UE vectorizados y accesibles desde WhatsApp en tiempo real.

**Query killer feature:**
> *"¿Puedo aplicar mancozeb al cacao si cosecho en 8 días para Europa?"*

### Corpus mínimo viable

| Fuente | Contenido | Prioridad |
|---|---|---|
| Pesticide MRL Database (UE) | Límites máximos de residuos — tiene endpoints JSON directos, no requiere scraping | 🔴 Crítica |
| USDA Tolerance Database | MRLs para mercado estadounidense | 🔴 Crítica |
| GlobalGAP / EUREPGAP | BPAs por cultivo | 🟠 Alta |
| Fichas técnicas de 50 insumos | Dosis, periodos de carencia, cultivos registrados | 🟠 Alta |
| SOPs internos por finca | Se cargan al onboardear cada cliente | 🟡 Media |

**Stack**: pgvector (ya en Postgres) + `text-embedding-3-small` + chunking 400–600 tokens.

**Meta de calidad**: RAGAS faithfulness ≥ 90% en consultas de MRLs antes de lanzar.

Detalle completo en [`docs/10-corpus-rag-agro.md`](docs/10-corpus-rag-agro.md).

---

## 9. Observabilidad y evals

> Sin observabilidad, todas las optimizaciones de tokens son estimaciones. No sabes si el agente estructuró un audio al 95% o al 60%.

### Stack: LangFuse self-hosted en GCP

- Cloud Run (2 contenedores) + tu Cloud SQL existente. Costo adicional: ~$5–10/mes.
- Traza cada llamada LLM/STT: modelo, tokens, latencia, costo estimado.
- Ref deploy: https://langfuse.com/docs/deployment/self-host

### Dataset de evals

50–100 pares `{mensaje crudo → JSON esperado}` construidos con datos reales de campo, guardados en la tabla `eval_dataset`.

### Métrica principal: field-level accuracy

¿Se extrajo correctamente el lote? ¿La dosis? ¿La unidad? ¿El tipo de evento?

**Meta MVP**: ≥ 85% de field-level accuracy antes de lanzar con usuarios reales.

Los resultados se guardan en `eval_results` para comparar versiones de prompt/modelo.

Detalle completo en [`docs/09-observabilidad-evals.md`](docs/09-observabilidad-evals.md).

---

## 10. Infraestructura WhatsApp Business API

### Decisión de BSP

| Fase | Opción | Costo adicional | Razón |
|---|---|---|---|
| **MVP (0–50 fincas)** | 360Dialog o WatiApp (BSP LATAM) | ~$49–79/mes fijo | Lanza en días, no semanas |
| **v1 (50+ fincas)** | Meta Cloud API directo | Solo costo por conversación | Elimina markup del BSP |

### Arquitectura en GCP

El webhook de Meta debe responder en < 3 segundos. El procesamiento STT + LLM toma 5–15 segundos. Solución: desacoplamiento via Cloud Pub/Sub:

```text
Meta Webhook → Cloud Run (responde 200 en <3s) → Pub/Sub → Message Processor → Respuesta
```

### Plantillas pre-aprobadas (necesarias antes del primer usuario)

5 plantillas mínimas de tipo BI Utility: alerta de plaga, informe semanal, recordatorio de registro, bienvenida, escalamiento de SLA. Tiempo de aprobación: 1–7 días hábiles.

### Política de 24 horas

- El trabajador envía audio → ventana UI activa 24h → Wasagro puede responder libremente (más barato, sin plantilla).
- Wasagro inicia (alerta, informe) → requiere plantilla aprobada.

**Optimización**: un mensaje de "reporta tu día" por la mañana (plantilla) abre la ventana UI para todas las respuestas del día laboral.

Detalle completo en [`infra/whatsapp-bsp.md`](infra/whatsapp-bsp.md).

---

## 11. Costos y modelo económico

### Unit economics por finca/mes (finca mediana: 8 trabajadores, 20 días laborables)

| Componente | Costo/mes |
|---|---|
| WhatsApp — conversaciones UI | ~$2.16 |
| WhatsApp — BI Utility (alertas + informes) | ~$0.26 |
| STT (Whisper self-hosted) | ~$0.36 |
| Tokens LLM (todos los tipos) | ~$0.82 |
| Infra GCP (prorrateada) | ~$3–5 |
| **Total estimado** | **~$6.60–10.60/mes** |

> ⚠️ El costo de WhatsApp ($2.42/mes) supera el costo de toda la IA + STT ($1.18/mes). Es el componente más frecuentemente omitido en modelos de costos de startups WhatsApp-first.

### Rangos de precio

| Plan | Precio | Gross margin est. |
|---|---|---|
| Básico (captura + alertas) | $49–79/mes | ~85–90% |
| Pro (informes + RAG agronómico) | $99–149/mes | ~85–90% |
| Enterprise (multi-finca + API ERP) | $299+/mes | ~90%+ |

### Estrategias de optimización (ordenadas por impacto)

1. **Maximizar UI vs BI en WhatsApp** — diseñar flujos para que el trabajador inicie la conversación.
2. **Whisper self-hosted** — ahorro del 83% en STT (el componente de IA más costoso).
3. **Post-corrección STT con LLM** — calidad sin costo significativo.
4. **Prompt caching** del system prompt por finca (−60% input tokens repetitivos).
5. **Workspace-as-memory** (−70–80% tokens multi-turn).
6. **RAG + routing de complejidad** (−80% uso de modelo grande).
7. **Destilación del clasificador** (v1): −99% en costo de clasificación.

Detalle completo en [`docs/07-costos-y-modelo-economico.md`](docs/07-costos-y-modelo-economico.md).

---

## 12. Gobernanza de datos e IA

Principios:

- **Una sola fuente de verdad**: todos los paneles se construyen desde `events` y vistas derivadas.
- **Dato vs interpretación**: cada vista distingue entre mediciones crudas, agregaciones (KPIs) y narrativas generadas por IA.
- **Calidad de datos visible**: cobertura de lotes reportando, retraso medio, alertas críticas abiertas — siempre visible, no ocultable.
- **Auditoría**: cualquier cambio manual en eventos o KPIs se registra.
- **Loop humano activo**: eventos críticos tienen revisión explícita con SLA definido (ver sección 7).

Más en [`docs/05-governanza-datos-e-ia.md`](docs/05-governanza-datos-e-ia.md).

---

## 13. Roadmap

### MVP — antes del primer usuario real

- [ ] Experimento agente PDR/SR: 3 variantes de prompt con 10–20 audios reales (< $5 en API)
- [ ] Plantillas WhatsApp aprobadas por Meta (5 plantillas mínimas)
- [ ] LangFuse self-hosted en GCP activo
- [ ] Dataset de 50–100 pares de evals construido con datos reales
- [ ] Field-level accuracy ≥ 85% en dataset de evals
- [ ] Captura por WhatsApp (audio + texto + foto)
- [ ] Estructuración básica de eventos (plaga, labor, insumo, gasto)
- [ ] Confirmación al trabajador en < 15 segundos
- [ ] Panel web simple: mapa, alertas, 3–4 KPIs
- [ ] Primer flujo de informe semanal

### v1 — primeras 50 fincas

- [ ] Corpus RAG: MRLs UE + USDA + 50 fichas técnicas de insumos vectorizadas en pgvector
- [ ] Query killer feature activa: "¿Puedo aplicar X a Y días de cosecha para Europa?"
- [ ] Migración a Meta Cloud API directo (eliminar BSP)
- [ ] Integración de clima (`weather_hourly` + vista `event_with_weather`)
- [ ] Destilación del clasificador de tipo de evento (Llama 3.1 8B fine-tuned sobre 500+ pares)
- [ ] RAGAS faithfulness ≥ 90% en consultas RAG de MRLs

### v2 — escala

- [ ] Tri-RAG: embeddings densos + BM25 + grafo de conocimiento por cultivo/insumo
- [ ] Modelos especializados por cultivo
- [ ] Multiagentes de verificación avanzada
- [ ] Integraciones profundas con ERP/contabilidad
- [ ] Fine-tuning de modelo STT para jerga agro latinoamericana

---

## Estructura del repositorio

```
wasagro-architecture/
├── README.md                          ← Este archivo
├── docs/
│   ├── 01-problema-y-contexto.md
│   ├── 02-arquitectura-ai-first.md    ← Reflexion Agent, workspace-as-memory, pipeline completo
│   ├── 03-modelo-de-datos.md
│   ├── 04-flujos-whatsapp.md
│   ├── 05-governanza-datos-e-ia.md
│   ├── 06-entrega-y-productos-deliver.md
│   ├── 07-costos-y-modelo-economico.md ← Unit economics con WhatsApp incluido
│   ├── 08-roadmap-mvp-v1-v2.md
│   ├── 09-observabilidad-evals.md     ← LangFuse, dataset de evals, field-level accuracy
│   ├── 10-corpus-rag-agro.md          ← MRLs UE, fichas técnicas, pgvector, RAGAS
│   └── 11-loop-humano-slas.md         ← Matriz de SLAs, escalamiento, tablas SQL
├── backend/
│   ├── sql/
│   │   ├── 01-schema-core.sql         ← Todas las tablas incl. escalation_rules, eval_dataset
│   │   └── 02-schema-weather.sql
│   └── README.md
├── flows/
│   ├── whatsapp-onboarding-gerente.md
│   └── whatsapp-eventos-campo.md
└── infra/
    └── whatsapp-bsp.md                ← BSP vs Meta directo, Pub/Sub architecture, plantillas
```
