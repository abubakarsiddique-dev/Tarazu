import '../constants/app_strings.dart';

class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? requiredField(String? v) =>
      (v == null || v.trim().isEmpty) ? AppStrings.fieldRequired : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
    return _emailRe.hasMatch(v.trim()) ? null : AppStrings.emailInvalid;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
    return v.length < 6 ? AppStrings.passwordShort : null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
    return v == original ? null : AppStrings.passwordMismatch;
  }
}
