import 'dart:collection';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:budoux_dart/budoux.dart';
import 'package:flutter/material.dart';

import '../../../core/config/budoux_model.dart';

/// アプリ全体で使用するテキストウィジェット
///
/// [Text] の代わりに使用することで、以下の機能を提供します。
/// - **セマンティック改行**: BudouXを使用し、文節の区切り以外での改行を防ぎます。
/// - **括弧の結合**: `(注釈)` などの短い括弧内が改行で割れるのを防ぎます。
/// - **自動サイズ調整**: [maxLines] 指定時にフォントサイズを縮小して収めます。
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.minFontSize = 12,
    this.maxFontSize = double.infinity,
    this.stepGranularity = 1,
    this.presetFontSizes,
    this.group,
    this.wrapWords = true,
  }) : textSpan = null;

  const AppText.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.minFontSize = 12,
    this.maxFontSize = double.infinity,
    this.stepGranularity = 1,
    this.presetFontSizes,
    this.group,
    this.wrapWords = true,
  }) : data = null;

  final String? data;
  final TextSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  // AutoSizeText properties
  final double minFontSize;
  final double maxFontSize;
  final double stepGranularity;
  final List<double>? presetFontSizes;
  final AutoSizeGroup? group;
  final bool wrapWords;

  // BudouX parser & LRU Cache
  static final BudouX _budouX = BudouX(budouxModelJa);
  static final LinkedHashMap<String, String> _semanticLayoutCache =
      LinkedHashMap<String, String>();
  static const int _maxCacheEntries = 1000;
  static final RegExp _japaneseRegex = RegExp(
    r'[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uff9f\u4e00-\u9faf\u3400-\u4dbf]',
  );
  static final RegExp _bracketRegex = RegExp(
    r'([\(（\[「『][^\)）\]」』]{1,10}[\)）\]」』])',
  );

  @override
  Widget build(BuildContext context) {
    // maxLines が指定されていない、かつ AutoSizeText 固有のパラメータがデフォルト値の場合は
    // 標準の Text ウィジェットを使用する。これにより、LayoutBuilder と IntrinsicHeight/Width の
    // 競合（AlertDialog や ListTile などで発生）を回避できる。
    // また、AutoSizeText.rich は WidgetSpan をサポートしていないため、WidgetSpan が含まれる場合は
    // 常に標準の Text.rich を使用して Assertion Error (dimensions != null) を防ぐ。
    final hasWidgetSpan = textSpan != null && _containsWidgetSpan(textSpan!);
    final shouldUseAutoSize =
        !hasWidgetSpan &&
        (maxLines != null ||
            group != null ||
            presetFontSizes != null ||
            minFontSize != 12 ||
            maxFontSize != double.infinity ||
            stepGranularity != 1);

    if (data != null) {
      final processedData = wrapWords ? _applySemanticLayout(data!) : data!;
      if (!shouldUseAutoSize) {
        return Text(
          processedData,
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaleFactor != null
              ? TextScaler.linear(textScaleFactor!)
              : null,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
        );
      }

      return AutoSizeText(
        processedData,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        minFontSize: minFontSize,
        maxFontSize: maxFontSize,
        stepGranularity: stepGranularity,
        presetFontSizes: presetFontSizes,
        group: group,
        wrapWords: wrapWords,
      );
    } else {
      final processedSpan = wrapWords
          ? _applySemanticLayoutToSpan(textSpan!)
          : textSpan!;
      if (!shouldUseAutoSize) {
        return Text.rich(
          processedSpan,
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaleFactor != null
              ? TextScaler.linear(textScaleFactor!)
              : null,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
        );
      }

      return AutoSizeText.rich(
        processedSpan,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        minFontSize: minFontSize,
        maxFontSize: maxFontSize,
        stepGranularity: stepGranularity,
        presetFontSizes: presetFontSizes,
        group: group,
        wrapWords: wrapWords,
      );
    }
  }

  /// TextSpan にセマンティックレイアウトを再帰的に適用する
  TextSpan _applySemanticLayoutToSpan(TextSpan span) {
    return TextSpan(
      text: span.text != null ? _applySemanticLayout(span.text!) : null,
      children: span.children?.map((child) {
        if (child is TextSpan) {
          return _applySemanticLayoutToSpan(child);
        }
        return child;
      }).toList(),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  /// テキストにセマンティックレイアウト（文節区切り・括弧結合）を適用する
  String _applySemanticLayout(String text) {
    if (text.isEmpty || text.length <= 1) return text;

    // LRUキャッシュヒットの確認
    final cached = _semanticLayoutCache[text];
    if (cached != null) {
      _semanticLayoutCache.remove(text);
      _semanticLayoutCache[text] = cached;
      return cached;
    }

    // 日本語が含まれているか簡易チェック
    if (!_japaneseRegex.hasMatch(text)) {
      if (_semanticLayoutCache.length >= _maxCacheEntries) {
        _semanticLayoutCache.remove(_semanticLayoutCache.keys.first);
      }
      _semanticLayoutCache[text] = text;
      return text;
    }

    var processed = text;

    // 1. Bracket Glue (括弧内の結合)
    // 括弧内が短い場合(10文字以内など)、内部をWord Joinerで結合して改行を防ぐ
    // 対象: (), （）, [], 「」, 『』
    processed = processed.replaceAllMapped(_bracketRegex, (match) {
      final content = match.group(1)!;
      // 文字の間に Word Joiner (U+2060) を挿入
      return content.split('').join('\u2060');
    });

    // 2. BudouX (文節区切り)
    // 文節のリストを取得
    final chunks = _budouX.parse(processed);

    // 文節ごとの処理
    // 戦略: 文節内は改行禁止(Word Joinerで結合)、文節間は改行許可(Zero Width Space U+200B を挿入)
    // ただし、既にBracket GlueでU+2060が入っている部分は維持する
    final buffer = StringBuffer();
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final gluedChunk = chunk.split('').join('\u2060');
      buffer.write(gluedChunk);

      // 最後の文節以外には、文節区切りとして Zero Width Space (改行許容) を入れる
      if (i < chunks.length - 1) {
        buffer.write('\u200B');
      }
    }

    final result = buffer.toString();
    if (_semanticLayoutCache.length >= _maxCacheEntries) {
      _semanticLayoutCache.remove(_semanticLayoutCache.keys.first);
    }
    _semanticLayoutCache[text] = result;
    return result;
  }

  /// TextSpan 内に WidgetSpan が含まれているかを再帰的に判定する
  bool _containsWidgetSpan(InlineSpan span) {
    if (span is WidgetSpan) {
      return true;
    }
    if (span is TextSpan && span.children != null) {
      for (final child in span.children!) {
        if (_containsWidgetSpan(child)) {
          return true;
        }
      }
    }
    return false;
  }
}
