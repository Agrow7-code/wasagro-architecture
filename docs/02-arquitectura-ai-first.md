# Arquitectura AI-First de Wasagro

Este documento describe la arquitectura AI-first de Wasagro: cómo se capturan datos desde WhatsApp, cómo la IA los estructura, cómo se decide qué modelo usar y cómo esos datos terminan alimentando decisiones confiables.

---

## 1. Principios de diseño

1. **La IA es la interfaz de ingestión**  
   La IA no es solo un dashboard posterior. Es el primer actor que recibe audios, fotos y texto, y los transforma en eventos de base de datos.

2. **Agente PDR/SR = Reflexion Agent**  
   El operador PDR/SR es académicamente un **Reflexion agent** (Shinn et al., 2023) combinado con el patrón **ReAct** (Yao et al., 2023):
   - **ReAct**: el agente alterna razonamiento y acción en el mismo contexto de tokens.
   - **Reflexion**: añade un paso de auto-crítica antes de finalizar.
   - En Wasagro: genera borrador → critica → refina → produce JSON final o pregunta.

3. **Workspace como memoria de conversación**  
   Para conversaciones multi-turn, no se envía todo el historial al LLM. Se envía solo el JSON parcial actual + el último mensaje del usuario. Reducción de tokens multi-turn: **70–80%**.

4. **Loop humano activo**  
   Cuando faltan campos críticos o la confianza es baja, la IA pregunta de vuelta por WhatsApp. Los SLAs de respuesta humana deben estar definidos para eventos críticos.

5. **RAG y destilación como capas ortogonales**  
   RAG trae conocimiento externo (MRLs UE, fichas técnicas, BPAs). La destilación internaliza skills frecuentes en modelos pequeños.

6. **Deliver anti-maquillaje**  
   La capa de entrega muestra siempre la calidad del dato y evita que la realidad se endulce al subir en la organización.

---

## 2. Diagrama lógico de la arquitectura

```text
[Canales de campo]
  - WhatsApp / Telegram
  - (Opcional) App ligera / IoT

        │
        ▼
1) EXTRACT  (Ingesta multimodal)
  - STT: audio → texto (Whisper self-hosted / Voxtral)
      · Post-corrección STT con LLM: corregir jerga agro antes de estructurar
  - OCR: texto desde fotos (libretas, etiquetas)
  - Texto nativo
  - Metadata: usuario, rol, finca, timestamp

        │
        ▼
2) CATEGORIZE  (Router de complejidad / presupuesto)
  - Clasifica tipo de evento (plaga, insumo, labor, gasto, consulta)
  - Decide ruta:
      · Modelo Base + PDR/SR            → 55% del volumen
      · Modelo Base + RAG               → 15% del volumen
      · Modelo Premium + RAG + agentes  →  5% del volumen
  - Capa de eficiencia: prompt caching, LLMLingua-2

        │
        ▼
3) QUOTE  (Agente estructurador PDR/SR — Reflexion Agent)
  - Paso 1: genera borrador JSON (ReAct)
  - Paso 2: auto-crítica de campos faltantes (Reflexion)
  - Paso 3: refina JSON o genera pregunta mínima
  - Workspace: solo JSON parcial + reflexion_note (no historial completo)

        │
        ▼
4) ANALYZE  (Motor de análisis)
  - KPIs clásicos + consultas LLM
  - RAG sobre corpus agro (MRLs UE, fichas, BPAs)

        │
        ▼
5) ASSIST  (Asistencia en tiempo real)
  - Respuestas/recomendaciones por WhatsApp
  - Multiagentes: verificador dosis/normas, auditor de eventos críticos

        │
        ▼
6) DELIVER  (Entrega)
  - WhatsApp, panel web, reportes PDF/Excel, APIs ERP

        │
        ▼
7) OBSERVE  (Observabilidad — obligatoria desde día 1)
  - LangFuse self-hosted: traza cada llamada LLM/STT
  - Dataset de evals: pares {mensaje → JSON esperado}
  - Métrica: field-level accuracy por tipo de evento
```

Ver `docs/09-observabilidad-evals.md` para la estrategia completa de observabilidad.

---

## 3. Definición técnica del agente PDR/SR (Reflexion Agent)

Referencias académicas:

- **ReAct** (Yao et al., 2023 — arXiv:2210.03629): alterna razonamiento y acción en el mismo contexto.
- **Reflexion** (Shinn et al., 2023 — arXiv:2303.11366): auto-evaluación verbal antes de finalizar.

### Representación del workspace

```json
{
  "event_type": "input_application",
  "confidence": 0.85,
  "fields_extracted": {
    "id_field": null,
    "input_name": "Round-Up",
    "dose": 0.5,
    "dose_unit": "bombada",
    "area_ha": null,
    "event_time": "hoy mañana"
  },
  "mandatory_missing": ["id_field", "area_ha"],
  "pending_question": "¿En qué lote aplicaste el Round-Up?",
  "reflexion_note": "dose_unit 'bombada' requiere normalización a L/ha — preguntar área antes de normalizar"
}
```

Solo este JSON se reenvía al LLM en el siguiente turno (no el historial completo).

### Experimento de validación (< $5 en API)

Antes de escribir código de producción:
1. Tomar 10–20 audios reales de campo, transcribirlos.
2. Testear 3 variantes: single-shot, ReAct 2 pasos, Reflexion 3 pasos.
3. Medir field-level accuracy campo por campo.
4. Elegir la variante con mejor accuracy/costo como prompt base del MVP.

---

## 4. Router de complejidad / presupuesto

Rutas de decisión:

- `ACCEPT_BASE`: modelo base + PDR/SR.
- `ESCALATE_RAG`: modelo base + RAG.
- `ESCALATE_PREMIUM`: modelo premium + RAG + multiagentes.
- `ASK_CLARIFICATION`: pedir datos faltantes antes de crear evento.

En MVP: reglas estáticas. En v1: clasificador destilado (Llama 3.1 8B fine-tuned) → costo −99%.

---

## 5. RAG y destilación de skills

Ver `docs/10-corpus-rag-agro.md` para el corpus completo.

**Query killer feature**: *"¿Puedo aplicar X a Y días de cosecha para mercado europeo?"*

**Stack**: pgvector (ya en Postgres) + `text-embedding-3-small`.

---

## 6. Capa DELIVER anti-maquillaje

Todos los canales muestran métricas de integridad de datos y separan dato crudo / agregación / narrativa IA.

---

## 7. Observabilidad

Ver `docs/09-observabilidad-evals.md` para la estrategia completa.

**Meta MVP**: field-level accuracy ≥ 85% antes de lanzar a usuarios reales.
