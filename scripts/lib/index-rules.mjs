// Rules a submission has to hold beyond schema shape: folder naming, the
// files allowed to live in a mod folder, and the download paths the launcher
// can actually install from.
//
// Rule ids are stable so a PR comment can point at one: MI1xx layout,
// MI2xx metadata, MI3xx distribution.

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { validate } from './jsonschema.mjs';

export const MAX_THUMB_BYTES = 2 * 1024 * 1024;
export const MAX_DESCRIPTION_BYTES = 64 * 1024;
export const ALLOWED_FILES = new Set(['meta.json', 'description.md', 'thumbnail.png', 'thumbnail.jpg']);

const MAGIC = {
  'thumbnail.png': [0x89, 0x50, 0x4e, 0x47],
  'thumbnail.jpg': [0xff, 0xd8, 0xff],
};

// Author@id. The author half keeps only characters that stay legible in a
// path, a branch name and a URL — spaces and punctuation get dropped by the
// submission helper rather than escaped forever after.
const FOLDER_RE = /^([A-Za-z0-9._-]{1,64})@([A-Za-z0-9_-]{1,64})$/;

// Hosts that hand back an installable archive rather than an HTML page.
const GOOD_DOWNLOAD = [
  /^https:\/\/github\.com\/[^/]+\/[^/]+\/releases\/latest\/download\/[^/]+\.zip$/,
  /^https:\/\/github\.com\/[^/]+\/[^/]+\/releases\/download\/[^/]+\/[^/]+\.zip$/,
  /^https:\/\/github\.com\/[^/]+\/[^/]+\/archive\/refs\/(heads|tags)\/[^/]+\.zip$/,
  // Personal indexes may host ready-to-install ZIPs directly in a public
  // GitHub repository. raw.githubusercontent.com returns the file bytes,
  // not an HTML page, so it is safe for the launcher's ZIP importer.
  /^https:\/\/raw\.githubusercontent\.com\/[^/]+\/[^/]+\/[^/]+\/.+\.zip$/,
  /^https:\/\/codeberg\.org\/[^/]+\/[^/]+\/archive\/[^/]+\.zip$/,
  /^https:\/\/gitlab\.com\/[^/]+\/[^/]+\/-\/archive\/[^/]+\/[^/]+\.zip$/,
];

export function loadSchema(repoRoot) {
  return JSON.parse(readFileSync(join(repoRoot, 'schema', 'mod.schema.json'), 'utf8'));
}

