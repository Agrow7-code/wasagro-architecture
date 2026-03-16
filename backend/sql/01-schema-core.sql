-- Esquema core de datos para Wasagro
-- Motor sugerido: PostgreSQL 15+ con extensión PostGIS

CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Roles de usuario
CREATE TABLE roles (
  id_role      SERIAL PRIMARY KEY,
  name         VARCHAR(50) NOT NULL UNIQUE,
  description  VARCHAR(255)
);

-- 2. Fincas
CREATE TABLE farms (
  id_farm      SERIAL PRIMARY KEY,
  name         VARCHAR(255) NOT NULL,
  country      VARCHAR(100),
  region       VARCHAR(100),
  centroid     GEOGRAPHY(POINT, 4326),   -- lon/lat aproximado
  boundary     GEOGRAPHY(POLYGON, 4326), -- polígono de la finca (opcional)
  active       BOOLEAN DEFAULT TRUE
);

-- 3. Lotes / cuarteles
CREATE TABLE fields (
  id_field     SERIAL PRIMARY KEY,
  id_farm      INT NOT NULL REFERENCES farms(id_farm),
  name         VARCHAR(255) NOT NULL,
  area_ha      NUMERIC,
  crop_type    VARCHAR(100),
  centroid     GEOGRAPHY(POINT, 4326),
  boundary     GEOGRAPHY(POLYGON, 4326),
  status       VARCHAR(50)
);

-- 4. Usuarios
CREATE TABLE users (
  id_user      SERIAL PRIMARY KEY,
  full_name    VARCHAR(255) NOT NULL,
  phone_msisdn VARCHAR(30)  NOT NULL UNIQUE,
  id_role      INT          NOT NULL REFERENCES roles(id_role),
  id_farm      INT          NOT NULL REFERENCES farms(id_farm),
  active       BOOLEAN      DEFAULT TRUE
);

-- 5. Catálogo de insumos
CREATE TABLE inputs (
  id_input          SERIAL PRIMARY KEY,
  commercial_name   VARCHAR(255) NOT NULL,
  active_ingredient VARCHAR(255),
  formulation       VARCHAR(100),
  label_uri         VARCHAR(500),
  regulatory_notes  TEXT
);

