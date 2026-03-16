-- Vistas analíticas para Wasagro

-- 1. Vista que une eventos con el clima más cercano en espacio y tiempo

CREATE OR REPLACE VIEW event_with_weather AS
SELECT
    e.id_event,
    e.id_field,
    e.id_farm,
    e.event_time,
    e.event_type,
    e.status,
    f.name          AS field_name,
    f.centroid      AS field_centroid,
    w.id_weather,
    w.ts_utc        AS weather_ts_utc,
    w.temp_c,
    w.rel_humidity,
    w.rain_mm,
    w.wind_speed_ms,
    w.wind_dir_deg,
    w.solar_radiation,
    w.pressure_hpa,
    w.source        AS weather_source
FROM events e
JOIN fields f
  ON e.id_field = f.id_field
LEFT JOIN LATERAL (
    SELECT w.*
    FROM weather_hourly w
    WHERE w.ts_utc BETWEEN e.event_time - INTERVAL '1 hour'
                      AND e.event_time + INTERVAL '1 hour'
    ORDER BY
      ST_Distance(w.location, f.centroid) ASC,
      ABS(EXTRACT(EPOCH FROM (w.ts_utc - e.event_time))) ASC
    LIMIT 1
) AS w ON TRUE;

-- 2. Ejemplo de vista de integridad de datos por finca y rango (simplificada)

CREATE OR REPLACE VIEW farm_data_integrity AS
SELECT
  f.id_farm,
  date_trunc('day', e.event_time) AS day,
  COUNT(DISTINCT e.id_field)::float / NULLIF(COUNT(DISTINCT fld.id_field), 0) AS coverage_ratio,
  AVG(EXTRACT(EPOCH FROM (e.ingested_at - e.event_time)) / 3600.0)           AS avg_reporting_delay_hours
FROM farms f
JOIN fields fld ON fld.id_farm = f.id_farm
LEFT JOIN events e
  ON e.id_field = fld.id_field
GROUP BY f.id_farm, date_trunc('day', e.event_time);
