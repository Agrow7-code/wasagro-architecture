-- Esquema de clima horario para Wasagro
-- Depende de PostGIS (ver 01-schema-core.sql para EXTENSION)

CREATE TABLE weather_hourly (
  id_weather      BIGSERIAL PRIMARY KEY,
  grid_id         INT,
  location        GEOGRAPHY(POINT, 4326),
  ts_utc          TIMESTAMPTZ NOT NULL,
  temp_c          NUMERIC,
  feels_like_c    NUMERIC,
  rel_humidity    NUMERIC,
  wind_speed_ms   NUMERIC,
  wind_dir_deg    NUMERIC,
  rain_mm         NUMERIC,
  solar_radiation NUMERIC,
  pressure_hpa    NUMERIC,
  source          VARCHAR(50),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_weather_time
  ON weather_hourly (ts_utc);

CREATE INDEX idx_weather_location_gist
  ON weather_hourly
  USING GIST (location);
