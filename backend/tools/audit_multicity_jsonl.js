// Local data-quality smoke. Selects search examples from real imported OSM rows.
// Usage: node tools/audit_multicity_jsonl.js path/to/multicity-candidates.jsonl
import { readFileSync } from 'node:fs';
import { normalizeSearchText, wordPrefixMatches } from '../src/geocoding-candidates.js';

const source = process.argv[2];
if (!source) throw new Error('Provide extracted JSONL path');
const rows = readFileSync(source, 'utf8').trim().split('\n').map(JSON.parse);
const cities = [...new Set(rows.map((row) => row.citySlug))].sort();

function search(records, query) {
  const clean = normalizeSearchText(query);
  const house = /^(.+?)[,\s]+(\d[\p{L}\d/-]*)$/u.exec(clean);
  return records.filter((row) => house
    ? row.kind === 'address' && wordPrefixMatches(row.name, house[1]) &&
        normalizeSearchText(row.house).startsWith(house[2])
    : ['street', 'poi'].includes(row.kind) &&
        [row.name, ...(row.aliases ?? [])].some((value) => wordPrefixMatches(value, clean)));
}

const report = {};
for (const city of cities) {
  const records = rows.filter((row) => row.citySlug === city);
  const examples = [];
  const used = new Set();
  for (const kind of ['street', 'second-word', 'address', 'poi']) {
    const candidates = records.filter((row) => kind === 'second-word'
      ? row.kind === 'street' && normalizeSearchText(row.name).split(/[\s\-]+/u).length > 1
      : row.kind === kind);
    for (const row of candidates) {
      let prefix;
      if (kind === 'address') {
        prefix = `${row.name} ${[...normalizeSearchText(row.house)][0]}`;
      } else if (kind === 'second-word') {
        prefix = [...normalizeSearchText(row.name).split(/[\s\-]+/u)[1]].slice(0, 3).join('');
      } else {
        prefix = [...normalizeSearchText(row.name)].slice(0, 3).join('');
      }
      if ([...prefix].length < 2 || used.has(prefix)) continue;
      const matches = search(records, prefix);
      if (!matches.some((match) => match.osmType === row.osmType && match.osmId === row.osmId)) continue;
      used.add(prefix);
      examples.push({ kind, query: prefix, result: row.name, house: row.house ?? null,
        matchingResults: matches.length });
      break;
    }
  }
  report[city] = { records: records.length, examples };
}
console.log(JSON.stringify({ total: rows.length, cities: report }, null, 2));
if (Object.values(report).some((item) => item.examples.length < 4)) process.exitCode = 1;
