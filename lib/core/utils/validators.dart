import 'package:flutter/material.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class Validators {
  Validators._();

  static String? requiredText(BuildContext context, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return AppLocalizations.of(context)?.validationRequired ?? '必須項目です';
    }
    return null;
  }

  static String? minLength(BuildContext context, String? value, int min) {
    final v = value ?? '';
    if (v.length < min) {
      return AppLocalizations.of(context)?.validationMinLength(min) ??
          '$min文字以上で入力してください';
    }
    return null;
  }

  static String? maxLength(BuildContext context, String? value, int max) {
    final v = value ?? '';
    if (v.length > max) {
      return AppLocalizations.of(context)?.validationMaxLength(max) ??
          '$max文字以内で入力してください';
    }
    return null;
  }

  static String? email(BuildContext context, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!ok) {
      return AppLocalizations.of(context)?.validationInvalidEmail ??
          '有効なメールアドレスを入力してください';
    }
    return null;
  }

  static String? intRange(
    BuildContext context,
    String? value, {
    int? min,
    int? max,
  }) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final parsed = int.tryParse(v);
    if (parsed == null) {
      return AppLocalizations.of(context)?.validationInvalidNumber ??
          '数値を入力してください';
    }
    if (min != null && parsed < min) {
      return AppLocalizations.of(context)?.validationMinValueInt(min) ??
          '$min以上の数値を入力してください';
    }
    if (max != null && parsed > max) {
      return AppLocalizations.of(context)?.validationMaxValueInt(max) ??
          '$max以下の数値を入力してください';
    }
    return null;
  }

  static String? doubleRange(
    BuildContext context,
    String? value, {
    double? min,
    double? max,
  }) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final parsed = double.tryParse(v);
    if (parsed == null) {
      return AppLocalizations.of(context)?.validationInvalidNumber ??
          '数値を入力してください';
    }
    if (min != null && parsed < min) {
      return AppLocalizations.of(context)?.validationMinValueDouble(min) ??
          '$min以上の数値を入力してください';
    }
    if (max != null && parsed > max) {
      return AppLocalizations.of(context)?.validationMaxValueDouble(max) ??
          '$max以下の数値を入力してください';
    }
    return null;
  }
}
