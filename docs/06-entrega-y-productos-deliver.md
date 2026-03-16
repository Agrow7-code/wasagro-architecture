# 06 – Entrega y productos (DELIVER)

Este documento detalla la capa de entrega de información de Wasagro: cómo se presentan los datos a trabajadores, jefes de campo, gerentes y sistemas externos.

---

## 6.1 Principios de diseño de DELIVER

- **Mis datos, mi realidad**: cada finca ve sus datos, con métricas adaptadas a sus prioridades, pero con la misma lógica de integridad y trazabilidad.  
- **Verdad antes que comodidad**: es mejor ver un KPI con baja cobertura de datos que un "excel perfecto" basado en supuestos.  
- **Multicanal**: WhatsApp, panel web, reportes y APIs ofrecen vistas complementarias sobre la misma fuente de verdad.

---

## 6.2 WhatsApp y redes

### 6.2.1 Trabajadores y jefes de campo

- Confirmación inmediata de eventos registrados:

  > "Registré: plaga **roya** severidad **alta** en **Lote 4** hoy a las 6:30 am. Si algo está mal, dímelo para corregirlo."

- Preguntas de aclaración cuando falta información crítica (lote, dosis, fecha).

### 6.2.2 Gerentes

- Resúmenes periódicos (diario/semanal/según preferencia) con:
  - KPIs clave (adaptados a foco personal),  
  - bloque de integridad de datos,  
  - link al panel web para detalle.

---

## 6.3 Panel web por finca y rol

### 6.3.1 Layout base

- Cinta superior de **integridad de datos**.  
- Mapa de lotes con color por KPI (producción, calidad, sanidad, costos).  
- Panel de alertas críticas (no ocultable sin acción registrada).  
- Tarjetas de KPIs principales, ordenadas según preferencias del usuario.  
- Timeline de eventos clave (filtrable).

### 6.3.2 Adaptación por finca y usuario

- El mismo layout sirve para muchas fincas; lo que cambia es:
  - el filtro por `id_farm`,  
  - la priorización de KPIs (foco en calidad vs kilos vs costos),  
  - el nivel de detalle (sólo finca o finca + lotes) según `user_preferences`.

---

## 6.4 Reportes PDF/Excel

### 6.4.1 Estructura propuesta

1. Portada (finca, periodo, responsable).  
2. Resumen ejecutivo (KPIs + integridad de datos).  
3. Producción (por finca y por lote).  
4. Calidad (rechazos, calibres, reclamos).  
5. Costos (por ha, por centro de costo).  
6. Plagas y riesgos.  
7. Anexos de eventos crudos.

### 6.4.2 Generación y revisión

- Un job genera un borrador de reporte usando `events` y vistas analíticas.  
- Un humano revisa y marca `status='approved'` antes de enviarlo.  
- El reporte se almacena en storage y se notifica por WhatsApp/correo.

---

## 6.5 APIs y Webhooks

- Endpoints para exportar datos a ERP/contabilidad incluyen:
  - montos y cantidades,  
  - metadatos de calidad de dato (cobertura, método de estimación),  
  - referencias a eventos fuente cuando sea viable.

- Webhooks permiten que sistemas externos reaccionen a eventos de Wasagro (ej. nueva alerta crítica, cierre de un ciclo de cosecha).

El objetivo de la capa DELIVER es que **ningún actor clave tenga que vivir en un Excel paralelo para entender qué está pasando en la finca**.
