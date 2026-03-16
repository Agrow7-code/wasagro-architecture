# 10 – Corpus RAG agro-exportación

Este documento define la estrategia para construir el corpus de conocimiento para la capa RAG de Wasagro.

> **El corpus RAG es el moat real de Wasagro.** Ningún WhatsApp bot genérico puede replicar un corpus agro-exportación con MRLs de la UE, fichas técnicas de insumos regionales y BPAs por cultivo, vectorizado y accesible en tiempo real desde WhatsApp.

---

## 10.1 Por qué este corpus es diferenciador

Las exportadoras de banano, cacao, café y palma en LATAM enfrentan restricciones de residuos de agroquímicos en sus mercados de destino (UE, EEUU, Japón). Un rechazo en puerto por residuos fuera de norma puede costar decenas de miles de dólares. La pregunta crítica que ningún sistema actual responde en campo es:

> *"¿Puedo aplicar X producto a Y días de la cosecha para exportar a Europa?"*

Wasagro puede responder esto desde WhatsApp, con trazabilidad, en segundos.

---

## 10.2 Fuentes del corpus

### Fuentes públicas prioritarias

| Fuente | Contenido | Prioridad | URL / Acceso |
|---|---|---|---|
| Pesticide MRL Database (UE) | Límites máximos de residuos por cultivo/producto para la UE | 🔴 Crítica | https://ec.europa.eu/food/plant/pesticides/eu-pesticides-database |
| USDA Tolerance Database | MRLs para mercado estadounidense | 🔴 Crítica | https://www.ecfr.gov/current/title-40/chapter-I/subchapter-E/part-180 |
| Codex Alimentarius (FAO/OMS) | MRLs internacionales de referencia | 🟠 Alta | https://www.fao.org/fao-who-codexalimentarius |
| GlobalGAP / EUREPGAP BPAs | Protocolos de Buenas Prácticas Agrícolas por cultivo | 🟠 Alta | https://www.globalgap.org |
| SENASA / AGROCALIDAD / ICA | Registros fitosanitarios nacionales (Ecuador, Colombia, Honduras, CR) | 🟡 Media | Por país |

### Fuentes internas a construir

| Fuente | Contenido | Cuándo |
|---|---|---|
| Fichas técnicas de insumos | 50 productos de uso común (dosis, periodos de carencia, cultivos registrados) | MVP / v1 |
| SOPs internos de finca | Procedimientos estándar de operación por cultivo | Al onboardear cada cliente |
| Historial de eventos de campo | Eventos pasados de la finca (plagas, aplicaciones, condiciones) | Crece con el uso |
| Alertas fitosanitarias nacionales | Boletines SENASA/AGROCALIDAD de nuevas plagas | v1 |

---

## 10.3 Arquitectura técnica del RAG

### Stack

- **Vector store**: `pgvector` — ya disponible en Postgres, sin infraestructura adicional para el MVP.
- **Modelo de embeddings**: `text-embedding-3-small` (OpenAI) — relación costo/calidad óptima para texto técnico en español.
- **Chunking**: chunks de 400–600 tokens con solapamiento de 50 tokens. Para tablas de MRLs, una fila por chunk.
- **Retrieval**: top-3 chunks por consulta, con filtro por cultivo y mercado de destino cuando estén disponibles.

### Flujo RAG en Wasagro

```text
Consulta usuario: "¿Puedo echarle mancozeb al cacao si cosecho en 8 días para Europa?"

1. CATEGORIZE: router marca need_rag = true, tipo = consulta_agronómica
2. RAG RETRIEVE:
   - query: "mancozeb cacao MRL periodo de carencia Unión Europea"
   - filtros: crop = "cacao", market = "EU"
   - top-3 chunks devueltos: MRL mancozeb cacao UE + ficha técnica mancozeb + BPA cacao
3. QUOTE (con contexto RAG):
   - El LLM recibe los 3 chunks + la pregunta del usuario
   - Responde con el MRL, el periodo de carencia real, y si es seguro aplicar
4. ASSIST:
   - Respuesta en WhatsApp: "El MRL de mancozeb en cacao para la UE es X mg/kg.
     El periodo de carencia es Y días. Con 8 días antes de cosecha, [respuesta].
     Fuente: Reglamento UE [número]."
```

---

## 10.4 Hoja de ruta para construir el corpus

| Semana | Acción | Output |
|---|---|---|
| **Semana 3–4** | Descargar y parsear MRLs UE para banano, cacao, café (tablas PDF/web → CSV). Instalar pgvector. Generar embeddings. | Vector store funcional con MRLs UE |
| **Mes 2** | Agregar MRLs USDA + Codex. Cargar 50 fichas técnicas de insumos frecuentes. | Cobertura ~80% de consultas de carencia comunes |
| **v1** | Integrar SOPs por finca al onboardear cada cliente. Conectar alertas fitosanitarias nacionales. | RAG contextual por finca + cultura de cultivo |
| **v2** | Tri-RAG: combinar embeddings densos + BM25 + grafo de conocimiento por cultivo/insumo. | Precisión máxima en consultas técnicas complejas |

---

## 10.5 Métricas de calidad del RAG

Usar **RAGAS** (framework de evaluación RAG, 2023) para medir:

- **Faithfulness**: ¿la respuesta está soportada por los chunks recuperados?
- **Answer relevancy**: ¿la respuesta responde la pregunta del usuario?
- **Context recall**: ¿el retrieval recuperó los chunks correctos?

Meta v1: faithfulness ≥ 90% en el conjunto de preguntas de evaluación de MRLs.
