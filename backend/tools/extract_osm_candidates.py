"""Export real OSM streets and numbered addresses inside a city bounding box.

Usage: python extract_osm_candidates.py INPUT.osm.pbf CITY SOUTH WEST NORTH EAST
Requires pyosmium. Output is JSON Lines; it never invents coordinates or houses.
"""

import json
import sys
import unicodedata

import osmium


path, city, south, west, north, east = sys.argv[1:7]
south, west, north, east = map(float, (south, west, north, east))


def inside(lat, lon):
    return south <= lat <= north and west <= lon <= east


def clean(value):
    return unicodedata.normalize('NFC', value.strip()) if value else ''


class Nodes(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.locations = {}
        self.addresses = []

    def node(self, node):
        if not node.location.valid():
            return
        lat, lon = node.location.lat, node.location.lon
        if not inside(lat, lon):
            return
        self.locations[node.id] = (lat, lon)
        house = clean(node.tags.get('addr:housenumber'))
        street = clean(node.tags.get('addr:street'))
        if house and street:
            self.addresses.append({
                'kind': 'address', 'city': city, 'name': street,
                'house': house, 'lat': lat, 'lng': lon,
                'osm_type': 'node', 'osm_id': node.id,
            })


class Ways(osmium.SimpleHandler):
    def __init__(self, locations):
        super().__init__()
        self.locations = locations
        self.streets = {}
        self.addresses = []

    def way(self, way):
        coords = [self.locations[ref.ref] for ref in way.nodes
                  if ref.ref in self.locations]
        if not coords:
            return
        lat = sum(point[0] for point in coords) / len(coords)
        lon = sum(point[1] for point in coords) / len(coords)
        house = clean(way.tags.get('addr:housenumber'))
        addr_street = clean(way.tags.get('addr:street'))
        if house and addr_street:
            self.addresses.append({
                'kind': 'address', 'city': city, 'name': addr_street,
                'house': house, 'lat': lat, 'lng': lon,
                'osm_type': 'way', 'osm_id': way.id,
            })
        name = clean(way.tags.get('name'))
        if not name or not way.tags.get('highway'):
            return
        key = name.casefold()
        aliases = list({clean(way.tags.get(tag)) for tag in ('name:ru', 'name:kk')}
                       - {'', name})
        if key not in self.streets:
            self.streets[key] = {
                'kind': 'street', 'city': city, 'name': name,
                'aliases': aliases, 'lat': lat, 'lng': lon,
                'osm_type': 'way', 'osm_id': way.id,
            }


nodes = Nodes()
nodes.apply_file(path)
ways = Ways(nodes.locations)
ways.apply_file(path)
for item in ways.streets.values():
    print(json.dumps(item, ensure_ascii=False))
for item in nodes.addresses + ways.addresses:
    print(json.dumps(item, ensure_ascii=False))
