import 'package:flutter/material.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../../domain/models/media_item.dart';

extension MediaTierExt on MediaTier {
  /// ティアに対応する色を取得
  Color color(BuildContext context) {
    switch (this) {
      case MediaTier.s:
        return const Color(0xFFE57373);
      case MediaTier.a:
        return const Color(0xFFFFB74D);
      case MediaTier.b:
        return const Color(0xFF9575CD);
      case MediaTier.c:
        return const Color(0xFF64B5F6);
      case MediaTier.d:
        return const Color(0xFF81C784);
      case MediaTier.none:
        return const Color(0xFFB0BEC5);
    }
  }

  /// ティアに対応するラベルを取得 (多言語対応)
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case MediaTier.s:
        return 'S';
      case MediaTier.a:
        return 'A';
      case MediaTier.b:
        return 'B';
      case MediaTier.c:
        return 'C';
      case MediaTier.d:
        return 'D';
      case MediaTier.none:
        return l10n.tierNone;
    }
  }
}
