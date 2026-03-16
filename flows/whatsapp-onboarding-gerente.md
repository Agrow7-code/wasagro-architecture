# Flujo de WhatsApp – Onboarding de gerente

Este archivo documenta el flujo de onboarding de un gerente vía WhatsApp y su implementación como máquina de estados.

## Texto del flujo

Ver README y `docs/04-flujos-whatsapp.md` para el contenido detallado de los mensajes.

## Estados de conversación

- `IDLE`
- `ONBOARDING_START`
- `ONBOARDING_Q1_FOCUS`
- `ONBOARDING_Q2_TIME_HORIZON`
- `ONBOARDING_Q3_DETAIL_LEVEL`
- `ONBOARDING_Q4_FREQUENCY`
- `ONBOARDING_Q5_CHANNEL`
- `ONBOARDING_SUMMARY`

Cada estado espera una entrada específica (número) y actualiza `user_preferences` al final.
