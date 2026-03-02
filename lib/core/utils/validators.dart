class Validators {
  static bool isValidEmail(String value) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
  }

  static bool isStrongPassword(String value) {
    return value.length >= 6;
  }

  const Validators._();
}
