const EMAIL_REGEX = /^[\w.+-]+@[\w-]+\.[\w.-]+$/;
const PHONE_REGEX = /^\+?\d{7,15}$/;
const USERNAME_REGEX = /^[a-zA-Z0-9_]{3,20}$/;

export function isValidEmail(value: string): boolean {
  return EMAIL_REGEX.test(value.trim());
}

export function isValidPhoneNumber(value: string): boolean {
  return PHONE_REGEX.test(value.trim().replace(/[\s-]/g, ''));
}

export function isValidName(value: string): boolean {
  return value.trim().length >= 2;
}

export function isValidUsername(value: string): boolean {
  return USERNAME_REGEX.test(value.trim());
}

export function isValidPassword(value: string): boolean {
  return value.length >= 6;
}
