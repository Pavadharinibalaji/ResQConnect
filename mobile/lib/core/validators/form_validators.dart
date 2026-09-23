class FormValidators {
  FormValidators._();

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Must contain country code starting with + and at least 9 digits
    final phoneRegex = RegExp(r'^\+[1-9]\d{1,14}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Include country code (e.g. +15555555555)';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Verification code is required';
    }
    if (value.trim().length != 6 || int.tryParse(value.trim()) == null) {
      return 'Verification code must be 6 digits';
    }
    return null;
  }
}
