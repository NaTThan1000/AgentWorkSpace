import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..');
const contractNames = [
  'analysis-request',
  'context-brief',
  'evidence-packet',
  'expert-assembly-receipt',
  'analysis-report',
  'decision-packet',
  'experiment-plan'
];

function readJson(filePath) {
  const bytes = fs.readFileSync(filePath);
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    throw new Error(`${filePath}: UTF-8 BOM is not allowed`);
  }
  try {
    return JSON.parse(bytes.toString('utf8'));
  } catch (error) {
    throw new Error(`${filePath}: invalid JSON: ${error.message}`);
  }
}

function valueType(value) {
  if (Array.isArray(value)) return 'array';
  if (value === null) return 'null';
  if (Number.isInteger(value)) return 'integer';
  return typeof value === 'object' ? 'object' : typeof value;
}

function resolveRef(rootSchema, reference) {
  if (!reference.startsWith('#/')) throw new Error(`Only local schema refs are supported: ${reference}`);
  return reference.slice(2).split('/').reduce((value, token) => {
    const decoded = token.replaceAll('~1', '/').replaceAll('~0', '~');
    if (!value || !Object.hasOwn(value, decoded)) throw new Error(`Unresolved schema ref: ${reference}`);
    return value[decoded];
  }, rootSchema);
}

function validateSchema(value, schema, rootSchema, location = '$', errors = []) {
  if (schema.$ref) return validateSchema(value, resolveRef(rootSchema, schema.$ref), rootSchema, location, errors);

  if (Object.hasOwn(schema, 'const') && JSON.stringify(value) !== JSON.stringify(schema.const)) {
    errors.push(`${location}: const must equal ${JSON.stringify(schema.const)}`);
    return errors;
  }
  if (schema.enum && !schema.enum.some((item) => JSON.stringify(item) === JSON.stringify(value))) {
    errors.push(`${location}: enum rejected ${JSON.stringify(value)}`);
    return errors;
  }

  if (schema.type) {
    const actual = valueType(value);
    const matches = schema.type === actual || (schema.type === 'number' && actual === 'integer');
    if (!matches) {
      errors.push(`${location}: expected type ${schema.type}, received ${actual}`);
      return errors;
    }
  }

  if (schema.type === 'object') {
    for (const requiredName of schema.required ?? []) {
      if (!Object.hasOwn(value, requiredName)) errors.push(`${location}: missing required property ${requiredName}`);
    }
    const declared = schema.properties ?? {};
    for (const [name, child] of Object.entries(value)) {
      if (Object.hasOwn(declared, name)) {
        validateSchema(child, declared[name], rootSchema, `${location}.${name}`, errors);
      } else if (schema.additionalProperties === false) {
        errors.push(`${location}: additional property ${name} is not allowed`);
      }
    }
  }

  if (schema.type === 'array') {
    if (schema.minItems !== undefined && value.length < schema.minItems) errors.push(`${location}: minItems ${schema.minItems}`);
    if (schema.maxItems !== undefined && value.length > schema.maxItems) errors.push(`${location}: maxItems ${schema.maxItems}`);
    if (schema.uniqueItems) {
      const serialized = value.map((item) => JSON.stringify(item));
      if (new Set(serialized).size !== serialized.length) errors.push(`${location}: uniqueItems violated`);
    }
    if (schema.items) value.forEach((item, index) => validateSchema(item, schema.items, rootSchema, `${location}[${index}]`, errors));
  }

  if (schema.type === 'string') {
    if (schema.minLength !== undefined && value.length < schema.minLength) errors.push(`${location}: minLength ${schema.minLength}`);
    if (schema.maxLength !== undefined && value.length > schema.maxLength) errors.push(`${location}: maxLength ${schema.maxLength}`);
    if (schema.pattern && !(new RegExp(schema.pattern).test(value))) errors.push(`${location}: pattern ${schema.pattern}`);
    if (schema.format === 'date-time') {
      const rfc3339 = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;
      if (!rfc3339.test(value) || Number.isNaN(Date.parse(value))) errors.push(`${location}: invalid date-time`);
    }
  }

  if (schema.type === 'integer' || schema.type === 'number') {
    if (schema.minimum !== undefined && value < schema.minimum) errors.push(`${location}: minimum ${schema.minimum}`);
    if (schema.maximum !== undefined && value > schema.maximum) errors.push(`${location}: maximum ${schema.maximum}`);
  }
  return errors;
}

