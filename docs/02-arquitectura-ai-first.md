# Arquitectura AI-First de Wasagro

Este documento describe la arquitectura AI-first de Wasagro: cómo se capturan datos desde WhatsApp, cómo la IA los estructura, cómo se decide qué modelo usar y cómo esos datos terminan alimentando decisiones confiables.

---

## 1. Principios de diseño

1. **La IA es la interfaz de ingestión**  
   La IA no es solo un dashboard posterior. Es el primer actor que recibe audios, fotos y texto, y los transforma en eventos de base de datos.

2. **Operador PDR/SR ligero**  
   En lugar de una sola pasada prompt → respuesta, usamos un ciclo corto de:
   - **P** (Parallel Drafting): uno o varios borradores de interpretación.  
   - **D** (Distillation): consolidar esos borradores.  
   - **R** (Refinement / Sequential-Refine): pulir el resultado final y marcar dudas.

3. **Loop humano activo**  
   Cuando faltan campos críticos (lote, dosis, fecha) o la confianza es baja, la IA **pregunta de vuelta** por WhatsApp antes de cerrar el evento.

4. **RAG y destilación como capas ortogonales**  
   - RAG trae conocimiento externo (etiquetas, normas, SOPs, historial).  
   - La destilación va internalizando skills frecuentes en modelos pequeños específicos.

5. **Deliver anti‑maquillaje**  
   La capa de entrega (dashboards, reportes, resúmenes WA) está diseñada para mostrar siempre la calidad del dato y evitar que la realidad se “endulce” a medida que sube en la organización.

---

## 2. Diagrama lógico de la arquitectura

```text
[Canales de campo]
  - WhatsApp / Telegram / red social preferida
  - (Opcional) App ligera
  - (Opcional) Botón físico / dispositivo IoT

        │
        ▼
1) EXTRACT  (Ingesta multimodal)
  - STT: transcribe audio (Whisper/Voxtral/…)
  - OCR: texto desde fotos (libretas, etiquetas, carteles)
  - Texto nativo: mensajes escritos
  - Metadata: usuario, rol, finca, lote (si viene), timestamp, geolocalización

        │
        ▼
2) CATEGORIZE  (Router de complejidad / presupuesto)
  - Clasificación de tipo de evento:
      · plaga / enfermedad
      · uso de insumo / agroquímico
      · avance de labores / tareas
      · gasto / insumo económico
      · nota libre / consulta
  - Estimación de:
      · riesgo agronómico / normativo
      · necesidad de conocimiento externo (RAG o no)
      · presupuesto de cómputo y latencia por rol
  - Decisión de ruta:
      · solo Modelo Base + PDR/SR ligero
      · Modelo Base + RAG
      · Modelo Premium + RAG
      · activar o no multiagentes de verificación

        │
        ├─────────────▶ [Capa de Eficiencia]
        │                 - Prompt caching
        │                 - Serialización JSON compacta
        │                 - Compresión LLMLingua-2 en system prompts / few-shots
        │
        ▼
3) QUOTE  (Agente estructurador PDR/SR ligero)
  - Modelo Base (80% del volumen) opera como OPERADOR, no como una sola pasada:
      · Entrada: {transcripción STT, texto OCR, texto nativo, metadata, contexto corto}
      · Ronda 0: genera 1–N borradores de JSON (evento estructurado)
      · Ronda 1 (SR o PDR):
          · SR: refine sobre un borrador con feedback interno
          · PDR: varios borradores + distillation a un workspace compacto
      · Salida:
          · JSON estructurado (evento) normalizado
          · Workspace corto (razonamiento clave / dudas)

        │
        ▼
4) ANALYZE  (Motor de análisis y decisión)
  - Lado clásico (no‑LLM):
      · KPIs (rendimiento, uso de insumos, costos)
      · detección de anomalías simples
  - Lado LLM:
      · consultas complejas sobre historial
      · generación de explicaciones y resúmenes por lote/finca
  - RAG (capa ortogonal 1):
      · se activa cuando el router marca que la consulta es knowledge‑intensive

        │
        ▼
5) ASSIST  (Asistencia en tiempo real)
  - Generación de respuestas y recomendaciones por WhatsApp:
      · mensajes claros y accionables
      · checklists de “próximos pasos”
  - Multiagentes (calidad, no costo):
      · verificador de dosis/normas
      · agente que cruza con historial del lote y clima
      · agente auditor para casos críticos

        │
        ▼
6) DELIVER  (Entrega)
  - Respuesta inmediata en WhatsApp / red social
  - Panel web por finca y rol
  - Reportes PDF/Excel periódicos
  - Webhooks / APIs hacia ERP/contabilidad
```

