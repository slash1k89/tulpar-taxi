-- Candidate list for manual verification against OSM/Nominatim.
-- Rows without a verified address and coordinates are never inserted.
CREATE TEMP TABLE esil_place_candidates (
  name text, category text, address text,
  latitude double precision, longitude double precision, aliases text[]
);

INSERT INTO esil_place_candidates VALUES
  ('Железнодорожный вокзал Есиль', 'вокзал', '', NULL, NULL,
    ARRAY['вокзал', 'жд вокзал', 'ж/д вокзал', 'железнодорожный вокзал', 'станция']),
  ('Отдел полиции', 'полиция', '', NULL, NULL,
    ARRAY['полиция', 'отдел полиции', 'ровд']),
  ('Районная больница', 'больница', '', NULL, NULL,
    ARRAY['больница', 'црб', 'районная больница']),
  ('Поликлиника', 'поликлиника', '', NULL, NULL,
    ARRAY['поликлиника', 'больница']),
  ('Акимат', 'акимат', '', NULL, NULL, ARRAY['акимат', 'администрация']),
  ('Рынок', 'рынок', '', NULL, NULL, ARRAY['рынок', 'базар']),
  ('Автовокзал', 'автовокзал', '', NULL, NULL, ARRAY['автовокзал', 'автостанция']),
  ('Школа', 'школа', '', NULL, NULL, ARRAY['школа']);

-- Fill verified values above, then run. Approximate coordinates are forbidden.
INSERT INTO public.tulpar_places
  (name, category, address, latitude, longitude, aliases)
SELECT name, category, address, latitude, longitude, aliases
FROM esil_place_candidates
WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND address <> '';

SELECT name AS requires_manual_verification
FROM esil_place_candidates
WHERE latitude IS NULL OR longitude IS NULL OR address = '';
