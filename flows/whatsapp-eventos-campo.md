# Flujo de WhatsApp – Eventos de campo (esqueleto)

Este archivo describe el esqueleto del flujo para registrar eventos de campo (ej. plaga) via WhatsApp.

## Idea general

1. Trabajador envía audio/foto/texto describiendo un evento.  
2. IA interpreta y propone un borrador de evento (`event_type`, `id_field`, `event_time`, etc.).  
3. Si faltan campos obligatorios, se pregunta de vuelta.  
4. Una vez completo, se confirma y se informa al usuario.

## Posibles estados

- `FIELD_EVENT_START`
- `FIELD_EVENT_INTERPRETED`
- `FIELD_EVENT_NEEDS_CLARIFICATION`
- `FIELD_EVENT_CONFIRMATION_SENT`

El detalle se completará cuando se implemente el flujo de captura completo.
