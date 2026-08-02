import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const sources = [
  'docs/COMMERCIAL_MODEL_BACKLOG.md',
  'docs/LEAGUE_MANAGEMENT_BACKLOG.md',
  'docs/ios/IOS_BACKLOG.md',
];
const master = fs.readFileSync(path.join(root, 'docs/ROOBIN_MASTER_BACKLOG.md'), 'utf8');

function idsBetween(start, end) {
  const section = master.slice(master.indexOf(start), master.indexOf(end));
  return new Set([...section.matchAll(/`((?:COM|LM|IOS)-\d{3})`/g)].map((m) => m[1]));
}

const finesRequired = idsBetween('## Track A — Complete RooBin Fines Team subscription', '## Track B — Complete RooBin League commercial subscription');
const leagueCommercial = idsBetween('## Track B — Complete RooBin League commercial subscription', '## Track C — Full League Management product');
const optional = idsBetween('## Explicitly optional commercial experiments', '## Cross-track critical dependencies');

const dependencies = {
  'COM-011': ['COM-010'], 'COM-013': ['COM-010'], 'COM-014': ['COM-010', 'COM-011'],
  'COM-015': ['COM-012', 'COM-013', 'COM-014'],
  'COM-020': ['COM-001', 'COM-004', 'COM-010', 'COM-011', 'COM-025'],
  'COM-021': ['COM-020'], 'COM-022': ['COM-020', 'COM-021'],
  'COM-027': ['COM-021', 'COM-025', 'COM-026'], 'COM-028': ['COM-027'],
  'COM-029': ['COM-021', 'COM-022'],
  'COM-039': ['COM-021', 'COM-022', 'COM-027', 'COM-028', 'COM-029'],
  'COM-041': ['COM-010', 'COM-011', 'COM-040'],
  'COM-030': ['COM-001', 'COM-025', 'LM-003'], 'COM-031': ['COM-030', 'COM-021'],
  'COM-034': ['COM-031', 'LM-003'], 'COM-035': ['COM-010', 'COM-031', 'LM-003', 'LM-007'],
  'COM-036': ['COM-035'], 'LM-003': ['LM-001', 'LM-002'],
  'LM-007': ['LM-003', 'LM-006'], 'LM-008': ['LM-003', 'LM-007'],
  'LM-010': ['LM-001', 'LM-004', 'LM-008'], 'LM-011': ['LM-010'],
  'LM-012': ['LM-011'], 'LM-013': ['LM-012'], 'LM-014': ['LM-011', 'LM-013'],
  'LM-015': ['LM-014'], 'LM-016': ['LM-015'], 'LM-023': ['LM-020', 'LM-022'],
  'LM-024': ['LM-023'], 'LM-031': ['LM-030'], 'LM-032': ['LM-023', 'LM-031'],
  'LM-033': ['LM-004', 'LM-030'], 'LM-040': ['LM-015', 'LM-030'],
  'LM-060': ['LM-001', 'LM-003', 'LM-004'], 'LM-061': ['LM-060', 'LM-086'],
  'LM-062': ['LM-061', 'LM-082', 'LM-083', 'LM-084', 'LM-086'],
};

function statusFor(id, body) {
  const note = body.match(/^Status:\s*([^\n]+)/mi)?.[1]?.trim().replace(/\.$/, '');
  if (id.startsWith('IOS-') && Number(id.slice(4)) <= 12) return ['Complete', 'Foundation completion recorded in docs/ios/README.md'];
  if (/\bcomplete\b/i.test(note ?? '')) return ['Complete', note];
  if (/\bin progress\b/i.test(note ?? '')) return ['In Progress', note];
  return ['Draft', note || 'No completion evidence recorded'];
}

function productFor(id) {
  if (id.startsWith('LM-')) return 'League Management';
  if (leagueCommercial.has(id)) return 'Shared Commercial';
  return 'RooBin Fines';
}

function surfacesFor(id, title) {
  if (id.startsWith('IOS-')) return 'iOS';
  const text = title.toLowerCase();
  const values = new Set(['Platform-wide']);
  if (/website|public|web |checkout|pricing|support|status/.test(text)) values.add('Web');
  if (/ios|native|purchas/.test(text)) values.add('iOS');
  if (/android/.test(text)) values.add('Android');
  return [...values].join(' + ');
}

function releaseFor(id) {
  if (finesRequired.has(id)) return 'Paid Fines';
  if (leagueCommercial.has(id)) return 'League Lite';
  if (id === 'COM-042' || optional.has(id)) return 'Later';
  if (id.startsWith('IOS-')) return Number(id.slice(4)) >= 90 ? 'Later' : 'Fines MVP';
  const n = Number(id.slice(3));
  if (n < 30 || (n >= 50 && n <= 52)) return 'League Lite';
  if (n >= 60 && n < 70) return 'Replacement / Multi-sport';
  return 'Complete League';
}

