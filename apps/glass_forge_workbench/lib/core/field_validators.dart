import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FieldValidators {
  static String? emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email.';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (value.length > 100) {
      return 'Password must be at most 100 characters.';
    }
    return null;
  }

  static String? confirmPasswordValidator(
    String? value,
    TextEditingController passwordController,
  ) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? nameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name.';
    }
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(value)) {
      return 'Please enter a valid name.';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters.';
    }
    if (value.length > 30) {
      return 'Name must be at most 30 characters.';
    }
    return null;
  }

  static String? textValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter text.';
    }
    return null;
  }

  static String? numberValidator(
    String? value, {
    int? min,
    int? max,
  }) {
    if (value == null || value.isEmpty) {
      return 'Please enter a number.';
    }

    final number = int.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number.';
    }

    if (min != null && number < min) {
      return 'Number must be at least $min.';
    }

    if (max != null && number > max) {
      return 'Number must be at most $max.';
    }

    return null;
  }

  static String? dateValidator(String? value, {bool allowFutureDates = false}) {
    if (value == null || value.isEmpty) {
      return 'Please enter a date.';
    }

    final date = DateFormat('dd/MM/yyyy').tryParse(value);
    if (date == null) {
      return 'Please enter a valid date (dd/MM/yyyy).';
    }

    final now = DateTime.now();
    if (!allowFutureDates && date.isAfter(now)) {
      return 'Date must be in the past.';
    } else if (allowFutureDates && date.isBefore(now)) {
      return 'Date must be in the future.';
    }

    return null;
  }

  static String? timeValidator(String? value, DateTime? date) {
    if (value == null || value.isEmpty) {
      return 'Please enter a time';
    }

    final timeParts = value.split(':');
    if (timeParts.length != 2) {
      return 'Please enter a valid time in format HH:mm';
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return 'Please enter a valid time';
    }

    if (date != null) {
      final enteredDateTime =
          DateTime(date.year, date.month, date.day, hour, minute);
      final now = DateTime.now();
      if (enteredDateTime.isBefore(now)) {
        return 'Time must be greater than or equal to now';
      }
    }

    return null;
  }

  static String? emailOrPhoneValidatorSync(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email or phone number.';
    }

    if (value.contains('@')) {
      return emailValidator(value);
    } else {
      return phoneValidator(value);
    }
  }

  static String? phoneValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number.';
    }

    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Accept an optional leading + followed by 7-15 digits (E.164 friendly).
    final phonePattern = RegExp(r'^\+?\d{7,15}$');

    if (!phonePattern.hasMatch(cleaned)) {
      return 'Please enter a valid phone number.';
    }

    return null;
  }

  static String? dateOfBirthValidator(String? value, {int minAge = 13}) {
    if (value == null || value.isEmpty) {
      return 'Please select your date of birth.';
    }

    try {
      final date = DateTime.parse(value);
      final today = DateTime.now();

      if (date.isAfter(today)) {
        return 'Date of birth cannot be in the future.';
      }

      var age = today.year - date.year;
      if (today.month < date.month ||
          (today.month == date.month && today.day < date.day)) {
        age--;
      }

      if (age < minAge) {
        return 'You must be at least $minAge years old to join.';
      }

      if (age > 120) {
        return 'Please enter a valid date of birth.';
      }

      return null;
    } on FormatException {
      return 'Please enter a valid date.';
    }
  }

  static String? genderValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select your gender.';
    }
    return null;
  }

  static String? stateValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a state.';
    }
    return null;
  }

  static String? cityValidator(String? value, String? selectedState, [List<String>? availableCities]) {
    if (selectedState != null && (value == null || value.isEmpty)) {
      return 'Please select a city.';
    }
    if (value != null && value.isNotEmpty && availableCities != null && !availableCities.contains(value)) {
      return 'Please select a valid city from the list.';
    }
    return null;
  }

  static String? addressValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your address.';
    }
    if (value.length < 10) {
      return 'Address must be at least 10 characters.';
    }
    if (value.length > 200) {
      return 'Address must be at most 200 characters.';
    }
    return null;
  }

  static String? postalCodeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your postal code.';
    }

    final cleanedValue = value.replaceAll(RegExp(r'[\s\-]'), '');

    // Generic international postal/ZIP code: 3-10 alphanumeric characters.
    if (!RegExp(r'^[A-Za-z0-9]{3,10}$').hasMatch(cleanedValue)) {
      return 'Please enter a valid postal code.';
    }

    return null;
  }

  static String? validateCardNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Card number is required';
    }
    final cardNumber = value.replaceAll(' ', '');
    if (cardNumber.length < 13 || cardNumber.length > 19) {
      return 'Please enter a valid card number';
    }
    if (!RegExp(r'^\d+$').hasMatch(cardNumber)) {
      return 'Card number must contain only digits';
    }
    return null;
  }

  static String? validateExpiryDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Expiry date is required';
    }
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
      return 'Please enter expiry date in MM/YY format';
    }
    final parts = value.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null) {
      return 'Invalid expiry date';
    }
    if (month < 1 || month > 12) {
      return 'Invalid month';
    }

    // Expand the 2-digit year to a full year and check the card is not expired.
    final fullYear = 2000 + year;
    final now = DateTime.now();
    // Card expires at the end of its expiry month.
    final expiry = DateTime(fullYear, month + 1, 0, 23, 59, 59);
    if (expiry.isBefore(now)) {
      return 'Card has expired';
    }

    return null;
  }

  static String? validateCVV(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CVV is required';
    }
    if (value.length < 3 || value.length > 4) {
      return 'CVV must be 3 or 4 digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'CVV must contain only digits';
    }
    return null;
  }
}
