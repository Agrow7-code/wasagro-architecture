# 05 – Governanza de datos e IA en Wasagro

Este documento define los principios y mecanismos de gobernanza de datos e IA que guían el diseño de Wasagro.

---

## 5.1 Objetivos

- Asegurar que los datos que ven gerentes y juntas reflejan la **realidad operativa**, no una versión maquillada.  
- Hacer visibles los límites y la calidad de los datos (qué sabemos y qué no sabemos).  
- Dar confianza en que las recomendaciones de IA se basan en datos íntegros y trazables.  
- Cumplir con buenas prácticas de transparencia y responsabilidad en IA.

---

## 5.2 Una sola fuente de verdad

- Los datos de operación se registran **una sola vez** en la base operacional (`events`, `event_payloads`, `raw_messages`).  
- Paneles, reportes y APIs se construyen sobre estas tablas y vistas derivadas.  
- No se permiten “Excels paralelos” como fuente de KPIs oficiales.

Consecuencia: si un KPI está mal, se corrige desde su origen (eventos), no solo en el reporte.

---

## 5.3 Dato vs interpretación

Toda vista debe distinguir explícitamente entre:

- **Dato crudo**: observaciones de campo (eventos, mediciones, fotos).  
- **Agregaciones**: promedios, sumas, KPIs por lote/finca.  
- **Narrativas**: explicaciones, insights o historias generadas por IA o humanos.

En el frontend, esto se refleja en:

- Secciones separadas en dashboards y reportes.  
- Etiquetas claras (“Datos registrados”, “Cálculos”, “Comentarios/Análisis”).

---

## 5.4 Calidad de datos visible

La integridad de datos no se esconde; se hace protagonista:

- **Cobertura**: porcentaje de lotes con al menos un reporte en un periodo.  
- **Retraso**: tiempo medio entre evento en campo y registro en el sistema.  
- **Alertas abiertas**: número de eventos críticos sin acción marcada.

Estos indicadores aparecen como **cinta superior** en el dashboard y como bloque en los reportes PDF.

---

## 5.5 Loop humano activo

Para eventos de alto riesgo (plagas severas, uso de agroquímicos, decisiones fitosanitarias):

- La IA puede sugerir, pero no decide sola.  
- Se marca explícitamente cuándo intervino un humano para aprobar o ajustar:
  - en la entidad `events` (quién confirmó, cuándo),  
  - en `reports` (quién aprobó cada reporte antes de enviarlo).

Esto crea una cadena clara de responsabilidad compartida IA + humano.

---

## 5.6 Auditoría y trazabilidad

- Cualquier modificación manual en un evento o en un KPI derivado debe quedar registrada (campos `updated_by`, `updated_at`, comentarios).  
- Los modelos de IA usados (versión, proveedor, parámetros clave) se registran cuando sea relevante para auditoría (especialmente en recomendaciones críticas).

En fases futuras se pueden añadir tablas específicas de auditoría de modelos.

---

## 5.7 Protección contra "+datos bonitos"

Wasagro incorpora mecanismos de diseño para evitar el sesgo de “poner todo en verde”:

- Los KPIs principales van siempre acompañados de **indicadores de calidad de dato**.  
- Las alertas críticas no se pueden ocultar sin registrar una acción (o motivo de no acción).  
- Los reportes incluyen muestras de eventos crudos en anexos, para que quien lea pueda comparar la narrativa con la realidad.

La cultura que se quiere reforzar: “es mejor ver un problema temprano que descubrirlo en el puerto”.
