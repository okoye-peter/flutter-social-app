import { z } from 'zod';

// A string field that may be omitted entirely OR sent as an explicit
// `null` — e.g. a Dart/Flutter client whose JSON encoder includes a
// nullable field's key with value `null` rather than dropping the key.
// z.string().optional() alone rejects that null with a raw type-mismatch
// error instead of treating it the same as "not provided"; this collapses
// both to `undefined` so callers only ever see `string | undefined`.
export function optionalString() {
  return z
    .string()
    .optional()
    .nullable()
    .transform((value) => value ?? undefined);
}

// Multipart form fields can't carry real arrays, so several endpoints send
// an array as a JSON-encoded string instead — this parses and validates it
// in one step instead of an unguarded JSON.parse(...) as string[] cast.
export function optionalJsonStringArray(label: string) {
  return z
    .string()
    .optional()
    .nullable()
    .transform((raw, ctx) => {
      if (raw === undefined || raw === null) return undefined;

      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch {
        ctx.addIssue(`${label} must be valid JSON`);
        return z.NEVER;
      }

      const result = z.array(z.string()).safeParse(parsed);
      if (!result.success) {
        ctx.addIssue(`${label} must be an array of strings`);
        return z.NEVER;
      }
      return result.data;
    });
}
