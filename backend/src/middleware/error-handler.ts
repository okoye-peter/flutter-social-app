import type { NextFunction, Request, Response } from 'express';
import multer from 'multer';
import { HttpError } from '../lib/http-error.js';

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof HttpError) {
    return res.status(err.statusCode).json({ error: err.message });
  }

  // Multer throws its own error class for upload problems (file too large,
  // wrong field name, etc.) rather than an HttpError — translate it instead
  // of letting it fall through as an opaque 500.
  if (err instanceof multer.MulterError) {
    const message = err.code === 'LIMIT_FILE_SIZE' ? 'File is too large' : err.message;
    return res.status(400).json({ error: message });
  }

  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
}
