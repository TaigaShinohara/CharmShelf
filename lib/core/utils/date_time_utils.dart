import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class DateTimeUtils {
  DateTimeUtils._();

  /// 例:
  /// - たった今 / just now
  /// - 3分前 / 3 minutes ago
  /// - 昨日 14:30 / Yesterday 14:30
  static String formatRelative(
    BuildContext context,
    DateTime dateTime, {
    DateTime? now,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final current = now ?? DateTime.now();
    final diff = current.difference(dateTime);

    // 未来日付は「たった今」扱い（通知・並び替え等でズレるケースの安全策）
    if (diff.isNegative) return l10n.relativeJustNow;

    if (diff.inMinutes < 1) return l10n.relativeJustNow;
    if (diff.inHours < 1) return l10n.relativeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.relativeHoursAgo(diff.inHours);

    final startOfToday = DateTime(current.year, current.month, current.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    // 開始境界を含む比較（!isBefore = isAfter || isAtSameMomentAs）
    if (!dateTime.isBefore(startOfYesterday) &&
        dateTime.isBefore(startOfToday)) {
      return l10n.relativeYesterdayAt(formatTime(context, dateTime));
    }

    if (diff.inDays < 7) return l10n.relativeDaysAgo(diff.inDays);

    return formatDate(context, dateTime);
  }

  /// 例: 2026年1月17日 14:30 / Jan 17, 2026, 14:30
  static String formatDateTime(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_Hm().format(dateTime);
  }

  /// コンパクトな日時表記
  /// 例: 今年の場合: 8/20 14:30、過去年の場合: 2025/8/20 14:30
  static String formatCompactDate(
    BuildContext context,
    DateTime dateTime, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (dateTime.year == current.year) {
      return DateFormat('M/d HH:mm').format(dateTime);
    }
    return DateFormat('yyyy/M/d HH:mm').format(dateTime);
  }

  /// 例: 2026年1月17日 / Jan 17, 2026
  static String formatDate(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).format(dateTime);
  }

  /// 例: 14:30
  static String formatTime(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Hm(locale).format(dateTime);
  }

  /// 日付ピッカーのラッパー（テーマ/ダークモードに合わせて表示）
  static Future<DateTime?> showAppDatePicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendarOnly,
  }) {
    final locale = Localizations.localeOf(context);
    return showDatePicker(
      context: context,
      locale: locale,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: initialEntryMode,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return Theme(data: Theme.of(context), child: child);
      },
    );
  }
}
