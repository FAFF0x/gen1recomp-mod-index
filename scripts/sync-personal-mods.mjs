#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SOURCE_REPO = process.env.MOD_SOURCE_REPO || 'FAFF0x/gen1recomp';
const SOURCE_REF = process.env.MOD_SOURCE_REF || 'main';
const AUTHOR = process.env.MOD_INDEX_AUTHOR || 'FAFF0x';
const token = process.env.GITHUB_TOKEN || '';
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const modsDir = join(repoRoot, 'mods');
const tempRoot = mkdtempSync(join(tmpdir(), 'gen1recomp-mod-sync-'));
const statePath = join(repoRoot, '.github', 'faff0x-source-state.json');
const forceSync = ['1', 'true', 'yes'].includes(String(process.env.FORCE_SYNC || '').toLowerCase());

const ZIP_RE = /^(.+)_v(\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?)\.zip$/i;
const VALID_CATEGORIES = new Set([
  'GAMEPLAY', 'CONTENT', 'BALANCE', 'ART', 'AUDIO', 'UI', 'QOL',
  'TRANSLATION', 'TOTAL_CONVERSION', 'LIBRARY', 'TOOL', 'OTHER',
]);

try {
  mkdirSync(modsDir, { recursive: true });
  const sourceCommit = await githubJson(
    `https://api.github.com/repos/${SOURCE_REPO}/commits/${encodeURIComponent(SOURCE_REF)}`,
  );
  const sourceSha = sourceCommit?.sha;
  if (typeof sourceSha !== 'string') throw new Error(`Could not resolve ${SOURCE_REPO}@${SOURCE_REF}`);
  const previousState = readJson(statePath);
  if (!forceSync && previousState?.commit === sourceSha) {
    console.log(`source unchanged at ${sourceSha}; nothing to sync`);
    process.exitCode = 0;
  } else {
  const files = await githubJson(
    `https://api.github.com/repos/${SOURCE_REPO}/contents?ref=${encodeURIComponent(SOURCE_REF)}`,
  );
  if (!Array.isArray(files)) throw new Error(`Could not list ${SOURCE_REPO}@${SOURCE_REF}`);

  const latestByFilenameId = new Map();
  for (const file of files) {
    if (file?.type !== 'file' || typeof file.name !== 'string') continue;
    const match = ZIP_RE.exec(file.name);
    if (!match || typeof file.download_url !== 'string') continue;
    const candidate = {
      filenameId: match[1],
      filenameVersion: match[2],
      name: file.name,
      downloadURL: file.download_url,
    };
    const previous = latestByFilenameId.get(candidate.filenameId.toLowerCase());
    if (!previous || compareSemver(candidate.filenameVersion, previous.filenameVersion) > 0) {
      latestByFilenameId.set(candidate.filenameId.toLowerCase(), candidate);
    }
  }

  if (latestByFilenameId.size === 0) throw new Error(`No versioned ZIP files found in ${SOURCE_REPO}`);

  const latestByManifestId = new Map();
  let failures = 0;
  for (const candidate of latestByFilenameId.values()) {
    try {
      const extracted = await inspectZip(candidate);
      const id = extracted.manifest.id;
      if (!isValidId(id)) {
        console.error(`Skipping ${candidate.name}: manifest id is missing or invalid`);
        continue;
      }
      const version = validVersion(extracted.manifest.version)
        ? extracted.manifest.version
        : candidate.filenameVersion;
      const row = { ...candidate, ...extracted, id, version };
      const previous = latestByManifestId.get(id.toLowerCase());
      if (!previous || compareSemver(row.version, previous.version) > 0) {
        latestByManifestId.set(id.toLowerCase(), row);
      }
    } catch (error) {
      failures += 1;
      console.error(`Skipping ${candidate.name}: ${error.message}`);
    }
  }

  let created = 0;
  let updated = 0;
  let unchanged = 0;

  for (const row of [...latestByManifestId.values()].sort((a, b) => a.id.localeCompare(b.id))) {
    const folder = `${AUTHOR}@${row.id}`;
    const dir = join(modsDir, folder);
    const metaPath = join(dir, 'meta.json');
    const descriptionPath = join(dir, 'description.md');
    const existing = readJson(metaPath);
    const meta = existing ? updateMeta(existing, row) : createMeta(row);
    const metaText = `${JSON.stringify(meta, null, 2)}\n`;
    const oldMetaText = existsSync(metaPath) ? readFileSync(metaPath, 'utf8') : null;

    mkdirSync(dir, { recursive: true });
    let changed = oldMetaText !== metaText;
    if (changed) writeFileSync(metaPath, metaText);

    if (!existsSync(descriptionPath)) {
      writeFileSync(descriptionPath, buildDescription(row));
      changed = true;
    }

    if (!existing) created += 1;
    else if (changed) updated += 1;
    else unchanged += 1;

    console.log(`${changed ? (existing ? 'updated' : 'created') : 'unchanged'} ${folder} -> ${row.version}`);
  }

  if (failures > 0) {
    throw new Error(`${failures} ZIP file(s) could not be synchronized; source state was not advanced`);
  }

  mkdirSync(dirname(statePath), { recursive: true });
  writeFileSync(statePath, `${JSON.stringify({
    source: SOURCE_REPO,
    ref: SOURCE_REF,
    commit: sourceSha,
  }, null, 2)}\n`);
  console.log(`sync complete: ${created} created, ${updated} updated, ${unchanged} unchanged`);
  }
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}

