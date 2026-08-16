#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const {contentHash, stableStringify} = require('./canonical');
const {initializeFirebase} = require('./firebase');
const {
  applyManifest,
  auditInventory,
  auditProfiles,
  auditRevocations,
  generateManifest,
  verifyManifest,
} = require('./operations');

const HELP = `Firebase production reconciliation/audit tool

Usage:
  node src/cli.js audit-profiles --project-id PROJECT [--output FILE]
  node src/cli.js audit-revocations --project-id PROJECT [--output FILE]
  node src/cli.js audit-inventory --project-id PROJECT [--output FILE]
  node src/cli.js audit --project-id PROJECT [--output FILE]
  node src/cli.js manifest --project-id PROJECT --output FILE
  node src/cli.js hash --manifest FILE
  node src/cli.js apply --project-id PROJECT --manifest FILE --apply --confirm-hash SHA256
  node src/cli.js verify --project-id PROJECT --manifest FILE [--output FILE]

All remote commands are read-only except apply. Credentials come only from
GOOGLE_APPLICATION_CREDENTIALS or Application Default Credentials (ADC).`;

const OPTION_NAMES = new Set(['project-id', 'output', 'manifest', 'confirm-hash']);

function parseArguments(argv) {
  const args = {command: argv[0], apply: false};
  for (let index = 1; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === '--apply') {
      args.apply = true;
      continue;
    }
    if (!token.startsWith('--')) throw new Error(`Unexpected argument: ${token}`);
    const name = token.slice(2);
    if (!OPTION_NAMES.has(name)) throw new Error(`Unknown option: --${name}`);
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) throw new Error(`--${name} requires a value.`);
    if (args[name] !== undefined) throw new Error(`--${name} was provided more than once.`);
    args[name] = value;
    index += 1;
  }
  return args;
}

function readManifest(file) {
  if (!file) throw new Error('--manifest is required.');
  return JSON.parse(fs.readFileSync(path.resolve(file), 'utf8'));
}

function writeResult(value, output) {
  const serialized = `${stableStringify(value, 2)}\n`;
  if (!output) {
    process.stdout.write(serialized);
    return;
  }
  const destination = path.resolve(output);
  const parent = path.dirname(destination);
  if (!fs.existsSync(parent)) throw new Error(`Output directory does not exist: ${parent}`);
  const temporary = `${destination}.tmp-${process.pid}`;
  fs.writeFileSync(temporary, serialized, {encoding: 'utf8', flag: 'wx', mode: 0o600});
  try {
    fs.renameSync(temporary, destination);
  } catch (error) {
    fs.rmSync(temporary, {force: true});
    throw error;
  }
}

function hasAuditFindings(result) {
  if (result.audit === 'auth_profiles') {
    return result.missingProfiles.length > 0 || result.profilesWithoutAuth.length > 0;
  }
  return Array.isArray(result.issues) && result.issues.length > 0;
}

async function withFirebase(args, operation) {
  const context = initializeFirebase(args['project-id']);
  try {
    return await operation(context);
  } finally {
    await context.close();
  }
}

async function main(argv) {
  const args = parseArguments(argv);
  if (!args.command || args.command === 'help' || args.command === '--help') {
    process.stdout.write(`${HELP}\n`);
    return;
  }
  if (args.command === 'hash') {
    if (args.apply || args.output || args['project-id'] || args['confirm-hash']) {
      throw new Error('hash accepts only --manifest.');
    }
    process.stdout.write(`${contentHash(readManifest(args.manifest))}\n`);
    return;
  }
  if (args.command === 'apply') {
    if (!args.apply) throw new Error('Refusing write: apply requires the literal --apply flag.');
    if (!args['confirm-hash']) throw new Error('Refusing write: --confirm-hash is required.');
    if (args.output) throw new Error('apply does not accept --output.');
    const manifest = readManifest(args.manifest);
    const actualHash = contentHash(manifest);
    if (args['confirm-hash'].toLowerCase() !== actualHash) {
      throw new Error('Refusing write: --confirm-hash does not match the exact manifest contents.');
    }
    const result = await withFirebase(args, (context) => applyManifest(
      context,
      manifest,
      (progress) => process.stdout.write(`${stableStringify({progress}, 0)}\n`),
    ));
    writeResult(result);
    if (!result.ok) process.exitCode = 2;
    return;
  }
  if (args.apply || args['confirm-hash']) {
    throw new Error('--apply and --confirm-hash are valid only for the apply command.');
  }
  if (args.command === 'verify') {
    const manifest = readManifest(args.manifest);
    const result = await withFirebase(args, (context) => verifyManifest(context, manifest));
    writeResult(result, args.output);
    if (!result.ok) process.exitCode = 2;
    return;
  }
  if (args.command === 'manifest') {
    if (args.manifest) throw new Error('manifest does not accept --manifest.');
    if (!args.output) throw new Error('manifest requires --output to avoid accidental terminal disclosure.');
    const result = await withFirebase(args, (context) => generateManifest(context));
    writeResult(result, args.output);
    process.stdout.write(`${stableStringify({manifestWritten: path.resolve(args.output), hash: contentHash(result)}, 0)}\n`);
    return;
  }

  const audits = {
    'audit-profiles': auditProfiles,
    'audit-revocations': auditRevocations,
    'audit-inventory': auditInventory,
  };
  if (audits[args.command]) {
    if (args.manifest) throw new Error(`${args.command} does not accept --manifest.`);
    const result = await withFirebase(args, (context) => audits[args.command](context));
    writeResult(result, args.output);
    if (hasAuditFindings(result)) process.exitCode = 2;
    return;
  }
  if (args.command === 'audit') {
    if (args.manifest) throw new Error('audit does not accept --manifest.');
    const result = await withFirebase(args, async (context) => ({
      projectId: context.projectId,
      results: await Promise.all([
        auditProfiles(context), auditRevocations(context), auditInventory(context),
      ]),
    }));
    writeResult(result, args.output);
    if (result.results.some(hasAuditFindings)) process.exitCode = 2;
    return;
  }
  throw new Error(`Unknown command: ${args.command}\n\n${HELP}`);
}

main(process.argv.slice(2)).catch((error) => {
  if (error && error.code) {
    process.stderr.write(`Operation failed safely (${String(error.code)}). No secrets were logged.\n`);
  } else {
    process.stderr.write(`ERROR: ${error instanceof Error ? error.message : 'Unknown failure.'}\n`);
  }
  process.exitCode = 1;
});
