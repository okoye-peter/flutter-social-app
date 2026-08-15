/// Masks a phone number for display, keeping the first 6 and last 2
/// characters visible and replacing the rest with asterisks, e.g.
/// "+2348012345678" -> "+23480******78".
String maskPhoneNumber(String phone) {
  final cleaned = phone.trim();
  if (cleaned.length <= 8) return cleaned;

  final start = cleaned.substring(0, 6);
  final end = cleaned.substring(cleaned.length - 2);
  final maskedLength = cleaned.length - 8;

  return '$start${'*' * maskedLength}$end';
}

/// Masks an email address for display, keeping the first 1-2 characters
/// of the local part visible, e.g. "johndoe@gmail.com" -> "jo***@gmail.com".
String maskEmail(String email) {
  final trimmed = email.trim();
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return trimmed;

  final local = trimmed.substring(0, atIndex);
  final domain = trimmed.substring(atIndex);
  final visible = local.length <= 2
      ? local.substring(0, 1)
      : local.substring(0, 2);

  return '$visible***$domain';
}