function validateSemantics(contractName, document, errors) {
  const lifecycle = document.lifecycle;
  if (lifecycle?.scope === 'host_reference_required' && !lifecycle.host_target_ref) {
    errors.push('$.lifecycle: host_reference_required requires host_target_ref');
  }

  if (contractName === 'analysis-request') {
    if (document.requested_endpoint === 'decision_packet' && !document.decision_question) {
      errors.push('$.decision_question: decision_packet requests require a real decision question');
    }
  }

  if (contractName === 'evidence-packet') {
    if (document.status === 'complete' && document.items?.length === 0) errors.push('$.items: complete evidence requires at least one item');
    if (document.status === 'unavailable' && document.items?.length > 0) errors.push('$.items: unavailable evidence must not claim items');
    const ids = (document.items ?? []).map((item) => item.evidence_id);
    if (new Set(ids).size !== ids.length) errors.push('$.items: evidence_id values must be unique');
  }

  if (contractName === 'expert-assembly-receipt') {
    const count = document.selections?.length ?? 0;
    if (document.status === 'not_requested' && (document.mode !== 'none' || count !== 0)) {
      errors.push('$.mode: not_requested requires none mode and no selections');
    }
    if (['assembled', 'degraded'].includes(document.status) && (document.mode === 'none' || count === 0)) {
      errors.push('$.selections: assembled requires expert selections and a non-none mode');
    }
    if (document.status === 'unavailable' && (document.mode !== 'none' || count !== 0)) {
      errors.push('$.mode: unavailable requires none mode and no selections');
    }
  }

  if (contractName === 'analysis-report') {
    if (document.status === 'complete' && (document.findings?.length ?? 0) === 0) {
      errors.push('$.findings: complete analysis requires at least one finding');
    }
    const ids = (document.findings ?? []).map((finding) => finding.finding_id);
    if (new Set(ids).size !== ids.length) errors.push('$.findings: finding_id values must be unique');
    for (const [index, finding] of (document.findings ?? []).entries()) {
      if (finding.classification === 'supported' && (finding.evidence_refs?.length ?? 0) === 0) {
        errors.push(`$.findings[${index}].evidence_refs: supported finding requires evidence`);
      }
    }
  }

  if (contractName === 'decision-packet') {
    const optionIds = (document.options ?? []).map((option) => option.option_id);
    if (new Set(optionIds).size !== optionIds.length) errors.push('$.options: option_id values must be unique');
    if (document.recommendation && !optionIds.includes(document.recommendation.option_id)) {
      errors.push('$.recommendation.option_id: must reference an option in this packet');
    }
    const criterionIds = (document.criteria ?? []).map((criterion) => criterion.criterion_id);
    if (new Set(criterionIds).size !== criterionIds.length) errors.push('$.criteria: criterion_id values must be unique');
  }

  if (contractName === 'experiment-plan') {
    const variantIds = (document.variants ?? []).map((variant) => variant.variant_id);
    if (new Set(variantIds).size !== variantIds.length) errors.push('$.variants: variant_id values must be unique');
    const metricIds = (document.metrics ?? []).map((metric) => metric.metric_id);
    if (new Set(metricIds).size !== metricIds.length) errors.push('$.metrics: metric_id values must be unique');
  }
  return errors;
}

function validateDocument(contractName, schema, document) {
  const errors = validateSchema(document, schema, schema);
  // Semantic checks assume the shape guaranteed by the schema. Preserve useful
  // validation errors for malformed input instead of throwing on map/entries.
  if (errors.length) return errors;
  return validateSemantics(contractName, document, errors);
}

function assertClosedObjectSchemas(schema, location = '$') {
  if (!schema || typeof schema !== 'object' || Array.isArray(schema)) return;
  if (schema.type === 'object' && schema.additionalProperties !== false) {
    throw new Error(`${location}: object schema must set additionalProperties=false`);
  }
  for (const [name, child] of Object.entries(schema.properties ?? {})) assertClosedObjectSchemas(child, `${location}.properties.${name}`);
  for (const [name, child] of Object.entries(schema.$defs ?? {})) assertClosedObjectSchemas(child, `${location}.$defs.${name}`);
  if (schema.items) assertClosedObjectSchemas(schema.items, `${location}.items`);
}

