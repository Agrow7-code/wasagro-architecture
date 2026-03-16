# 03 – Modelo de datos en Postgres + PostGIS

Este documento explica el modelo de datos básico de Wasagro usando PostgreSQL y PostGIS como base de datos operacional.

El DDL completo está en `backend/sql/01-schema-core.sql`. Aquí se describe el **por qué** de las principales tablas.

---

## 3.1 Motor de base de datos

- PostgreSQL 15+ como motor relacional principal.  
- Extensión PostGIS para:
  - almacenar geometrías de fincas y lotes (POINT, POLYGON),  
  - realizar joins espaciales con datos meteorológicos y otras capas.

Ventajas:

- Soporta SQL estándar, JSONB y tipos espaciales.  
- Se integra bien con BigQuery / data lakes más adelante.  
- Es maduro y ampliamente usado en soluciones agrícolas y geoespaciales.

---

## 3.2 Entidades núcleo

### 3.2.1 roles

Define los roles de usuario:

- `worker` (trabajador de campo)  
- `field_manager` (jefe de campo)  
- `farm_manager` (gerente de finca)  
- `advisor` (consultor agrónomo)  
- otros según el caso.

Se usa para controlar accesos y adaptar vistas (lo que ve un trabajador vs un gerente).

### 3.2.2 farms y fields

- `farms` representa una finca o unidad productiva completa.
  - Contiene `centroid` y `boundary` para unir con clima y capas espaciales.
- `fields` representa lotes/cuarteles dentro de una finca.
  - Tiene `area_ha`, `crop_type` y geometría propia.

Estos niveles permiten:

- Registrar eventos **por lote** cuando se necesitan decisiones muy finas.  
- Registrar eventos a nivel **finca** (compras, costos generales) cuando aplica.

### 3.2.3 users

Representa a cualquier persona que interactúa con Wasagro (por WhatsApp o panel web):

- `phone_msisdn` se usa para mapear mensajes entrantes a `id_user`.  
- `id_role`, `id_farm` definen el contexto primario de ese usuario.

---

## 3.3 Captura de mensajes y eventos

### 3.3.1 raw_messages y message_processed

- `raw_messages` almacena el mensaje crudo del canal (WA/app):
  - texto original, audio, imagen, metadata y timestamps.
- `message_processed` guarda los resultados de STT/OCR:
  - transcripción de audio (`text_stt`), texto extraído de imagen (`text_ocr`), idioma, etc.

Esta separación permite re‑procesar mensajes antiguos con mejores modelos sin perder el original.

### 3.3.2 events y event_payloads

- `events` es la tabla central de **eventos operativos** estructurados:
  - quién reportó (`id_user`),  
  - qué finca y lote (`id_farm`, `id_field`, `scope`),  
  - tipo de evento (`event_type`),  
  - nivel de riesgo y estados (`status`, `completeness_status`),  
  - tiempo del evento (`event_time`) y confianza `source_time_confidence`.

- `event_payloads` contiene el detalle específico en `JSONB`:
  - para `pest`: nombre de plaga, severidad, superficie afectada, etc.  
  - para `input_application`: insumo, dosis, unidades, área, método, etc.  
  - para `expense`: monto, moneda, centro de costo.

Este diseño separa **estructura común** de **detalle flexible**, permitiendo iterar rápido en nuevos tipos de evento sin migraciones complejas.

### 3.3.3 router_decisions y workspaces

- `router_decisions` registra cómo el router de complejidad decidió tratar un mensaje:
  - tipo de evento predicho,  
  - modelo usado,  
  - flags de necesidad de RAG, modelo premium o revisión multiagente.

- `workspaces` guarda un resumen corto del razonamiento del modelo (PDR/SR) por evento:
  - explica cómo se llegó al JSON final,  
  - sirve para auditoría y debugging.

---

## 3.4 Preferencias y reportes

### 3.4.1 user_preferences

Almacena la configuración de cada usuario para cada finca:

- foco (producción, calidad, costos, sanidad, mixto),  
- horizonte de tiempo,  
- nivel de detalle,  
- frecuencia de informes,  
- canales de entrega.

Se alimenta desde la **mini‑encuesta por WhatsApp** y requiere aprobación humana antes de usarse en producción.

### 3.4.2 reports

Registra cada reporte generado (PDF/Excel):

- periodo (`from_date`, `to_date`),  
- tipo (`weekly`, `monthly`),  
- `file_uri` en el storage,  
- estado (`draft`, `approved`, `sent`).

---

## 3.5 Conversaciones de WhatsApp

### 3.5.1 wa_conversations

Almacena el estado actual de la máquina de estados conversacional por número de teléfono:

- `current_state`: nombre del estado actual (ej. `ONBOARDING_Q1_FOCUS`).  
- `context`: JSON con respuestas parciales, ids de finca, etc.

Esto permite soportar múltiples flujos (onboarding, informes, captura de eventos) de forma robusta.

---

## 3.6 Extensiones futuras

- Tablas específicas para producción y calidad por lote/fecha (si necesitas SQL más rico).  
- Tablas de normas/reglas agronómicas por cultivo/insumo.  
- Historial de versiones de modelos usados (para trazabilidad de IA).
