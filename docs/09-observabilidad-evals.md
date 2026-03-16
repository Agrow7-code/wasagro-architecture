# 09 – Observabilidad y evaluación de calidad IA

Este documento define la estrategia de observabilidad y evaluación de calidad para el pipeline de IA de Wasagro.

> **Por qué es crítico desde el día 1**: sin observabilidad, todas las optimizaciones de tokens son estimaciones. No sabrás si el agente PDR/SR estructuró un audio correctamente al 95% o al 60%.

---

## 9.1 Stack de observabilidad

### LangFuse (self-hosted en GCP)

- **Qué es**: herramienta open source para trazar, evaluar y depurar pipelines LLM. Es el stack más usado en producción en 2025 para este tipo de pipeline.
- **Por qué self-hosted**: gratuito, los datos de campo no salen del entorno, fácil de desplegar en GKE.
- **Qué traza**:
  - cada llamada LLM (modelo, tokens input/output, latencia, costo estimado),
  - cada llamada STT (duración, confianza, modelo usado),
  - cada decisión del router (tipo de evento predicho, ruta elegida),
  - resultado final (JSON producido, campos extraídos, mandatory_missing resueltos).

### Integración con el pipeline

Cada servicio que llama a un LLM o STT envía trazas a LangFuse:

```python
# Ejemplo conceptual
with langfuse.trace(name="pdr_sr_agent", metadata={"event_type": "pest", "farm_id": farm_id}) as trace:
    transcript = stt_service.transcribe(audio)  # traza STT
    draft = llm.complete(prompt_borrador)        # traza LLM paso 1
    critique = llm.complete(prompt_reflexion)    # traza LLM paso 2
    final_json = llm.complete(prompt_refinement) # traza LLM paso 3
    trace.score(name="completeness", value=completeness_ratio)
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
2. Transcribir manualmente los audios que tengan transcripción incierta.
3. Construir el JSON esperado a mano para cada mensaje.
4. Guardar los pares en una tabla de evals (`eval_dataset`) en la BD.

---

## 9.3 Métricas de calidad

### Field-level accuracy (métrica principal)

Evalúa qué porcentaje de campos obligatorios se extrajo **correctamente** en el JSON final.

| Campo | Peso | Criterio de "correcto" |
|---|---|---|
| `event_type` | Alto | Tipo de evento correcto |
| `id_field` (lote) | Crítico | Lote mapeado al ID correcto |
| `event_time` | Alto | Fecha/hora dentro de ±1 hora |
| `dose` | Crítico (para aplicaciones) | Valor numérico correcto |
| `dose_unit` | Alto | Unidad correcta o normalizable |
| `pest_name` | Medio | Nombre reconocible (puede haber variantes) |

**Cálculo**:
```
field_level_accuracy = campos_correctos / total_campos_obligatorios
```

**Meta MVP**: ≥ 85% de field-level accuracy en el dataset de evals antes de lanzar a usuarios reales.

### Métricas secundarias

- **Tasa de mandatory_missing**: porcentaje de eventos que requieren al menos 1 pregunta de aclaración.
- **Turnos promedio para completar un evento**: cuántos mensajes necesita el usuario para registrar un evento completo.
- **Latencia del pipeline**: tiempo desde que llega el mensaje hasta que se envía confirmación al usuario.
- **Costo por evento**: tokens LLM + STT por evento completado.

---

## 9.4 Proceso de mejora continua

1. **Baseline**: medir field-level accuracy con el prompt inicial sobre el dataset de evals.
2. **Identificar debilidades**: qué campos se pierden más, qué tipos de mensaje fallan más.
3. **Iterar el prompt** del agente PDR/SR y re-medir sobre el mismo dataset.
4. **Registrar errores reales** en producción: cuando un usuario corrige la confirmación del bot, ese par mensaje → corrección va al dataset de evals.
5. **Destilar clasificador** cuando el dataset de pares correctos supere 500 ejemplos (ver roadmap v1).

---

## 9.5 Tabla de acciones por fase

| Fase | Acción | Output |
|---|---|---|
| **Semana 1** | Tomar 10–20 audios reales, testear 3 variantes de prompt (single-shot, ReAct 2-paso, Reflexion 3-paso), medir field-level accuracy a mano | Prompt PDR/SR inicial validado con datos reales |
| **Semana 2** | Instalar LangFuse en GCP, construir dataset de 50–100 pares, conectar trazas al pipeline | Dashboard de observabilidad con costo real por tipo de evento |
| **Mes 2** | Baseline formal de field-level accuracy, identificar campos con peor extracción, segunda iteración del prompt | Mejora documentada de accuracy vs baseline |
| **Mes 3–6** | Acumular 500 pares corregidos, destilar clasificador de tipo de evento | Clasificador propio: costo −99% vs LLM completo |
