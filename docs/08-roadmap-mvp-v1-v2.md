# 08 – Roadmap MVP, v1 y v2

Este documento resume las etapas previstas de desarrollo de Wasagro.

---

## 8.1 MVP

Objetivo: validar problema/solución y flujo AI-first en 1–2 fincas piloto.

Alcance mínimo:

- Captura de eventos por WhatsApp (texto + audio → STT):
  - tipos de evento: plaga, labor, insumo, gasto, nota.  
  - estructuración básica (lote, fecha, severidad, dosis, monto).

- Base de datos operacional con Postgres + PostGIS:
  - `farms`, `fields`, `users`, `events`, `event_payloads`, `raw_messages`, `message_processed`.

- Panel web simple para gerentes:
  - mapa de lotes con 1–2 KPIs,  
  - panel de alertas,  
  - timeline de eventos.

- Flujo de onboarding de gerente por WhatsApp y primer informe semanal.

---

## 8.2 v1

Objetivo: robustecer producto y empezar a escalar a más fincas.

Features adicionales:

- Integración de clima:
  - tabla `weather_hourly`,  
  - vista `event_with_weather`.

- RAG básico:
  - indexar etiquetas de productos, manuales internos, SOPs.  
  - permitir consultas de soporte agronómico.

- Destilación del clasificador de tipo de evento:
  - entrenar modelo pequeño que clasifique eventos sin necesidad de LLM grande.

- Mejoras de panel web:
  - más KPIs, filtros, comparaciones inter‑semanales.

---

## 8.3 v2

Objetivo: profundizar en IA de dominio y gobernanza.

Features aspiracionales:

- Tri‑RAG agro:
  - combinación de embeddings densos, BM25 y grafos de conocimiento por cultivo/insumo.

- Modelos especializados por cultivo:
  - finetuning o prompting avanzado para banano, cacao, café, palma, etc.

- Multiagentes de verificación avanzada:
  - agentes que debaten decisiones críticas,  
  - validan consistencia entre eventos, clima y normas.

- Integraciones profundas con ERP/contabilidad:
  - sincronización de centros de costo,  
  - conciliación de compras y aplicaciones,  
  - reportes financieros ajustados a realidad de campo.

Este roadmap es un artefacto vivo y se ajustará en función del aprendizaje con usuarios reales.
