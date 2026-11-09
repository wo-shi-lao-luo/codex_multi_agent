/** Composite identities preserve component boundaries even when callers use punctuation in IDs. */
/** Encode ordered string components unambiguously; persisted old encodings require migration. */
export function compositeId(...parts) {
  return JSON.stringify(parts);
}