async function inspectZip(candidate) {
  const zipPath = join(tempRoot, candidate.name);
  const response = await fetch(candidate.downloadURL, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!response.ok) throw new Error(`download returned HTTP ${response.status}`);
  writeFileSync(zipPath, Buffer.from(await response.arrayBuffer()));

  const names = execFileSync('unzip', ['-Z1', zipPath], { encoding: 'utf8' })
    .split(/\r?\n/)
    .filter(Boolean);
  const manifestPath = chooseEntry(names, 'manifest.json');
  if (!manifestPath) throw new Error('manifest.json not found in ZIP');
  const manifestText = execFileSync('unzip', ['-p', zipPath, manifestPath], { encoding: 'utf8' });
  const manifest = JSON.parse(manifestText);

  const readmePath = chooseEntry(names, 'README.md');
  const readme = readmePath
    ? execFileSync('unzip', ['-p', zipPath, readmePath], { encoding: 'utf8' })
    : '';
  return { manifest, readme };
}

function chooseEntry(names, wanted) {
  const matches = names.filter((name) => basename(name).toLowerCase() === wanted.toLowerCase());
  if (matches.length === 0) return null;
  matches.sort((a, b) => a.split('/').length - b.split('/').length || a.localeCompare(b));
  return matches[0];
}

function updateMeta(existing, row) {
  const manifest = row.manifest;
  const next = {
    ...existing,
    id: row.id,
    version: row.version,
    downloadURL: row.downloadURL,
    automatic_version_check: false,
  };
  if ('api' in manifest) syncOptional(next, 'api', manifest.api);
  if ('game_version' in manifest) syncOptional(next, 'game_version', manifest.game_version);
  if ('profile' in manifest) syncOptional(next, 'profile', manifest.profile);
  if ('affects_link' in manifest) syncOptional(next, 'affects_link', manifest.affects_link);
  if ('permissions' in manifest) syncArray(next, 'permissions', manifest.permissions);
  if ('dependencies' in manifest) syncArray(next, 'dependencies', manifest.dependencies);
  if ('conflicts' in manifest) syncArray(next, 'conflicts', manifest.conflicts);
  if ('experimental' in manifest) syncOptional(next, 'experimental', manifest.experimental);
  return next;
}

