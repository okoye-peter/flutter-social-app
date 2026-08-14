import jwt from 'jsonwebtoken';

function requireSecret(): string {
  const value = process.env.JWT_SECRET;
  if (!value) {
    throw new Error('JWT_SECRET environment variable is required');
  }
  return value;
}

const secret = requireSecret();
const expiresIn = process.env.ACCESS_TOKEN_EXPIRES_IN ?? '6h';

export function signAccessToken(userId: string): string {
  return jwt.sign({ sub: userId }, secret, { expiresIn } as jwt.SignOptions);
}

export function verifyAccessToken(token: string): string {
  const payload = jwt.verify(token, secret) as jwt.JwtPayload;
  if (typeof payload.sub !== 'string') {
    throw new Error('Invalid token payload');
  }
  return payload.sub;
}
