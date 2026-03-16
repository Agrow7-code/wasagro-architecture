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
  id_raw            BIGINT PRIMARY KEY REFERENCES raw_messages(id_raw),
  text_stt          TEXT,
  text_stt_corrected TEXT,  -- transcript post-correción LLM (jerga agro)
  text_ocr          TEXT,
  language          VARCHAR(10),
  stt_model         VARCHAR(100),    -- 'whisper-self-hosted','voxtral',...
  stt_confidence    NUMERIC,         -- confianza del modelo STT (0–1)
  processing_status VARCHAR(20) NOT NULL DEFAULT 'ok', -- 'ok','failed','low_confidence'
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. Eventos operativos normalizados
CREATE TABLE events (
  id_event              BIGSERIAL PRIMARY KEY,
  id_user               INT NOT NULL REFERENCES users(id_user),
  id_farm               INT NOT NULL REFERENCES farms(id_farm),
  id_field              INT     REFERENCES fields(id_field),
  scope                 VARCHAR(20) NOT NULL DEFAULT 'field', -- 'farm' o 'field'
  event_type            VARCHAR(50) NOT NULL,
  risk_level            VARCHAR(20),
  status                VARCHAR(30) NOT NULL DEFAULT 'pending_review',
  event_time            TIMESTAMPTZ,
  source_time_confidence NUMERIC,
  raw_message_id        BIGINT REFERENCES raw_messages(id_raw),
  completeness_status   VARCHAR(30) NOT NULL DEFAULT 'pending',
  mandatory_missing     JSONB,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  ingested_at           TIMESTAMPTZ NOT NULL DEFAULT now(), -- tiempo de llegada al sistema
  confirmed_at          TIMESTAMPTZ,
  confirmed_by          INT REFERENCES users(id_user),
  -- Campos de escalamiento (loop humano activo)
  escalated_at          TIMESTAMPTZ,
  escalated_to          INT REFERENCES users(id_user),
  escalation_note       TEXT
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

-- 11. Workspaces de razonamiento (PDR/SR — Reflexion Agent)
CREATE TABLE workspaces (
  id_workspace   BIGSERIAL PRIMARY KEY,
  id_event       BIGINT NOT NULL REFERENCES events(id_event) ON DELETE CASCADE,
  workspace_json JSONB NOT NULL,   -- JSON parcial acumulado (workspace-as-memory)
  reflexion_note TEXT,             -- auto-crítica del agente
  strategy       VARCHAR(20),      -- 'single_shot','react_2step','reflexion_3step'
  model_used     VARCHAR(100),
  turn_number    INT DEFAULT 1,    -- turno de conversación multi-turn
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. Preferencias de usuario por finca
CREATE TABLE user_preferences (
  id_preference     BIGSERIAL PRIMARY KEY,
  id_user           INT NOT NULL REFERENCES users(id_user),
  id_farm           INT NOT NULL REFERENCES farms(id_farm),
  focus             VARCHAR(20),
  time_horizon      VARCHAR(20),
  detail_level      VARCHAR(20),
  report_frequency  VARCHAR(20),
  delivery_channels VARCHAR(50),
  status            VARCHAR(20) DEFAULT 'pending_review',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 13. Reportes generados
CREATE TABLE reports (
  id_report   BIGSERIAL PRIMARY KEY,
  id_farm     INT NOT NULL REFERENCES farms(id_farm),
  from_date   DATE,
  to_date     DATE,
  type        VARCHAR(20),
  file_uri    VARCHAR(500),
  status      VARCHAR(20) DEFAULT 'draft',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_at TIMESTAMPTZ,
  approved_by INT REFERENCES users(id_user),
  sent_at     TIMESTAMPTZ
);

-- 14. Conversaciones de WhatsApp
CREATE TABLE wa_conversations (
  phone_msisdn   VARCHAR(30) PRIMARY KEY,
  id_user        INT REFERENCES users(id_user),
  current_state  VARCHAR(100) NOT NULL,
  context        JSONB,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 15. Reglas de escalamiento por tipo de evento (loop humano activo)
CREATE TABLE escalation_rules (
  id_rule          SERIAL PRIMARY KEY,
  event_type       VARCHAR(50) NOT NULL,
  risk_level       VARCHAR(20),           -- 'low','medium','high','critical'
  max_hours        NUMERIC NOT NULL,       -- SLA máximo en horas
  escalate_to_role INT REFERENCES roles(id_role),
  action_on_breach VARCHAR(100),          -- 'auto_approve','alert_manager','block_recommendation'
  active           BOOLEAN DEFAULT TRUE
);

-- 16. Datos de evaluación de calidad IA (evals)
CREATE TABLE eval_dataset (
  id_eval          BIGSERIAL PRIMARY KEY,
  source_message   TEXT NOT NULL,         -- mensaje crudo original
  source_type      VARCHAR(20),           -- 'audio','text','image'
  expected_json    JSONB NOT NULL,        -- JSON esperado (anotado a mano)
  event_type       VARCHAR(50),
  annotated_by     INT REFERENCES users(id_user),
  annotated_at     TIMESTAMPTZ,
  notes            TEXT
);

-- 17. Resultados de evals por modelo/prompt
CREATE TABLE eval_results (
  id_result         BIGSERIAL PRIMARY KEY,
  id_eval           BIGINT NOT NULL REFERENCES eval_dataset(id_eval),
  model_version     VARCHAR(100),
  prompt_version    VARCHAR(50),
  produced_json     JSONB,
  field_accuracy    NUMERIC,              -- field-level accuracy 0–1
  fields_detail     JSONB,               -- detalle por campo: {"id_field": true, "dose": false, ...}
  evaluated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices principales

CREATE INDEX idx_events_farm_time
  ON events (id_farm, event_time);

CREATE INDEX idx_events_field_time
  ON events (id_field, event_time);

CREATE INDEX idx_events_escalation
  ON events (status, risk_level, created_at)
  WHERE escalated_at IS NULL;

CREATE INDEX idx_raw_messages_user_time
  ON raw_messages (id_user, ingested_at);

CREATE INDEX idx_fields_farm
  ON fields (id_farm);