function createMeta(row) {
  const manifest = row.manifest;
  const title = cleanText(manifest.name) || titleCase(row.id);
  const summary = truncate(
    cleanText(manifest.description) || firstUsefulLine(row.readme) || `${title} for Gen1Recomp.`,
    200,
  );
  const meta = {
    id: row.id,
    title,
    author: AUTHOR,
    summary,
    version: row.version,
    categories: inferCategories(manifest),
    repo: `https://github.com/${SOURCE_REPO}`,
    downloadURL: row.downloadURL,
    automatic_version_check: false,
  };
  syncOptional(meta, 'api', manifest.api);
  syncOptional(meta, 'game_version', manifest.game_version);
  syncOptional(meta, 'profile', manifest.profile || 'content');
  syncOptional(meta, 'affects_link', manifest.affects_link ?? false);
  syncArray(meta, 'permissions', manifest.permissions);
  syncArray(meta, 'dependencies', manifest.dependencies);
  syncArray(meta, 'conflicts', manifest.conflicts);
  syncOptional(meta, 'experimental', manifest.experimental);
  return meta;
}

function buildDescription(row) {
  const readme = String(row.readme || '').trim();
  if (readme) return `${readme}\n`;
  const title = cleanText(row.manifest.name) || titleCase(row.id);
  const summary = cleanText(row.manifest.description) || `${title} for Gen1Recomp.`;
  return `# ${title}\n\n${summary}\n\nDownload and install the ZIP through Gen1Recomp's MODS screen.\n`;
}

function inferCategories(manifest) {
  const dependencies = Array.isArray(manifest.dependencies) ? manifest.dependencies : [];
  if (dependencies.some((value) => String(value).split('@')[0] === 'quest_system')) {
    return ['CONTENT', 'GAMEPLAY'];
  }
  const raw = String(manifest.category || '').trim().toUpperCase().replace(/[ -]+/g, '_');
  const aliases = {
    QUALITY_OF_LIFE: 'QOL',
    QUEST: 'CONTENT',
    QUESTS: 'CONTENT',
    OVERHAUL: 'GAMEPLAY',
    TOTALCONVERSION: 'TOTAL_CONVERSION',
  };
  const category = aliases[raw] || raw;
  return [VALID_CATEGORIES.has(category) ? category : 'OTHER'];
}

function syncOptional(target, key, value) {
  if (value === undefined || value === null || value === '') delete target[key];
  else target[key] = value;
}

function syncArray(target, key, value) {
  if (Array.isArray(value) && value.length) target[key] = value;
  else delete target[key];
}

function readJson(path) {
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    throw new Error(`Cannot parse ${path}: ${error.message}`);
  }
}

async function githubJson(url) {
  const response = await fetch(url, {
    headers: {
      Accept: 'application/vnd.github+json',
      'User-Agent': 'gen1recomp-personal-index-sync',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!response.ok) throw new Error(`GitHub API returned HTTP ${response.status} for ${url}`);
  return response.json();
}

function compareSemver(a, b) {
  const pa = parseSemver(a);
  const pb = parseSemver(b);
  for (let i = 0; i < 3; i += 1) {
    if (pa[i] !== pb[i]) return pa[i] - pb[i];
  }
  if (pa[3] === pb[3]) return 0;
  if (!pa[3]) return 1;
  if (!pb[3]) return -1;
  return pa[3].localeCompare(pb[3], undefined, { numeric: true });
}

function parseSemver(value) {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:-([^+]+))?/.exec(String(value));
  if (!match) return [0, 0, 0, ''];
  return [Number(match[1]), Number(match[2]), Number(match[3]), match[4] || ''];
}

function validVersion(value) {
  return /^\d+\.\d+\.\d+(?:[-+].*)?$/.test(String(value || ''));
}

function isValidId(value) {
  return /^[A-Za-z0-9_-]{1,64}$/.test(String(value || ''));
}

function firstUsefulLine(markdown) {
  for (const raw of String(markdown || '').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || line.startsWith('!') || line.startsWith('>')) continue;
    return cleanText(line.replace(/[*_`[\]]/g, ''));
  }
  return '';
}

function cleanText(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function truncate(value, max) {
  const text = cleanText(value);
  return text.length <= max ? text : `${text.slice(0, max - 1).trimEnd()}…`;
}

function titleCase(id) {
  return String(id)
    .split(/[_-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}
