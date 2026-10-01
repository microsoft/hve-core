// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

const MAX_ASSERTION_PATTERN_LENGTH = 512;
const MAX_ASSERTION_PATTERN_QUANTIFIERS = 16;

// Counts unescaped quantifiers, which are the operators that drive backtracking
// cost. Character classes are skipped because a quantifier inside a class is a
// literal.
function countNestedQuantifiers(pattern) {
  let count = 0;
  let inClass = false;
  for (let index = 0; index < pattern.length; index += 1) {
    const character = pattern[index];
    if (character === '\\') {
      index += 1;
      continue;
    }
    if (character === '[') {
      inClass = true;
      continue;
    }
    if (character === ']') {
      inClass = false;
      continue;
    }
    if (!inClass && (character === '*' || character === '+' || character === '{')) {
      count += 1;
    }
  }
  return count;
}

function normalizeText(value, options = {}) {
  if (value === null || value === undefined) {
    return '';
  }

  const text = typeof value === 'string' ? value : String(value);
  let normalized = text.normalize?.('NFC') || text;
  normalized = normalized.replace(/\r\n?/g, '\n');
  normalized = normalized.replace(/\u00a0/g, ' ');
  normalized = normalized.replace(/[ \t\f\v]+/g, ' ');
  normalized = normalized.replace(/\s*\n+\s*/g, ' ');

  const punctuationMode = options?.punctuationMode || 'preserve';
  if (punctuationMode === 'strip') {
    normalized = normalized.replace(/[^\p{L}\p{N}\s]/gu, '');
  } else if (punctuationMode === 'space') {
    normalized = normalized.replace(/[^\p{L}\p{N}\s]/gu, ' ');
  }

  normalized = normalized.replace(/\s+/g, ' ').trim();
  return normalized;
}

export function normalizeSpokenOutput(value, options = {}) {
  if (Array.isArray(value)) {
    const normalized = [];
    let previous = null;
    for (const phrase of value) {
      const normalizedPhrase = normalizeText(phrase, options);
      if (!options?.dedupeAdjacentPhrases || normalizedPhrase !== previous) {
        normalized.push(normalizedPhrase);
        previous = normalizedPhrase;
      }
    }
    return normalized;
  }

  return normalizeText(value, options);
}

function normalizeEvidencePayload(assertion, evidence, options = {}) {
  const evidenceType = assertion?.evidenceType || 'speech';
  if (Array.isArray(evidence)) {
    return { evidenceType, value: evidence };
  }

  if (evidence && typeof evidence === 'object') {
    if (evidenceType === 'speech') {
      const useNormalized = Boolean(options?.useNormalizedSpeech);
      if (useNormalized && Array.isArray(evidence.normalizedSpeech)) {
        return { evidenceType, value: evidence.normalizedSpeech };
      }
      if (Array.isArray(evidence.speech)) {
        return { evidenceType, value: evidence.speech };
      }
      if (Array.isArray(evidence.normalizedSpeech)) {
        return { evidenceType, value: evidence.normalizedSpeech };
      }
    }
    if (Array.isArray(evidence[evidenceType])) {
      return { evidenceType, value: evidence[evidenceType] };
    }
    if (evidenceType === 'browserState' && evidence.browserState !== undefined) {
      return { evidenceType, value: evidence.browserState };
    }
    if (evidenceType === 'accessibilityTree' && evidence.accessibilityTree !== undefined) {
      return { evidenceType, value: evidence.accessibilityTree };
    }
  }

  return { evidenceType, value: evidence };
}

function stringifyEvidenceValue(value) {
  if (Array.isArray(value)) {
    return value.map((item) => String(item ?? '')).join(' || ');
  }
  if (value === null || value === undefined) {
    return '';
  }
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return String(value);
}

function collectNodes(value, nodes = []) {
  if (!value || typeof value !== 'object') return nodes;
  const isAxValueWrapper = value.type !== undefined && value.value !== undefined;
  const isAxProperty = value.name !== undefined && value.value !== undefined && value.role === undefined;
  if (!Array.isArray(value) && !isAxValueWrapper && !isAxProperty && (value.role !== undefined || value.name !== undefined)) nodes.push(value);
  for (const child of Array.isArray(value) ? value : Object.values(value)) {
    if (child && typeof child === 'object') collectNodes(child, nodes);
  }
  return nodes;
}

function unwrapAxValue(value) {
  if (value && typeof value === 'object' && value.value !== undefined) {
    const valueType = String(value.type || '').toLowerCase();
    if ((valueType.includes('boolean') || valueType === 'tristate') && (value.value === 'true' || value.value === 'false')) {
      return value.value === 'true';
    }
    return value.value;
  }
  return value;
}

function readNodeValue(node, key) {
  if (node?.[key] !== undefined) {
    return unwrapAxValue(node[key]);
  }
  const property = Array.isArray(node?.properties)
    ? node.properties.find((entry) => entry?.name === key)
    : null;
  return unwrapAxValue(property?.value);
}

function nodeMatches(node, expected) {
  return Object.entries(expected).every(([key, expectedValue]) => {
    const actualValue = readNodeValue(node, key);
    if (key === 'nameContains') {
      return normalizeText(readNodeValue(node, 'name')).toLowerCase().includes(normalizeText(expectedValue).toLowerCase());
    }
    if (Array.isArray(expectedValue)) {
      return expectedValue.some((candidate) => String(candidate).toLowerCase() === String(actualValue).toLowerCase());
    }
    return typeof expectedValue === 'string'
      ? String(actualValue ?? '').toLowerCase() === expectedValue.toLowerCase()
      : actualValue === expectedValue;
  });
}