function setPath(target, dottedPath, value) {
  const tokens = dottedPath.split('.');
  let current = target;
  for (const token of tokens.slice(0, -1)) {
    const key = /^\d+$/.test(token) ? Number(token) : token;
    if (current[key] === undefined) throw new Error(`Mutation path does not exist: ${dottedPath}`);
    current = current[key];
  }
  const finalToken = tokens.at(-1);
  current[/^\d+$/.test(finalToken) ? Number(finalToken) : finalToken] = value;
}

function runSuite() {
  let validCount = 0;
  for (const contractName of contractNames) {
    const schemaPath = path.join(repositoryRoot, 'contracts', `${contractName}.schema.json`);
    const examplePath = path.join(repositoryRoot, 'examples', 'contracts', 'valid', `${contractName}.json`);
    const schema = readJson(schemaPath);
    if (schema.$schema !== 'https://json-schema.org/draft/2020-12/schema') throw new Error(`${contractName}: unsupported schema draft`);
    assertClosedObjectSchemas(schema);
    const errors = validateDocument(contractName, schema, readJson(examplePath));
    if (errors.length) throw new Error(`${contractName} valid example failed:\n${errors.join('\n')}`);
    validCount += 1;
  }

  const invalidPath = path.join(repositoryRoot, 'examples', 'contracts', 'invalid', 'cases.json');
  const invalidSuite = readJson(invalidPath);
  if (invalidSuite.schema_version !== 1 || !Array.isArray(invalidSuite.cases)) throw new Error('Invalid fixture suite contract failed');
  let invalidCount = 0;
  for (const testCase of invalidSuite.cases) {
    if (!contractNames.includes(testCase.schema)) throw new Error(`${testCase.id}: unknown schema ${testCase.schema}`);
    if (testCase.mutation?.operation !== 'set') throw new Error(`${testCase.id}: unsupported mutation`);
    const schema = readJson(path.join(repositoryRoot, 'contracts', `${testCase.schema}.schema.json`));
    const basePath = path.resolve(path.dirname(invalidPath), testCase.base_document);
    const document = structuredClone(readJson(basePath));
    setPath(document, testCase.mutation.path, testCase.mutation.value);
    const errors = validateDocument(testCase.schema, schema, document);
    if (errors.length === 0) throw new Error(`${testCase.id}: invalid example was accepted`);
    if (!errors.some((error) => error.includes(testCase.expected_error))) {
      throw new Error(`${testCase.id}: expected ${JSON.stringify(testCase.expected_error)}, received:\n${errors.join('\n')}`);
    }
    invalidCount += 1;
  }
  process.stdout.write(`AD-001 contract suite: PASS (${validCount} valid, ${invalidCount} invalid)\n`);
}

const isMainModule = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMainModule) {
  const args = process.argv.slice(2);
  if (args.includes('--suite')) {
    runSuite();
  } else {
    const schemaIndex = args.indexOf('--schema');
    const documentIndex = args.indexOf('--document');
    if (schemaIndex < 0 || documentIndex < 0 || !args[schemaIndex + 1] || !args[documentIndex + 1]) {
      throw new Error('Usage: validate-contracts.mjs --suite | --schema <schema> --document <json>');
    }
    const schemaPath = path.resolve(args[schemaIndex + 1]);
    const documentPath = path.resolve(args[documentIndex + 1]);
    const fileName = path.basename(schemaPath, '.schema.json');
    if (!contractNames.includes(fileName)) throw new Error(`Unknown contract schema: ${fileName}`);
    const errors = validateDocument(fileName, readJson(schemaPath), readJson(documentPath));
    if (errors.length) {
      process.stderr.write(`${errors.join('\n')}\n`);
      process.exitCode = 2;
    } else {
      process.stdout.write(`${fileName}: PASS\n`);
    }
  }
}

export { assertClosedObjectSchemas, readJson, validateDocument, validateSchema };
