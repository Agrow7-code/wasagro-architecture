# Wasagro – Asistente de Campo AI-First para Agricultura de Exportación

Wasagro es un sistema **AI-first** para capturar, estructurar y usar datos operativos de fincas de exportación en Latinoamérica (banano, cacao, café, palma, etc.), usando como interfaz natural **WhatsApp y voz/foto/texto**.

La hipótesis central:  
> El campo ya genera los datos correctos. El problema no es la tecnología, es la **fricción de captura** y la **maquillación de la realidad** en la cadena de reporte.

Wasagro ataca dos fricciones:
- **Captura**: convertir audios, fotos y mensajes sueltos en datos estructurados sin formularios pesados.  
- **Gobernanza y entrega (DELIVER)**: asegurar que lo que ve la gerencia es un reflejo honesto de lo que ocurre en lote, no un “Excel maquillado”.

---

## Tabla de contenidos

- [1. Problema y contexto](#1-problema-y-contexto)
- [2. Statement AI-First](#2-statement-ai-first)
- [3. Arquitectura de alto nivel](#3-arquitectura-de-alto-nivel)
- [4. Modelo de datos (Postgres + PostGIS)](#4-modelo-de-datos-postgres--postgis)
- [5. Flujos de WhatsApp](#5-flujos-de-whatsapp)
- [6. Governanza de datos e IA](#6-governanza-de-datos-e-ia)
- [7. Entrega y productos (DELIVER)](#7-entrega-y-productos-deliver)
- [8. Costos de infraestructura y modelos](#8-costos-de-infraestructura-y-modelos)
- [9. Roadmap y versiones](#9-roadmap-y-versiones)

---

## 1. Problema y contexto

En fincas agrícolas de exportación en LATAM, una parte significativa de la operación diaria **no llega** a un sistema digital: se queda en libretas, audios de WhatsApp, Excel impresos o simplemente en memoria.

El flujo típico de “realidad endulzada”:

1. **Campo**: el trabajador o digitador ve una plaga descontrolada o calibres deficientes y reporta un problema crítico.  
2. **Supervisor**: transmite una versión parcial (“hay un desafío, pero lo estamos manejando”).  
3. **Sub-Gerente**: convierte el reporte en gráficos y lo re‑etiqueta como “oportunidad de mejora en proceso”.  
4. **Gerente**: asegura al CEO que todo está bajo control.  
5. **CEO/Junta**: reporta que se logrará un año récord.

El choque con la realidad ocurre en el **puerto de destino**:
- Los kilos no aparecen (estimaciones irreales).  
- La calidad no cumple lo que el cliente esperaba.  
- La confianza se erosiona.

**Principio de diseño**:
- El único dato que representa la realidad es el que se captura en campo **tal como es**.  
- Si la cultura castiga el “mal dato”, el dato se maquilla.  
- Wasagro debe ser un mecanismo que:
  - reduzca la fricción para decir la verdad, y  
  - la haga visible de forma responsable a todos los niveles.

Más detalle en [`docs/01-problema-y-contexto.md`](docs/01-problema-y-contexto.md).

---

## 2. Statement AI-First

En lugar de construir formularios y GUIs complejas que fuerzan al humano a pensar como la máquina, Wasagro adopta una arquitectura **AI-first** donde la IA actúa como **Agente Estructurador Inteligente**:

- **La IA es la interfaz de ingestión**, no solo un dashboard posterior.  
- Toma audios, fotos y texto natural (con jerga local) y los convierte en **eventos de base de datos** (JSON) mediante un **operador PDR/SR ligero**:
  - genera 1–N borradores,  
  - los refina/combina,  
  - y produce un workspace compacto + JSON final.  

Capacidades clave:
- Entendimiento multimodal (voz, imagen, texto).  
- Estructuración autónoma (sin formularios).  
- Loop humano activo (si falta lote, fecha o dosis, pregunta).  
- Conciencia agro-contextual (unidades como “bombadas”, “canecas”, condiciones de lluvia, etc.).  

Detalle arquitectónico en [`docs/02-arquitectura-ai-first.md`](docs/02-arquitectura-ai-first.md).

---

## 3. Arquitectura de alto nivel

### 3.1 Componentes lógicos

- **Canales de entrada**:
  - WhatsApp / Telegram (primario).  
  - Opcional: app ligera o botón físico/IoT.

- **Capa EXTRACT**:
  - STT (Whisper/Voxtral/…) para audio.  
  - OCR para texto en fotos (libretas, etiquetas).  
  - Limpieza de texto y normalización.

- **Capa CATEGORIZE (Router de complejidad/presupuesto)**:
  - Clasifica tipo de evento: plaga, insumo, labor, gasto, nota, consulta.  
  - Estima riesgo y necesidad de conocimiento externo (RAG).  
  - Decide ruta:
    - Modelo base + PDR/SR.  
    - Modelo base + RAG.  
    - Modelo premium + RAG + multiagentes.

- **Capa QUOTE (Agente estructurador PDR/SR)**:
  - Modelo base (80% de volumen) que:
    - genera borradores de JSON,  
    - refina y consolida en workspace compacto,  
    - marca campos obligatorios faltantes (ej. lote, dosis, fecha).

- **Capa ANALYZE**:
  - Analítica clásica (KPIs) + consultas LLM.  
  - Enlaces con `weather_hourly` y otros datos contextuales.

- **Capa ASSIST**:
  - Respuestas en WhatsApp (sugerencias, checklists).  
  - Multiagentes para verificar reglas/dosis/historial antes de recomendar.

- **Capa DELIVER**:
  - Respuestas inmediatas por WhatsApp.  
  - Panel web por finca/rol.  
  - Reportes PDF/Excel periódicos.  
  - Webhooks/APIs hacia ERP/contabilidad.

La implementación de servicios y endpoints está en [`backend/README.md`](backend/README.md) y [`docs/04-flujos-whatsapp.md`](docs/04-flujos-whatsapp.md).

---

## 4. Modelo de datos (Postgres + PostGIS)

Wasagro usa **Cloud SQL for PostgreSQL + PostGIS** como base operacional:

### Entidades principales

- `roles` – rol del usuario (trabajador, jefe de campo, gerente, etc.).  
- `farms` – fincas, con centroide y polígono (`GEOGRAPHY`).  
- `fields` – lotes/cuarteles, vinculados a fincas, con geometría.  
- `users` – usuarios con número de WhatsApp y rol.  
- `events` – eventos operativos normalizados.  
- `event_payloads` – payload JSONB específico según tipo de evento.  
- `raw_messages` / `message_processed` – mensajes crudos y su procesamiento STT/OCR.  
- `router_decisions` – decisiones del router de complejidad.  
- `workspaces` – resumen de razonamiento PDR/SR por evento.  
- `weather_hourly` – clima horario con `location` (POINT) y `ts_utc`.  
- `event_with_weather` – vista que une eventos con el clima más cercano.

Ejemplo simplificado de tablas y vistas en [`backend/sql/01-schema-core.sql`](backend/sql/01-schema-core.sql) y [`backend/sql/02-schema-weather.sql`](backend/sql/02-schema-weather.sql).

---

## 5. Flujos de WhatsApp

### 5.1 Onboarding de gerente (mini‑encuesta)

- Flujo para entender:
  - Foco (kilos, calidad, costos, sanidad, mixto).  
  - Horizonte de tiempo preferido.  
  - Nivel de detalle (finca vs lote).  
  - Frecuencia de informes.  
  - Canal de entrega (solo WA, WA + web, WA + PDF/Excel).  

- Implementado como **máquina de estados** (`ONBOARDING_Q1_FOCUS`, `ONBOARDING_Q2_TIME_HORIZON`, etc.) almacenada en `wa_conversations`.  
- Los resultados se guardan en `user_preferences` y un humano los revisa antes de activarlos.

### 5.2 Primer informe semanal + drill‑down

- Envío automático de:
  - Resumen adaptado a preferencias (ej. foco en calidad).  
  - Cinta de integridad de datos (cobertura, retraso, alertas abiertas).  
  - Link al panel web.  
- Opciones de drill‑down vía WhatsApp:
  - Ver lotes con peor calidad.  
  - Ver plagas más graves.  
  - Ver resumen de costos.  

Los textos exactos y la máquina de estados están documentados en [`flows/whatsapp-onboarding-gerente.md`](flows/whatsapp-onboarding-gerente.md) y [`flows/whatsapp-eventos-campo.md`](flows/whatsapp-eventos-campo.md).

---

## 6. Governanza de datos e IA

Principios:

- **Una sola fuente de verdad**: todos los paneles y reportes se construyen desde `events` y vistas derivadas.  
- **Dato vs interpretación**: cada vista distingue entre:
  - mediciones crudas (eventos de campo),  
  - agregaciones (KPIs),  
  - narrativas/insights generados por IA.  
- **Calidad de datos visible**:
  - cobertura (porcentaje de lotes reportando),  
  - retraso medio entre evento y registro,  
  - número de alertas críticas abiertas.  
- **Auditoría**:
  - cualquier cambio manual en eventos o KPIs se registra.  
- **Loop humano activo**:
  - para eventos críticos (plaga, dosis, decisiones de alto riesgo) hay revisión explicita (IA + humano).  

Más en [`docs/05-governanza-datos-e-ia.md`](docs/05-governanza-datos-e-ia.md).

---

## 7. Entrega y productos (DELIVER)

Canales de salida:

- **WhatsApp / redes**:
  - Confirmación de eventos (“Registré plaga X en lote Y a tal hora”).  
  - Recomendaciones contextualizadas y trazables.  

- **Panel web por finca y rol**:
  - Cinta de integridad de datos siempre visible.  
  - Mapa de lotes (color por KPI).  
  - Panel de alertas que no se puede ocultar sin marcar acción.  
  - KPIs adaptados a las preferencias del gerente.

- **Reportes PDF/Excel**:
  - Resumen ejecutivo + sección de integridad de datos.  
  - Producción, calidad, costos, plagas, anexos de eventos crudos.  
  - Generados por IA, revisados y aprobados por un humano antes de envío.

- **APIs / Webhooks**:
  - Exportación de datos a ERP/contabilidad con metadatos de calidad y procedencia.

Ver detalles y wireframes técnicos en [`docs/06-entrega-y-productos-deliver.md`](docs/06-entrega-y-productos-deliver.md).

---

## 8. Costos de infraestructura y modelos

Se documentan:

- Decisiones de stack en GCP (Cloud SQL Postgres+PostGIS, GKE, Storage, etc.).  
- Elección de modelos:
  - STT base (Whisper/Voxtral) + STT premium (Gemini/Scribe) para casos críticos.  
  - Modelo base para 80% de volumen (ej. Gemini Flash / GPT mini).  
  - Modelo premium para verificación normativa y documentos.  
- Estrategias de optimización:
  - cambio de modelo base, prompt caching, RAG + routing, LLMLingua‑2, destilación de skills propias.

Más en [`docs/07-costos-y-modelo-economico.md`](docs/07-costos-y-modelo-economico.md).

---

## 9. Roadmap y versiones

- **MVP**:
  - Captura por WhatsApp (audio + texto).  
  - Estructuración básica de eventos (plaga, labor, insumo, gasto).  
  - Panel web simple con mapa, alertas y 3–4 KPIs.  
  - Primer flujo de informe semanal.  

- **v1**:
  - Integración de clima (`weather_hourly` + `event_with_weather`).  
  - RAG básico con documentos de finca.  
  - Destilación del clasificador de tipo de evento.  

- **v2**:
  - Tri‑RAG agro, modelos especializados por cultivo.  
  - Multiagentes de verificación avanzada.  
  - Integraciones profundas con ERP/contabilidad.

Ver detalle en [`docs/08-roadmap-mvp-v1-v2.md`](docs/08-roadmap-mvp-v1-v2.md).
