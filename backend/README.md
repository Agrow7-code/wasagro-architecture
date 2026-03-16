# Backend de Wasagro

Este directorio contiene la especificación de APIs y el esquema de base de datos para el backend de Wasagro.

## Estructura

- `api-spec-openapi.yaml` – borrador de especificación OpenAPI de los principales endpoints.  
- `sql/` – scripts SQL para crear el esquema core, tablas de clima y vistas analíticas.

## Servicios previstos

- `auth-service` – autenticación/autorización.  
- `events-service` – operaciones sobre eventos, KPIs, alertas.  
- `weather-service` – ingestión/consulta de clima.  
- `whatsapp-bot-service` – webhook y lógica de conversación.  
- `reporting-service` – generación y gestión de reportes.  
- `user-config-service` – preferencias de usuario/finca para dashboards y reportes.

Esta carpeta se irá llenando con implementaciones concretas (NestJS/FastAPI/etc.) en futuras iteraciones.
