# 09 – Observabilidad y evaluación de calidad IA

Este documento define la estrategia de observabilidad y evaluación de calidad para el pipeline de IA de Wasagro.

> **Por qué es crítico desde el día 1**: sin observabilidad, todas las optimizaciones de tokens son estimaciones. No sabrás si el agente PDR/SR estructuró un audio correctamente al 95% o al 60%.

---

## 9.1 Stack de observabilidad: LangFuse self-hosted

### Qué es LangFuse

[LangFuse](https://langfuse.com) es una herramienta open source para trazar, evaluar y depurar pipelines LLM. Es el stack más usado en producción en 2025 para exactamente este tipo de pipeline.

### Deploy en GCP (MVP)

Ref: https://langfuse.com/docs/deployment/self-host

- **Stack**: Cloud Run (2 contenedores: langfuse-web + langfuse-worker) + Cloud SQL Postgres (el mismo que ya tienes).
- **Costo adicional**: ~$5–10/mes en Cloud Run para el volumen de un MVP.
- **Ventaja**: los datos de campo no salen del entorno GCP. Cero costo de licencia.

### Pasos de instalación resumidos

1. Clonar el repo de LangFuse y configurar variables de entorno (`DATABASE_URL` apuntando a tu Cloud SQL).
2. Desplegar los dos contenedores en Cloud Run con imagen oficial.
3. Configurar autenticación (Google OAuth o usuario/clave).
4. Obtener `LANGFUSE_PUBLIC_KEY` y `LANGFUSE_SECRET_KEY` para el SDK.

### Integración con el pipeline de Wasagro

```python
from langfuse import Langfuse
langfuse = Langfuse()  # usa variables de entorno LANGFUSE_*

# Trazar un ciclo completo de PDR/SR
with langfuse.trace(
    name="pdr_sr_agent",
    metadata={"event_type": "pest", "farm_id": farm_id, "turn": turn_number}
) as trace:
    # Paso STT
    transcript = stt_service.transcribe(audio_uri)
    trace.span(name="stt", input={"audio_uri": audio_uri}, output={"transcript": transcript})

    # Post-corrección STT con LLM
    corrected = llm.correct_agro_vocab(transcript, vocab_list)
    trace.span(name="stt_correction", input=transcript, output=corrected)

    # Paso 1: borrador (ReAct)
    draft = llm.draft(corrected, workspace_json)
    trace.span(name="draft", input=corrected, output=draft)

    # Paso 2: auto-crítica (Reflexion)
    critique = llm.critique(draft)
    trace.span(name="critique", input=draft, output=critique)

    # Paso 3: JSON final o pregunta
    result = llm.refine(draft, critique)
    trace.span(name="refine", input=critique, output=result)

    # Score de completitud
    trace.score(name="field_accuracy", value=compute_field_accuracy(result, expected))
```

---

## 9.2 Dataset de evaluación (evals)

### Por qué es obligatorio antes de lanzar

Sin un dataset de evals no puedes saber:
- si cambiar el modelo base mejora o empeora la calidad real,
- qué tipos de audio o mensaje tienen peor extracción,
- qué campos se pierden más frecuentemente (lote, dosis, unidad).

### Construcción del dataset

**Tamaño mínimo viable**: 50–100 pares `{mensaje crudo → JSON esperado}` con datos reales de campo.

**Distribución sugerida**:

| Tipo de evento | Pares mínimos |
|---|---|
| Plaga / enfermedad | 15 |
| Aplicación de insumo | 20 |
| Avance de labor | 10 |
| Gasto / costo | 10 |
| Nota libre / consulta | 5 |

**Cómo construirlo**:
1. Recopilar audios/mensajes reales de campo (con permiso de usuarios).
2. Transcribir manualmente los audios con transcripción incierta.
3. Construir el JSON esperado a mano para cada mensaje.
4. Guardar en la tabla `eval_dataset` (ver `backend/sql/01-schema-core.sql`).

---

## 9.3 Métricas de calidad

### Field-level accuracy (métrica principal)

| Campo | Peso | Criterio de “correcto” |
|---|---|---|
| `event_type` | Alto | Tipo de evento correcto |
| `id_field` (lote) | Crítico | Lote mapeado al ID correcto |
| `event_time` | Alto | Fecha/hora dentro de ±1 hora |
| `dose` | Crítico (aplicaciones) | Valor numérico correcto |
| `dose_unit` | Alto | Unidad correcta o normalizable |
| `pest_name` | Medio | Nombre reconocible |

**Meta MVP**: ≥ 85% de field-level accuracy antes de lanzar a usuarios reales.

Los resultados se guardan en la tabla `eval_results` para comparar versiones de modelo/prompt.

### Métricas secundarias

- **Tasa de mandatory_missing**: % de eventos que requieren al menos 1 pregunta de aclaración.
- **Turnos promedio para completar un evento**: mensajes necesarios hasta evento completo.
- **Latencia del pipeline**: tiempo desde mensaje hasta confirmación al usuario.
- **Costo por evento**: tokens LLM + STT por evento completado.

---

## 9.4 Proceso de mejora continua

1. **Baseline**: medir field-level accuracy con el prompt inicial sobre el dataset de evals.
2. **Identificar debilidades**: qué campos se pierden más, qué tipos de mensaje fallan más.
3. **Iterar el prompt** del agente PDR/SR y re-medir sobre el mismo dataset.
4. **Capturar errores reales**: cuando un usuario corrige la confirmación del bot, ese par va al dataset de evals (`eval_dataset`).
5. **Destilar clasificador** cuando el dataset supere 500 ejemplos (roadmap v1).

---

## 9.5 Tabla de acciones por fase

| Fase | Acción | Output |
|---|---|---|
| **Semana 1** | 10–20 audios reales → testear 3 variantes de prompt, medir field-level accuracy a mano | Prompt PDR/SR inicial validado |
| **Semana 2** | Instalar LangFuse en GCP (Cloud Run + tu Cloud SQL existente, ~$5–10/mes extra) | Dashboard de observabilidad activo |
| **Semana 2** | Construir dataset de 50–100 pares, conectar trazas al pipeline | Costo real por tipo de evento visible |
| **Mes 2** | Baseline formal de field-level accuracy, segunda iteración del prompt | Mejora documentada vs baseline |
| **Mes 3–6** | 500 pares corregidos → destilar clasificador de tipo de evento | Clasificador propio: costo −99% vs LLM |
