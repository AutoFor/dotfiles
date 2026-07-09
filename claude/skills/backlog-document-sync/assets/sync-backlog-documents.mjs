#!/usr/bin/env node
// Syncs Markdown files under __DOCS_DIR__/ to Backlog Documents.
// Git is the source of truth. The Backlog Document API has no update endpoint,
// so an "update" is implemented as delete-then-recreate, matched by title
// (the file's first `# heading`, falling back to the filename).

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const DOCS_DIR = process.env.BACKLOG_DOCS_DIR || '__DOCS_DIR__';

const SPACE_HOST = requireEnv('BACKLOG_SPACE_HOST');
const API_KEY = requireEnv('BACKLOG_API_KEY');
const PROJECT_ID = requireEnv('BACKLOG_PROJECT_ID');

const eventName = process.env.GITHUB_EVENT_NAME || 'workflow_dispatch';
const beforeSha = process.env.GITHUB_EVENT_BEFORE || '';
const afterSha = process.env.GITHUB_SHA || 'HEAD';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(1);
  }
  return value;
}

function git(args) {
  return execFileSync('git', args, { encoding: 'utf8' }).trim();
}

function isZeroSha(sha) {
  return !sha || /^0+$/.test(sha);
}

function listAllMarkdownFiles() {
  if (!existsSync(DOCS_DIR)) return [];
  const out = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const full = path.join(dir, entry);
      if (statSync(full).isDirectory()) walk(full);
      else if (entry.endsWith('.md')) out.push(full);
    }
  };
  walk(DOCS_DIR);
  return out;
}

// Manual full sync (workflow_dispatch), or the first-ever push with no prior
// commit to diff against: treat every file as an upsert, nothing as deleted.
function getChangedFiles() {
  if (eventName !== 'push' || isZeroSha(beforeSha)) {
    return { upserted: listAllMarkdownFiles(), deleted: [] };
  }

  const diff = git(['diff', '--no-renames', '--name-status', beforeSha, afterSha, '--', DOCS_DIR]);
  const upserted = [];
  const deleted = [];
  for (const line of diff.split('\n').filter(Boolean)) {
    const [status, file] = line.split('\t');
    if (!file.endsWith('.md')) continue;
    if (status === 'D') deleted.push(file);
    else upserted.push(file);
  }
  return { upserted, deleted };
}

function extractTitleAndBody(raw, fallbackTitle) {
  const lines = raw.split('\n');
  const headingIndex = lines.findIndex((l) => l.trim().startsWith('# '));
  if (headingIndex === -1) return { title: fallbackTitle, body: raw };
  const title = lines[headingIndex].trim().replace(/^#\s+/, '');
  const body = lines.slice(headingIndex + 1).join('\n').replace(/^\n+/, '');
  return { title, body };
}

function getTitleForDeletedFile(filePath) {
  const raw = git(['show', `${beforeSha}:${filePath}`]);
  const { title } = extractTitleAndBody(raw, path.basename(filePath, '.md'));
  return title;
}

async function backlogFetch(method, endpoint, { query, form } = {}) {
  const url = new URL(`https://${SPACE_HOST}/api/v2/${endpoint}`);
  url.searchParams.set('apiKey', API_KEY);
  for (const [k, v] of Object.entries(query || {})) url.searchParams.set(k, v);

  const init = { method };
  if (form) init.body = new URLSearchParams(form);

  const res = await fetch(url, init);
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Backlog API ${method} ${endpoint} failed (${res.status}): ${text}`);
  }
  return text ? JSON.parse(text) : null;
}

async function fetchTitleToIdMap() {
  // documents/tree only lists documents that were explicitly added to the sidebar tree,
  // so a freshly-created document (never added to the tree) would be invisible to it and
  // get recreated as a duplicate on the next sync. The flat list endpoint has no such gap.
  // Unlike most Backlog endpoints, this one requires `projectIdOrKey`, not `projectId`.
  const documents = await backlogFetch('GET', 'documents', { query: { projectIdOrKey: PROJECT_ID } });
  return new Map(documents.map((doc) => [doc.title, doc.id]));
}

async function upsertDocument(filePath, titleMap) {
  const raw = readFileSync(filePath, 'utf8');
  const { title, body } = extractTitleAndBody(raw, path.basename(filePath, '.md'));

  const existingId = titleMap.get(title);
  if (existingId) {
    console.log(`update: "${title}" (delete ${existingId} -> recreate)`);
    await backlogFetch('DELETE', `documents/${existingId}`);
  } else {
    console.log(`create: "${title}"`);
  }

  // Document creation itself takes `projectId` in the form body (not projectIdOrKey).
  const created = await backlogFetch('POST', 'documents', {
    form: { projectId: PROJECT_ID, title, content: body },
  });
  titleMap.set(title, created.id);
}

async function deleteDocument(filePath, titleMap) {
  const title = getTitleForDeletedFile(filePath);
  const id = titleMap.get(title);
  if (!id) {
    console.log(`skip delete: no document found for "${title}"`);
    return;
  }
  console.log(`delete: "${title}" (${id})`);
  await backlogFetch('DELETE', `documents/${id}`);
  titleMap.delete(title);
}

async function main() {
  const { upserted, deleted } = getChangedFiles();
  if (upserted.length === 0 && deleted.length === 0) {
    console.log(`No changes under ${DOCS_DIR}/`);
    return;
  }

  const titleMap = await fetchTitleToIdMap();

  // Deletions first, so a rename (delete old title + create new title) can't collide.
  for (const file of deleted) {
    await deleteDocument(file, titleMap);
  }
  for (const file of upserted) {
    if (!existsSync(file)) continue; // guard: file removed again after the diff was computed
    await upsertDocument(file, titleMap);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
