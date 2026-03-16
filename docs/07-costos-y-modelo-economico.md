# 07 – Costos de infraestructura y modelo económico

Este documento resume las decisiones iniciales de infraestructura y cómo impactan en el costo mensual estimado, así como ideas para el modelo económico de Wasagro.

> Nota: todos los números son estimaciones de trabajo y deben refinarse con uso real.

---

## 7.1 Infraestructura base (GCP)

Componentes considerados para un MVP con ~1.000 usuarios activos:

- Cloud SQL for PostgreSQL + PostGIS (1 instancia).  
- GKE (1 clúster zonal, 2 nodos pequeños).  
- Cloud Storage (archivos, reportes, adjuntos).  
- Servicios de modelos (LLM/STT/OCR) vía APIs externas.

Se prioriza:

- Minimizar nodos y clústeres (1 clúster GKE, no 2).  
- Ajustar tamaños de instancia de BD y cache a carga real.  
- Mantener rutas claras para migrar a soluciones open‑weights cuando el volumen crezca.

---

## 7.2 Modelos de IA y costos

### 7.2.1 STT (voz → texto)

- Capa base: modelos open‑weights (Whisper, Voxtral) auto‑hospedados o vía proveedores de bajo costo.  
- Capa premium: modelos de alta precisión (Gemini STT, ElevenLabs Scribe) sólo para casos críticos o de baja confianza del modelo base.

### 7.2.2 LLMs

- Modelo base (80% del volumen): LLM rápido y barato (ej. Gemini Flash, GPT‑mini, modelo open‑source afinado).  
- Modelo premium (20% o menos): LLM con mejor razonamiento y comprensión de documentos (Claude/Gemini Pro) para:
  - verificaciones normativas,  
  - análisis de documentos largos,  
  - decisiones fitosanitarias de alto riesgo.

Estrategias de reducción de costo:

1. Cambiar modelo base a uno más eficiente (–90% del costo inmediato de tokens para el 80% de llamadas).  
2. Prompt caching y serialización eficiente (–60% adicional en input tokens repetitivos).  
3. RAG + routing de complejidad (–80% de uso de LLM grande en queries intensivas de conocimiento).  
4. LLMLingua‑2 en prompts largos (–14–20x en prompts de sistema y few‑shots extensos).  
5. Destilación de skills propias (–99% de uso de LLM grande en consultas de dominio repetitivas a largo plazo).

---

## 7.3 Costeo orientativo MVP (1.000 usuarios)

A muy alto nivel (no vinculante):

- Infraestructura GCP base (BD, GKE, storage): algunos cientos de USD/mes.  
- Tokens LLM + STT: algunos cientos de USD/mes, optimizables con las técnicas anteriores.  
- Total esperado MVP: en el orden de **$500–700 USD/mes** para 1.000 usuarios activos, sujeto a:
  - longitud media de mensajes,  
  - frecuencia de uso,  
  - porcentaje de consultas que requieren modelos premium.

Estos números son punto de partida para iterar el modelo de negocio (precio por ha, por finca, por usuario, etc.).

---

## 7.4 Modelo económico

Líneas posibles (a validar en mercado):

- Suscripción mensual por finca (ej. por ha o por tamaño de operación).  
- Tiers basados en:
  - número de usuarios,  
  - número de eventos/mes,  
  - volumen de tokens IA consumidos.

La meta es que el costo por ha/ciclo sea competitivo con soluciones agtech existentes, pero aportando:

- mayor integridad de datos,  
- menor fricción de captura,  
- y decisiones más confiables.
