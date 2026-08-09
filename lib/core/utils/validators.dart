final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your name';
  if (value.trim().length < 2) return 'Name is too short';
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your email';
  if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter your password';
  if (value.length < 6) return 'Must be at least 6 characters';
  return null;
}
