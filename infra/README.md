# Infraestructura de Wasagro

Este directorio contiene documentación de la arquitectura en la nube (GCP) y manifiestos de despliegue (Kubernetes).

## Componentes principales (MVP)

- Cloud SQL for PostgreSQL + PostGIS.  
- GKE (1 clúster zonal con 1–2 nodos pequeños).  
- Cloud Storage (archivos, reportes, backups).  
- Integraciones con APIs de modelos (LLM/STT/OCR).

Más detalles en `gcp-architecture.md`.
