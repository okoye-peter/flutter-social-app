import type { NextFunction, Request, Response } from 'express';
import type { ZodType } from 'zod';
import { HttpError } from '../lib/http-error.js';

interface ValidateOptions<T> {
  // Runs after the body schema succeeds — for the handful of checks that
  // depend on req.file, which a body-only zod schema can't see.
  withFile?: (req: Request, data: T) => void;
}

export function validate<T>(schema: ZodType<T>, options: ValidateOptions<T> = {}) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      throw new HttpError(400, result.error.issues[0]?.message ?? 'Invalid request');
    }
    req.body = result.data;
    options.withFile?.(req, result.data);
    next();
  };
}
