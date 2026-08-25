import { z } from 'zod';

// Multipart form fields can't carry real arrays, so several endpoints send
// an array as a JSON-encoded string instead — this parses and validates it
// in one step instead of an unguarded JSON.parse(...) as string[] cast.
export function optionalJsonStringArray(label: string) {
  return z
    .string()
    .optional()
    .transform((raw, ctx) => {
      if (raw === undefined) return undefined;

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
