# Arquitectura en GCP para Wasagro

Diseño orientativo de infraestructura en Google Cloud Platform.

## Recursos principales

- **VPC** dedicada para servicios de Wasagro.  
- **Cloud SQL** (PostgreSQL + PostGIS) para datos operacionales.  
- **GKE** para servicios backend (auth, events, whatsapp-bot, reporting, etc.).  
- **Cloud Storage** para ficheros (reportes, adjuntos).  
- **Cloud Load Balancer** para exponer APIs y webhook de WhatsApp.

## Consideraciones

- 1 clúster GKE zonal es suficiente para el MVP; en fases posteriores se puede pasar a regional.  
- Se debe configurar autopilot/autoscaling con límites conservadores para controlar costos.  
- Acceso a Cloud SQL desde GKE usando Private IP y/o SQL Proxy.

Este archivo se irá enriqueciendo con diagramas y configuraciones concretas.
