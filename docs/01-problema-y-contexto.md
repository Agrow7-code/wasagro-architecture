# 01 – Problema y contexto

Este documento amplía la sección de problema/contexto descrita en el README y la conecta con las decisiones de diseño de Wasagro.

## 1.1 Realidad operativa en fincas de exportación LATAM

En fincas de banano, cacao, café, palma y otros cultivos de exportación en Latinoamérica:

- La operación diaria es **intensiva en mano de obra** y distribuida en muchos lotes.  
- Los jefes de campo caminan entre 5 y 15 km al día, con clima variable, conectividad irregular y alta presión por cumplir metas.  
- El canal de comunicación natural es **WhatsApp** (audios, fotos, mensajes rápidos), no los ERPs ni las apps administrativas complejas.

### Brecha entre campo y oficina

El dato nace en el campo, pero viaja por:

- Libretas de papel.  
- Formatos de Excel impresos para llenar “más tarde”.  
- Audios y textos sueltos en chats de WhatsApp.  
- Memoria de los jefes de campo.

En la oficina, el dato se “traduce” en:

- Tablas agregadas y gráficas de PowerPoint.  
- Dashboards resumidos para gerencia.  
- Informes “para la Junta”, cada vez más alejados de la realidad del lote.

Cada traducción introduce fricción y sesgo.

## 1.2 Fricción de captura

Las interfaces tradicionales (formularios, ERPs, apps densas) exigen:

- Atención visual sostenida sobre pantallas en ambientes de sol, lluvia, humedad.  
- Motricidad fina (teclados pequeños, selects, combos) con manos sucias, mojadas o con guantes.  
- Vocabulario estándar que no refleja la jerga local ("bombadas", "canecas", "al trato").

Resultado: el trabajador **no registra** o registra a posteriori desde la memoria. El costo cognitivo de registrar supera el beneficio percibido.

## 1.3 Realidad endulzada en la cadena de reporte

La cadena típica de reporte se deforma así:

1. Campo: alguien observa un problema grave (plaga, calibre, falta de mano de obra) y lo comunica.  
2. Supervisor: filtra el problema para no quedar mal.  
3. Sub-Gerente: empaqueta los datos en gráficas que suenan a "oportunidad de mejora".  
4. Gerente: minimiza el riesgo al hablar con el CEO.  
5. CEO/Junta: reporta estimaciones optimistas hacia el cliente.

El **choque** con la realidad ocurre tarde (en puerto, en auditorías, en reclamos), cuando ya no hay margen de maniobra.

## 1.4 Tesis de Wasagro

- El dato correcto **ya se está viendo en el campo**.  
- El problema es que no se captura a tiempo, o se captura pero se maquilla en la subida.  
- La solución no es otro formulario; es una **interfaz IA-first** que hable el idioma del campo y respete la realidad.

Wasagro se propone:

1. Bajar la fricción de captura al mínimo posible usando voz, foto y texto informal.  
2. Estructurar esos inputs en tiempo (casi) real sin que el usuario llene formularios.  
3. Diseñar la entrega (dashboards, reportes) para que la realidad no se endulce en la cadena de mando.