const stories = [];
for (const relative of sources) {
  const text = fs.readFileSync(path.join(root, relative), 'utf8');
  const matches = [...text.matchAll(/^#### ((?:COM|LM|IOS)-\d{3}) — (.+)$/gm)];
  matches.forEach((match, index) => {
    const body = text.slice(match.index, matches[index + 1]?.index ?? text.length);
    const [status, evidence] = statusFor(match[1], body);
    stories.push({ id: match[1], title: match[2].trim(), product: productFor(match[1]),
      surfaces: surfacesFor(match[1], match[2]), status, release: releaseFor(match[1]),
      criticality: optional.has(match[1]) || match[1] === 'COM-042' ? 'Optional' : 'Required',
      dependencies: dependencies[match[1]] ?? [], evidence, source: relative });
  });
}

const order = { 'In Progress': 0, Ready: 1, Draft: 2, Complete: 3 };
stories.sort((a, b) => a.product.localeCompare(b.product) || order[a.status] - order[b.status] || a.id.localeCompare(b.id));
const esc = (v) => String(v).replaceAll('|', '\\|').replaceAll('\n', ' ');
const rows = stories.map((s) => `| ${s.id} | ${esc(s.title)} | ${s.product} | ${s.surfaces} | ${s.status} | ${s.release} | ${s.criticality} | ${s.dependencies.join(', ') || '—'} | [criteria](./${s.source.replace(/^docs\//, '')}#${s.id.toLowerCase()}) | ${esc(s.evidence)} |`);
const summary = (field) => Object.entries(stories.reduce((a, s) => ((a[s[field]] = (a[s[field]] ?? 0) + 1), a), {})).sort().map(([k, v]) => `| ${k} | ${v} |`).join('\n');
const statuses = ['Complete', 'In Progress', 'Ready', 'Draft'];
const statusSummary = statuses.map((status) => `| ${status} | ${stories.filter((s) => s.status === status).length} |`).join('\n');
const surfaces = ['iOS', 'Android', 'Web', 'Platform-wide'];
const surfaceSummary = surfaces.map((surface) => `| ${surface} | ${stories.filter((s) => s.surfaces.includes(surface)).length} |`).join('\n');
const paidFines = stories.filter((s) => s.release === 'Paid Fines' && s.criticality === 'Required');
const paidFinesSummary = statuses.map((status) => `| ${status} | ${paidFines.filter((s) => s.status === status).length} |`).join('\n');

const output = `# RooBin Story Register

Status: generated delivery view  
Generated: ${new Date().toISOString().slice(0, 10)}  
Source: \`npm run backlog:build\`

This register provides consistent delivery metadata across RooBin Fines and
League Management. Story titles and acceptance criteria remain authoritative in
their linked detailed backlogs. Do not edit this file directly.

## Status rules

- **Draft** — acceptance criteria or dependencies may change, or no verified delivery evidence is recorded.
- **Ready** — approved, dependency-clear and available to start. Ready is never inferred by the generator.
- **In Progress** — implementation is explicitly recorded as underway.
- **Complete** — completion evidence is explicitly recorded. Nearby code alone is not enough.

## Product summary

| Product | Stories |
|---|---:|
${summary('product')}

## Status summary

| Status | Stories |
|---|---:|
${statusSummary}

## Surface summary

Surface counts overlap by design.

| Surface | Stories |
|---|---:|
${surfaceSummary}

## Paid Fines critical path

These are the required commercial stories that gate the paid RooBin Fines
release. Their explicit story dependencies appear in the full register.

| Status | Stories |
|---|---:|
${paidFinesSummary}

Delivery order: commercial administration → public/support presence →
entitlements and controlled trial → checkout and subscription lifecycle →
approved native purchase route.

## Register conventions

- Surface is multi-valued; platform-wide covers backend, data, security and operations.
- Dependencies contain agreed hard story predecessors only. A blank does not prove independence.
- Owner, blocking decision, target date and evidence links belong in the detailed story before Ready or Complete.

## All stories

| ID | Story | Product | Surface | Status | Release | Criticality | Dependencies | Acceptance criteria | Evidence/status note |
|---|---|---|---|---|---|---|---|---|---|
${rows.join('\n')}
`;

fs.writeFileSync(path.join(root, 'docs/BACKLOG_REGISTER.md'), output);
console.log(`Wrote docs/BACKLOG_REGISTER.md with ${stories.length} stories.`);