// Check one mods/<folder> directory. Returns { folder, meta, errors, warnings }.
export function checkModFolder(dir, folder, schema) {
  const errors = [];
  const warnings = [];
  const fail = (rule, msg) => errors.push(`${rule} ${folder}: ${msg}`);
  const warn = (rule, msg) => warnings.push(`${rule} ${folder}: ${msg}`);

  const folderMatch = FOLDER_RE.exec(folder);
  if (!folderMatch) {
    fail('MI101', 'folder must be named Author@modid using letters, digits, . _ and - only');
  }

  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    fail('MI102', 'is not a readable directory');
    return { folder, meta: null, errors, warnings };
  }

  for (const entry of entries) {
    if (entry.isDirectory()) {
      fail('MI103', `contains a subdirectory "${entry.name}"; an index entry is metadata only`);
    } else if (!ALLOWED_FILES.has(entry.name)) {
      fail('MI103', `contains "${entry.name}"; only ${[...ALLOWED_FILES].join(', ')} are allowed`);
    }
  }

  // --- description.md
  const names = new Set(entries.filter((e) => e.isFile()).map((e) => e.name));
  if (!names.has('description.md')) {
    fail('MI104', 'is missing description.md');
  } else {
    const body = readFileSync(join(dir, 'description.md'));
    if (body.byteLength === 0) fail('MI104', 'description.md is empty');
    if (body.byteLength > MAX_DESCRIPTION_BYTES) {
      fail('MI104', `description.md is ${body.byteLength} bytes; the cap is ${MAX_DESCRIPTION_BYTES}`);
    }
    if (/<script|javascript:/i.test(body.toString('utf8'))) {
      fail('MI105', 'description.md contains script markup; the site renders descriptions as markdown only');
    }
  }

  // --- thumbnail
  if (names.has('thumbnail.png') && names.has('thumbnail.jpg')) {
    fail('MI106', 'has two thumbnails; keep one');
  }
  for (const thumb of ['thumbnail.png', 'thumbnail.jpg']) {
    if (!names.has(thumb)) continue;
    const path = join(dir, thumb);
    const size = statSync(path).size;
    if (size > MAX_THUMB_BYTES) {
      fail('MI106', `${thumb} is ${(size / 1048576).toFixed(2)} MB; the cap is 2 MB`);
    }
    const head = readFileSync(path).subarray(0, 4);
    const want = MAGIC[thumb];
    if (!want.every((byte, i) => head[i] === byte)) {
      fail('MI106', `${thumb} is not actually ${thumb.endsWith('png') ? 'PNG' : 'JPEG'} data`);
    }
  }

  // --- meta.json
  if (!names.has('meta.json')) {
    fail('MI107', 'is missing meta.json');
    return { folder, meta: null, errors, warnings };
  }
  let meta;
  try {
    meta = JSON.parse(readFileSync(join(dir, 'meta.json'), 'utf8'));
  } catch (err) {
    fail('MI107', `meta.json is not valid JSON (${err.message})`);
    return { folder, meta: null, errors, warnings };
  }

  for (const message of validate(meta, schema)) {
    fail('MI201', `meta.json ${message}`);
  }

  if (folderMatch && meta.id && meta.id !== folderMatch[2]) {
    fail('MI202', `folder id "${folderMatch[2]}" does not match meta.json id "${meta.id}"`);
  }
  if (folderMatch && meta.author && slug(meta.author) !== slug(folderMatch[1])) {
    fail('MI202', `folder author "${folderMatch[1]}" does not match meta.json author "${meta.author}"`);
  }

  // --- distribution
  if (!meta.github && !meta.downloadURL) {
    fail('MI301', 'needs either "github": "owner/repo" or a direct "downloadURL"');
  }
  if (meta.github && meta.repo && !meta.repo.toLowerCase().includes(meta.github.toLowerCase())) {
    warn('MI302', `"repo" (${meta.repo}) does not point at "github" (${meta.github})`);
  }
  if (meta.downloadURL && !GOOD_DOWNLOAD.some((re) => re.test(meta.downloadURL))) {
    fail(
      'MI303',
      `downloadURL must resolve straight to a .zip (a release, archive, or raw GitHub file), not a page: ${meta.downloadURL}`,
    );
  }
  if (!meta.github && meta.automatic_version_check) {
    warn('MI304', 'automatic_version_check needs "github" to have anything to check');
  }
  if (meta.profile === 'total_conversion' && meta.affects_link === false) {
    warn('MI305', 'a total_conversion that claims affects_link:false is unusual — see the Link Compatibility guide');
  }
  if (!meta.summary) {
    warn('MI306', 'has no "summary"; the browse card falls back to the first line of description.md');
  }

  return { folder, meta, errors, warnings };
}

// Cross-entry rules: one id, one listing.
export function checkCollisions(results) {
  const errors = [];
  const byId = new Map();
  for (const { folder, meta } of results) {
    if (!meta?.id) continue;
    const key = meta.id.toLowerCase();
    if (byId.has(key)) {
      errors.push(`MI203 ${folder}: mod id "${meta.id}" is already listed by ${byId.get(key)}`);
    } else {
      byId.set(key, folder);
    }
  }
  return errors;
}

export function listModFolders(modsDir) {
  return readdirSync(modsDir, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();
}

const slug = (s) => String(s).toLowerCase().replace(/[^a-z0-9]/g, '');