-- 6. Mensajes crudos (WhatsApp / otros canales)
CREATE TABLE raw_messages (
  id_raw        BIGSERIAL PRIMARY KEY,
  source_channel VARCHAR(50) NOT NULL, -- 'whatsapp', 'app', 'button', ...
  external_id   VARCHAR(255),          -- message_id del proveedor
  id_user       INT REFERENCES users(id_user),
  direction     VARCHAR(20) NOT NULL,  -- 'inbound' / 'outbound'
  text_raw      TEXT,
  audio_uri     VARCHAR(500),
  image_uri     VARCHAR(500),
  metadata      JSONB,
  ingested_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Mensajes procesados (STT/OCR)
CREATE TABLE message_processed (
  id_raw           BIGINT PRIMARY KEY REFERENCES raw_messages(id_raw),
  text_stt         TEXT,
  text_ocr         TEXT,
  language         VARCHAR(10),
  processing_status VARCHAR(20) NOT NULL DEFAULT 'ok', -- 'ok','failed',...
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. Eventos operativos normalizados
CREATE TABLE events (
  id_event              BIGSERIAL PRIMARY KEY,
  id_user               INT NOT NULL REFERENCES users(id_user),
  id_farm               INT NOT NULL REFERENCES farms(id_farm),
  id_field              INT     REFERENCES fields(id_field), -- puede ser NULL si scope='farm'
  scope                 VARCHAR(20) NOT NULL DEFAULT 'field', -- 'farm' o 'field'
  event_type            VARCHAR(50) NOT NULL,                -- 'pest','input_application',...
  risk_level            VARCHAR(20),                         -- 'low','medium','high'
  status                VARCHAR(30) NOT NULL DEFAULT 'pending_review',
  event_time            TIMESTAMPTZ,                         -- hora del evento en campo
  source_time_confidence NUMERIC,                            -- 0–1
  raw_message_id        BIGINT REFERENCES raw_messages(id_raw),
  completeness_status   VARCHAR(30) NOT NULL DEFAULT 'pending', -- 'complete','needs_clarification'
  mandatory_missing     JSONB,                               -- lista de campos obligatorios faltantes
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at          TIMESTAMPTZ
);

-- 9. Payload flexible por evento (JSONB)
CREATE TABLE event_payloads (
  id_event  BIGINT PRIMARY KEY REFERENCES events(id_event) ON DELETE CASCADE,
  payload   JSONB NOT NULL
);

-- 10. Decisiones del router de complejidad
CREATE TABLE router_decisions (
  id_router_decision BIGSERIAL PRIMARY KEY,
  id_raw             BIGINT REFERENCES raw_messages(id_raw),
  id_event           BIGINT REFERENCES events(id_event),
  predicted_event_type VARCHAR(50),
  model_used         VARCHAR(100),
  need_rag           BOOLEAN,
  need_premium_model BOOLEAN,
  need_multiagent_review BOOLEAN,
  confidence         NUMERIC,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 11. Workspaces de razonamiento (PDR/SR)
CREATE TABLE workspaces (
  id_workspace BIGSERIAL PRIMARY KEY,
  id_event     BIGINT NOT NULL REFERENCES events(id_event) ON DELETE CASCADE,
  workspace_text TEXT NOT NULL,      -- resumen corto de razonamiento
  strategy       VARCHAR(20),        -- 'SR','PDR','single_pass'
  model_used     VARCHAR(100),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. Preferencias de usuario por finca (configuración de informes/panel)
CREATE TABLE user_preferences (
  id_preference     BIGSERIAL PRIMARY KEY,
  id_user           INT NOT NULL REFERENCES users(id_user),
  id_farm           INT NOT NULL REFERENCES farms(id_farm),
  focus             VARCHAR(20),   -- 'yield','quality','costs','health','mixed'
  time_horizon      VARCHAR(20),   -- 'day','week','month','all'
  detail_level      VARCHAR(20),   -- 'farm','field','both'
  report_frequency  VARCHAR(20),   -- 'daily','weekly','biweekly','alerts_only'
  delivery_channels VARCHAR(50),   -- 'whatsapp','web+whatsapp','pdf+whatsapp'
  status            VARCHAR(20) DEFAULT 'pending_review', -- 'pending_review','approved'
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 13. Reportes generados
CREATE TABLE reports (
  id_report   BIGSERIAL PRIMARY KEY,
  id_farm     INT NOT NULL REFERENCES farms(id_farm),
  from_date   DATE,
  to_date     DATE,
  type        VARCHAR(20),  -- 'weekly','monthly',...
  file_uri    VARCHAR(500),
  status      VARCHAR(20) DEFAULT 'draft', -- 'draft','approved','sent'
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_at TIMESTAMPTZ,
  sent_at     TIMESTAMPTZ
);

-- 14. Conversaciones de WhatsApp (estado de máquina de estados)
CREATE TABLE wa_conversations (
  phone_msisdn   VARCHAR(30) PRIMARY KEY,
  id_user        INT REFERENCES users(id_user),
  current_state  VARCHAR(100) NOT NULL, -- 'IDLE','ONBOARDING_Q1_FOCUS',...
  context        JSONB,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices útiles

CREATE INDEX idx_events_farm_time
  ON events (id_farm, event_time);

CREATE INDEX idx_events_field_time
  ON events (id_field, event_time);

CREATE INDEX idx_raw_messages_user_time
  ON raw_messages (id_user, ingested_at);

CREATE INDEX idx_fields_farm
  ON fields (id_farm);

CREATE INDEX idx_weather_location_gist
  ON weather_hourly
  USING GIST (location);