function evaluateNodeAssertion(assertion, evidenceType, value) {
  const expected = assertion.expected;
  if (!expected || typeof expected !== 'object' || Array.isArray(expected)) {
    return { status: 'invalid-config', detail: `${assertion.type} requires an expected object.`, evidenceType };
  }
  const matches = collectNodes(value).filter((node) => nodeMatches(node, expected));
  if (assertion.type === 'nodeAbsent') {
    return matches.length === 0
      ? { status: 'pass', detail: `nodeAbsent matched the ${evidenceType} evidence`, evidenceType }
      : { status: 'fail', detail: `nodeAbsent found ${matches.length} matching node(s)`, evidenceType };
  }
  const minimum = Number.isInteger(assertion.minCount) ? assertion.minCount : 1;
  const maximum = Number.isInteger(assertion.maxCount) ? assertion.maxCount : Number.POSITIVE_INFINITY;
  const maximumLabel = Number.isFinite(maximum) ? maximum : 'unbounded';
  return matches.length >= minimum && matches.length <= maximum
    ? { status: 'pass', detail: `nodeMatches found ${matches.length} matching node(s)`, evidenceType }
    : { status: 'fail', detail: `nodeMatches found ${matches.length}; expected ${minimum}-${maximumLabel}`, evidenceType };
}

export function evaluateAssertion(assertion, evidence = [], options = {}) {
  if (!assertion || typeof assertion !== 'object') {
    return { status: 'invalid-config', detail: 'Assertion must be an object.' };
  }

  const assertionOptions = assertion?.normalization || options || {};
  const { evidenceType, value } = normalizeEvidencePayload(assertion, evidence, assertionOptions);
  if (assertion.type === 'nodeMatches' || assertion.type === 'nodeAbsent') {
    return evaluateNodeAssertion(assertion, evidenceType, value);
  }
  const normalizedValue = normalizeText(String(assertion.value ?? '').trim(), assertionOptions);
  const phraseText = stringifyEvidenceValue(value);
  const normalizedPhraseText = normalizeText(phraseText, assertionOptions);
  const loweredText = normalizedPhraseText.toLowerCase();
  const loweredValue = normalizedValue.toLowerCase();

  if (!normalizedValue) {
    return { status: 'invalid-config', detail: 'Assertion value cannot be empty.', evidenceType };
  }

  if (assertion.type === 'contains') {
    return loweredText.includes(loweredValue)
      ? { status: 'pass', detail: `contains matched the ${evidenceType} evidence`, evidenceType }
      : { status: 'fail', detail: `contains did not match the ${evidenceType} evidence`, evidenceType };
  }

  if (assertion.type === 'notContains') {
    return !loweredText.includes(loweredValue)
      ? { status: 'pass', detail: `notContains matched the ${evidenceType} evidence`, evidenceType }
      : { status: 'fail', detail: `notContains found prohibited ${evidenceType} evidence`, evidenceType };
  }

  if (assertion.type === 'orderedContains') {
    const tokens = normalizedValue.split(/\s+/).filter(Boolean);
    if (tokens.length === 0) {
      return { status: 'invalid-config', detail: 'orderedContains requires at least one token.', evidenceType };
    }

    let cursor = 0;
    for (const token of tokens) {
      const index = loweredText.indexOf(token.toLowerCase(), cursor);
      if (index < 0) {
        return { status: 'fail', detail: `orderedContains tokens were not found in order for ${evidenceType}`, evidenceType };
      }
      cursor = index + token.length;
    }

    return { status: 'pass', detail: `orderedContains matched the ${evidenceType} evidence`, evidenceType };
  }

  if (assertion.type === 'matches') {
    // Config-supplied patterns are bounded before compilation. An unbounded
    // pattern with nested quantifiers can backtrack catastrophically against
    // captured speech and hang the run.
    if (normalizedValue.length > MAX_ASSERTION_PATTERN_LENGTH) {
      return {
        status: 'invalid-config',
        detail: `matches pattern exceeds ${MAX_ASSERTION_PATTERN_LENGTH} characters`,
        evidenceType,
      };
    }
    if (countNestedQuantifiers(normalizedValue) > MAX_ASSERTION_PATTERN_QUANTIFIERS) {
      return {
        status: 'invalid-config',
        detail:
          `matches pattern exceeds ${MAX_ASSERTION_PATTERN_QUANTIFIERS} quantifiers, `
          + 'which risks catastrophic backtracking',
        evidenceType,
      };
    }
    try {
      const matcher = new RegExp(normalizedValue, 'i');
      return matcher.test(normalizedPhraseText)
        ? { status: 'pass', detail: `matches matched the ${evidenceType} evidence`, evidenceType }
        : { status: 'fail', detail: `matches did not match the ${evidenceType} evidence`, evidenceType };
    } catch (error) {
      return {
        status: 'invalid-config',
        detail: `Invalid regular expression for matches: ${error instanceof Error ? error.message : String(error)}`,
        evidenceType,
      };
    }
  }

  return { status: 'invalid-config', detail: 'Unsupported assertion type.', evidenceType };
}
