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

---

## 7.2 Modelos de IA y costos

### 7.2.1 STT (voz → texto) — el costo dominante

> ⚠️ El STT representa ~75% del costo total de IA en Wasagro. La primera optimización de costo debe ser el modelo STT, no el LLM.

| Opción | Costo estimado | Notas |
|---|---|---|
| Whisper API (OpenAI) | $0.006/minuto | Más fácil de integrar, más caro |
| Whisper self-hosted GCP (medium.en) | ~$0.001/minuto | Ahorro ~83% vs API — recomendado desde v1 |
| Voxtral (Mistral) | A evaluar | Mejor WER en español latinoamericano con acento centroamericano, según benchmarks 2025 |

**Post-corrección STT con LLM**: después de transcribir, enviar el transcript crudo al LLM con una lista de vocabulario agro esperado ("bombada", "caneca", "quintales", nombres de productos) para corrección antes de estructurar. Costo marginal, impacto muy alto en calidad del pipeline.

### 7.2.2 LLMs por tipo de interacción

| Tipo de interacción | Tokens input | Tokens output | Modelo sugerido | Costo est. | % del volumen |
|---|---|---|---|---|---|
| Audio corto campo (30–60s, evento simple) | ~600 (transcript + system prompt cacheado) | ~200 (JSON evento + 1 pregunta) | Gemini Flash | $0.0001 | 55% |
| Foto + texto (OCR + estructuración) | ~800 + imagen | ~300 | GPT-4o-mini vision | $0.0008 | 20% |
| Consulta agronómica con RAG | ~2.500 (query + top-3 chunks RAG + historial campo) | ~500 | GPT-4o-mini + RAG | $0.002 | 15% |
| Evento crítico (plaga/dosis alta) — multiagentes | ~5.000 (historial + RAG normativo + contexto) | ~800 | GPT-4o / Claude Sonnet | $0.058 | 5% |
| Informe semanal gerente (batch) | ~8.000 (KPIs semana + eventos + contexto) | ~1.500 | Claude Sonnet batch (−50%) | $0.07/informe | 5% |

---

## 7.3 Unit economics por finca/mes

**Finca mediana de referencia:** 8 trabajadores reportando, 1 supervisor, 1 gerente — 20 días laborables/mes.

### Volumen estimado de actividad

| Tipo | Cantidad |
|---|---|
| Eventos campo/día (8 trabajadores × 3 eventos) | 24 eventos/día → 480/mes |
| Consultas agronómicas/semana | 15 consultas → 60/mes |
| Eventos críticos/mes | 5 eventos |
| Informes semanales/mes | 4 informes |
| Audio promedio por evento | ~45 segundos |
| Total audio/mes | ~360 minutos |

### Desglose de costo mensual

| Componente | Cálculo | Costo/mes |
|---|---|---|
| STT (Whisper self-hosted) | 360 min × $0.001/min | **$0.36** |
| STT (Whisper API, sin optimizar) | 360 min × $0.006/min | $2.16 |
| Tokens eventos campo (modelo base) | 480 × $0.0001 | $0.048 |
| Tokens foto+texto | 96 × $0.0008 | $0.077 |
| Tokens consultas agronómicas | 60 × $0.002 | $0.12 |
| Tokens eventos críticos | 5 × $0.058 | $0.29 |
| Tokens informes semanales | 4 × $0.07 | $0.28 |
| **Total IA + STT (optimizado)** | | **~$1.18/mes** |
| **Total IA + STT (sin optimizar STT)** | | **~$3.00/mes** |
| Infra GCP (prorrateada, MVP 50 fincas) | | ~$3–5/mes |
| **Total estimado/finca/mes** | | **~$4–8/mes** |

> El análisis de arquitectura externo estimó $3.14/mes con Whisper API. Con Whisper self-hosted, ese número baja a ~$1.50/mes solo en IA/STT.

---

## 7.4 Rangos de precio viables por finca/mes

| Plan | Precio sugerido | Gross margin est. |
|---|---|---|
| Básico (captura + alertas) | $49–79/mes | ~93% |
| Pro (informes + RAG agronómico) | $99–149/mes | ~85% |
| Enterprise (multi-finca + API ERP) | $299+/mes | ~80% |

Gross margin incluyendo infra GCP: **75–80%** en régimen normal.

> Break-even por finca al precio básico ($49): se cubre el costo de infraestructura + IA incluso en uso intensivo. El margen real vendrá del volumen de fincas, no del precio por finca.

---

## 7.5 Estrategias de optimización de costo

Ordenadas por impacto esperado:

1. **Whisper self-hosted** (mayor ahorro, −83% del componente más costoso).
2. **Post-corrección STT con LLM** (mejora calidad sin añadir costo significativo).
3. **Prompt caching** del system prompt por finca (−60% en input tokens repetitivos).
4. **Workspace-as-memory** en lugar de historial completo (−70–80% en tokens multi-turn).
5. **RAG + routing de complejidad** (−80% de uso de LLM grande en consultas knowledge-intensive).
6. **LLMLingua-2** en prompts largos (−14–20× en prompts de sistema y few-shots extensos).
7. **Destilación del clasificador** (v1): Llama 3.1 8B fine-tuned → −99% en costo de clasificación.
8. **Modelos especializados por cultivo** (v2): fine-tuning reduce tokens necesarios para contextualizar.

---

## 7.6 Cómo medir costos reales en producción

Ver `docs/09-observabilidad-evals.md` para la estrategia completa.

- Instalar **LangFuse** self-hosted en GCP (open source, gratuito).
- Trazar cada llamada LLM/STT con metadatos: tipo de evento, modelo usado, tokens, costo, latencia.
- Dashboard de costo real por tipo de interacción y por finca.
- Objetivo: tener este dashboard activo desde el primer día en producción.
