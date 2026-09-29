"""Extract verified street, address and named POI candidates from a local OSM PBF.

Usage: python extract_multicity_osm.py SOURCE.osm.pbf OUTPUT.jsonl
Requires pyosmium and shapely. Does not access PostgreSQL or production.
The selected OSM place polygons were verified against the Kazakhstan PBF.
"""

import json
import math
import sys
import unicodedata

import osmium
from shapely import wkt
from shapely.geometry import Point
from shapely.prepared import prep


# City-place geometries, not the much larger surrounding districts.
CITY_AREAS = {
    'esil': ('way', 98652243),
    'atbasar': ('way', 192334774),
    'makinsk': ('way', 1526218479),
    'ereymentau': ('way', 1467579226),
    'rudny': ('relation', 4469413),
    'lisakovsk': ('way', 58683168),
    'karkaralinsk': ('way', 42646713),
    'shchuchinsk': ('relation', 2592316),
    'arkalyk': ('way', 1526039267),
    'zhitikara': ('way', 1527720426),
    'shalkar': ('way', 39369590),
    'aralsk': ('way', 295767956),
    'ekibastuz': ('relation', 21073386),
}

POI_TAGS = ('amenity', 'shop', 'tourism', 'leisure', 'healthcare', 'office',
            'railway', 'station', 'public_transport')


def clean(value):
    return unicodedata.normalize('NFC', str(value or '').strip())


def aliases(tags, name):
    values = [clean(tags.get(key)) for key in ('name:ru', 'name:kk', 'name:en', 'alt_name')]
    return sorted({value for value in values if value and value != name})


def tags_for(obj):
    return {key: value for key, value in obj.tags}


class Boundaries(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.polygons = {}
        self.details = {}
        self.factory = osmium.geom.WKTFactory()

    def area(self, area):
        kind = 'way' if area.from_way() else 'relation'
        for slug, identity in CITY_AREAS.items():
            if identity != (kind, area.orig_id()):
                continue
            shape = wkt.loads(self.factory.create_multipolygon(area))
            self.polygons[slug] = shape
            tags = tags_for(area)
            self.details[slug] = {
                'osmType': kind,
                'osmId': area.orig_id(),
                'name': tags.get('name'),
                'bounds': list(shape.bounds),
            }


class CandidateExtractor(osmium.SimpleHandler):
    def __init__(self, polygons):
        super().__init__()
        self.polygons = {slug: prep(shape) for slug, shape in polygons.items()}
        self.bounds = {slug: shape.bounds for slug, shape in polygons.items()}
        self.rows = []
        self.seen = set()
        self.invalid_coordinates = {slug: 0 for slug in polygons}
        self.duplicates = {slug: 0 for slug in polygons}
        self.factory = osmium.geom.WKTFactory()

    def _city(self, lat, lng):
        if not math.isfinite(lat) or not math.isfinite(lng):
            return None
        point = Point(lng, lat)
        for slug, (west, south, east, north) in self.bounds.items():
            if west <= lng <= east and south <= lat <= north and self.polygons[slug].covers(point):
                return slug
        return None

    def _add(self, kind, osm_type, osm_id, lat, lng, tags):
        city = self._city(lat, lng)
        if city is None:
            return
        name = clean(tags.get('name'))
        street = clean(tags.get('addr:street'))
        house = clean(tags.get('addr:housenumber'))
        category = next((f'{key}:{tags[key]}' for key in POI_TAGS if tags.get(key)), '')
        candidates = []
        if street and house:
            candidates.append(('address', street, house, ''))
        if kind == 'way' and name and tags.get('highway'):
            candidates.append(('street', name, '', ''))
        if name and category:
            candidates.append(('poi', name, '', category))
        for result_type, title, number, category_value in candidates:
            # Keep one street candidate per city/name; retain distinct real OSM homes/POIs.
            key = (city, result_type, clean(title).casefold()) if result_type == 'street' else (city, result_type, osm_type, osm_id)
            if key in self.seen:
                self.duplicates[city] += 1
                continue
            self.seen.add(key)
            self.rows.append({
                'citySlug': city, 'kind': result_type, 'name': title,
                'house': number or None, 'category': category_value or None,
                'aliases': aliases(tags, title), 'lat': lat, 'lng': lng,
                'osmType': osm_type, 'osmId': osm_id,
            })

    def node(self, node):
        if not node.location.valid():
            return
        tags = tags_for(node)
        if tags.get('addr:housenumber') or tags.get('name'):
            self._add('node', 'node', node.id, node.location.lat, node.location.lon, tags)

    def way(self, way):
        tags = tags_for(way)
        if not (tags.get('addr:housenumber') or (tags.get('name') and
                (tags.get('highway') or any(tags.get(key) for key in POI_TAGS)))):
            return
        try:
            geometry = wkt.loads(self.factory.create_linestring(way))
            point = geometry.representative_point()
        except Exception:
            return
        self._add('way', 'way', way.id, point.y, point.x, tags)


def extract(source, output):
    boundaries = Boundaries()
    boundaries.apply_file(source, locations=True)
    missing = set(CITY_AREAS) - set(boundaries.polygons)
    if missing:
        raise RuntimeError(f'Missing verified OSM city polygons: {sorted(missing)}')
    extractor = CandidateExtractor(boundaries.polygons)
    extractor.apply_file(source, locations=True)
    extractor.rows.sort(key=lambda item: (item['citySlug'], item['kind'], item['name'], item['house'] or '', item['osmId']))
    with open(output, 'w', encoding='utf-8', newline='\n') as result:
        for row in extractor.rows:
            result.write(json.dumps(row, ensure_ascii=False, separators=(',', ':')) + '\n')
    counts = {slug: {kind: sum(row['citySlug'] == slug and row['kind'] == kind for row in extractor.rows)
                     for kind in ('street', 'address', 'poi')} for slug in CITY_AREAS}
    print(json.dumps({'cities': boundaries.details, 'counts': counts,
                      'duplicates': extractor.duplicates,
                      'invalidCoordinates': extractor.invalid_coordinates,
                      'total': len(extractor.rows)}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    extract(sys.argv[1], sys.argv[2])