---

## 3. Componentes de backend y servicios

### 3.1 Servicios API

- `auth-service`
  - Login, JWT, autorización por rol.

- `user-config-service`
  - Maneja las preferencias de visualización de cada usuario/finca (resultado de la mini‑encuesta por WA).

- `events-service`
  - CRUD de eventos (`events`, `event_payloads`).
  - Endpoints agregados para KPIs, alertas, timelines.

- `weather-service`
  - Ingesta y consulta de `weather_hourly`.
  - Unión espacial/temporal con eventos.

- `whatsapp-bot-service`
  - Webhook con proveedor de WhatsApp.
  - Implementa la máquina de estados de conversación para:
    - captura de eventos de campo,
    - onboarding de gerentes,
    - envío de informes/resúmenes.

- `reporting-service`
  - Generación de reportes PDF/Excel.
  - Manejo de estados `draft` / `approved` / `sent`.

- `dashboard-web`
  - SPA (React/Vue/etc.) para gerentes y equipo técnico.

### 3.2 Flujo de un evento típico (plaga)

1. Trabajador envía audio por WhatsApp: “Encontré roya fuerte en el lote 4, parte baja.”
2. `whatsapp-bot-service` recibe el webhook, guarda `raw_message`.
3. `EXTRACT`:
   - STT transcribe audio.
   - Se normaliza texto y se asocia a `id_user`, `id_farm` vía número de teléfono.
4. `CATEGORIZE`:
   - Clasificador predice `event_type = pest`, `scope = field`.
   - Marca que se requiere lote obligatorio.
5. `QUOTE` (PDR/SR ligero):
   - Modelo base genera borrador de JSON:
     ```json
     {
       "event_type": "pest",
       "pest_name": "roya",
       "severity": "alta",
       "field_candidate": "Lote 4",
       "event_time": "hoy 06:30"
     }
     ```
   - Refinement valida lote contra BD y normaliza fecha.
   - Si falta algo esencial (ej. lote o fecha clara), el sistema pregunta por WA.
6. Se guarda `event` + `event_payload` + `workspace`.
7. `ANALYZE`/`ASSIST` decide si se dispara una recomendación inmediata (ej. monitoreo extra, acción correctiva).
8. El evento y sus efectos se reflejan en el panel y en futuros reportes.

---

## 4. Router de complejidad / presupuesto

El router decide qué ruta seguir para cada mensaje, usando:

- Features de entrada:
  - tipo de usuario (rol),
  - tipo de evento estimado,
  - longitud del mensaje,
  - historial de problemas recientes en la finca,
  - nivel de riesgo (ej. plagas y agroquímicos son alto riesgo).

- Acciones posibles:
  - `ACCEPT_BASE`: usar solo modelo base + PDR/SR.
  - `ESCALATE_RAG`: usar modelo base + RAG.
  - `ESCALATE_PREMIUM`: usar modelo premium + RAG + multiagentes.
  - `ASK_CLARIFICATION`: no crear evento aún, pedir datos faltantes.

En el MVP, el router puede implementarse con reglas estáticas. Más adelante puede entrenarse un policy (RL) inspirada en cascadas de modelos.

---

## 5. RAG y destilación de skills

### 5.1 RAG (capa ortogonal)

- Índices sobre:
  - etiquetas de productos,
  - manuales/SOPs,
  - normativa y documentación interna,
  - parte del historial de eventos.

- Servicio `rag-service`:
  - `retrieve(query, k)` devuelve pasajes relevantes.
  - Se usa cuando `router.need_rag = true`.

### 5.2 Destilación de skills

- A partir de logs reales (input crudo + evento final) se entrenan modelos pequeños para:
  - clasificar tipo de evento,
  - normalizar unidades/formatos,
  - detectar dosis fuera de rango,
  - mapear jerga → esquema interno.

- Estos modelos se intercalan antes del LLM generalista progresivamente, reduciendo tokens y costo a largo plazo.

---

## 6. Capa DELIVER consciente de integridad del dato

- Todos los canales de salida (WA, panel, reportes, APIs) muestran:
  - métricas de **integridad de datos** (cobertura, retraso, alertas abiertas),
  - separación clara entre dato crudo, agregación y narrativa.

- El objetivo no es reportar “todo verde”, sino permitir decisiones basadas en realidad, incluso cuando la realidad es incómoda.
