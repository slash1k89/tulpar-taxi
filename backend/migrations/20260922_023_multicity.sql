BEGIN;

CREATE TABLE public.cities (
  id smallint PRIMARY KEY,
  slug text NOT NULL UNIQUE,
  name_ru text NOT NULL,
  name_kk text NOT NULL,
  name_en text NOT NULL,
  center_lat double precision NOT NULL CHECK (center_lat BETWEEN -90 AND 90),
  center_lng double precision NOT NULL CHECK (center_lng BETWEEN -180 AND 180),
  osm_boundary_type text NOT NULL CHECK (osm_boundary_type IN ('way', 'relation')),
  osm_boundary_id bigint NOT NULL,
  bbox_south double precision NOT NULL,
  bbox_west double precision NOT NULL,
  bbox_north double precision NOT NULL,
  bbox_east double precision NOT NULL,
  is_enabled boolean NOT NULL DEFAULT true,
  sort_order smallint NOT NULL,
  CONSTRAINT cities_bbox_valid CHECK (bbox_south < bbox_north AND bbox_west < bbox_east),
  CONSTRAINT cities_osm_boundary_unique UNIQUE (osm_boundary_type, osm_boundary_id)
);

-- Centers are OSM place nodes; bounds are verified city-place polygons from the
-- local copy of Kazakhstan PBF. Bounds are for client viewport, not a security boundary.
INSERT INTO public.cities (id, slug, name_ru, name_kk, name_en, center_lat, center_lng,
                           osm_boundary_type, osm_boundary_id, bbox_south, bbox_west,
                           bbox_north, bbox_east, sort_order) VALUES
  (1, 'esil', 'Есиль', 'Есіл', 'Esil', 51.9607263, 66.404878, 'way', 98652243, 51.9312838, 66.3575681, 51.9701032, 66.4717266, 1),
  (2, 'atbasar', 'Атбасар', 'Атбасар', 'Atbasar', 51.8097369, 68.3573356, 'way', 192334774, 51.7651318, 68.3030282, 51.8431278, 68.3833996, 2),
  (3, 'makinsk', 'Макинск', 'Макинск', 'Makinsk', 52.63287, 70.418213, 'way', 1526218479, 52.6090679, 70.3864002, 52.6594917, 70.4495448, 3),
  (4, 'ereymentau', 'Ерейментау', 'Ерейментау', 'Ereymentaw', 51.619881, 73.103348, 'way', 1467579226, 51.5946863, 73.0733523, 51.6390267, 73.1911978, 4),
  (5, 'rudny', 'Рудный', 'Рудный', 'Rudny', 52.964458, 63.133488, 'relation', 4469413, 52.9351723, 62.966529, 53.0856565, 63.2783059, 5),
  (6, 'lisakovsk', 'Лисаковск', 'Лисаковск', 'Lisakovsk', 52.545864, 62.489201, 'way', 58683168, 52.5207134, 62.4478187, 52.57808, 62.5816138, 6),
  (7, 'karkaralinsk', 'Каркаралинск', 'Қарқаралы', 'Qarqaraly', 49.4124087, 75.4704514, 'way', 42646713, 49.4000745, 75.4522265, 49.4294928, 75.5044719, 7),
  (8, 'shchuchinsk', 'Щучинск', 'Щучинск', 'Shchuchinsk', 52.9387457, 70.1857634, 'relation', 2592316, 52.9083282, 70.1326921, 52.9794398, 70.3022002, 8),
  (9, 'arkalyk', 'Аркалык', 'Арқалық', 'Arkalyk', 50.253281, 66.914993, 'way', 1526039267, 50.2290889, 66.8630719, 50.2880231, 66.963129, 9),
  (10, 'zhitikara', 'Житикара', 'Жітіқара', 'Jitiqara', 52.1905261, 61.2047527, 'way', 1527720426, 52.1719315, 61.1605024, 52.2084482, 61.2431573, 10),
  (11, 'shalkar', 'Шалкар', 'Шалқар', 'Şalqar', 47.8273018, 59.6159216, 'way', 39369590, 47.8017028, 59.5917017, 47.8561917, 59.6527745, 11),
  (12, 'aralsk', 'Аральск', 'Арал', 'Aral', 46.797985, 61.661221, 'way', 295767956, 46.7818563, 61.6261836, 46.833313, 61.7097953, 12),
  (13, 'ekibastuz', 'Экибастуз', 'Екібастұз', 'Ekibastuz', 51.7275817, 75.3288511, 'relation', 21073386, 51.6901329, 75.2707853, 51.7600127, 75.3642433, 13);

ALTER TABLE public.orders ADD COLUMN city_id smallint REFERENCES public.cities(id);
-- Historical city/delivery orders are Esil; intercity remains outside this model.
UPDATE public.orders SET city_id = 1
WHERE city_id IS NULL AND service_type IN ('city', 'delivery');
ALTER TABLE public.orders ADD CONSTRAINT orders_local_city_required
  CHECK ((service_type IN ('city', 'delivery') AND city_id IS NOT NULL)
         OR (service_type NOT IN ('city', 'delivery') AND city_id IS NULL));

-- Temporary compatibility for clients/backend versions that omit city_id.
-- Local orders were Esil-only before this migration; intercity stays NULL.
CREATE FUNCTION public.legacy_local_order_city() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.service_type IN ('city', 'delivery') AND NEW.city_id IS NULL THEN
    NEW.city_id := 1;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER orders_legacy_local_city
  BEFORE INSERT ON public.orders FOR EACH ROW
  EXECUTE FUNCTION public.legacy_local_order_city();

ALTER TABLE public.driver_profiles ADD COLUMN work_city_id smallint
  REFERENCES public.cities(id) DEFAULT 1 NOT NULL;

ALTER TABLE public.tulpar_places ADD COLUMN city_id smallint
  REFERENCES public.cities(id) DEFAULT 1 NOT NULL;

CREATE TABLE public.autocomplete_candidates (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  city_id smallint NOT NULL REFERENCES public.cities(id),
  kind text NOT NULL CHECK (kind IN ('street', 'address', 'poi')),
  name text NOT NULL,
  name_search text NOT NULL,
  house_number text,
  house_search text,
  category text,
  aliases text[] NOT NULL DEFAULT '{}',
  latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  osm_type text NOT NULL CHECK (osm_type IN ('node', 'way', 'relation')),
  osm_id bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT autocomplete_osm_identity UNIQUE (city_id, kind, osm_type, osm_id)
);

CREATE TABLE public.autocomplete_candidate_terms (
  candidate_id bigint NOT NULL REFERENCES public.autocomplete_candidates(id) ON DELETE CASCADE,
  city_id smallint NOT NULL REFERENCES public.cities(id),
  term text NOT NULL,
  source text NOT NULL CHECK (source IN ('name', 'alias')),
  PRIMARY KEY (candidate_id, term, source)
);

CREATE INDEX autocomplete_terms_city_prefix_idx
  ON public.autocomplete_candidate_terms (city_id, term text_pattern_ops, candidate_id);
CREATE INDEX autocomplete_candidates_city_kind_house_idx
  ON public.autocomplete_candidates (city_id, kind, house_search text_pattern_ops);
CREATE INDEX orders_local_search_city_idx
  ON public.orders (city_id, service_type, created_at DESC)
  WHERE status = 'searching' AND service_type IN ('city', 'delivery');
CREATE INDEX driver_profiles_work_city_idx
  ON public.driver_profiles (work_city_id) WHERE status = 'active';
CREATE INDEX tulpar_places_city_active_idx
  ON public.tulpar_places (city_id, active);

COMMIT;
