import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';

/// Type scale and markdown styling for the chat surfaces.
///
/// Every markdown element gets an explicit size here. markdown_widget only
/// applies [PConfig] to text wrapped in a paragraph; tight list items and
/// table cells inherit [DefaultTextStyle] instead, which is why replies used
/// to mix 15px white paragraphs with 14px grey bullets. [ResponseMarkdown]
/// pins that default to [body] so no element can fall through.
///
/// Parameter names are load-bearing and differ between config classes
/// (`PConfig`/`PreConfig` take `textStyle`; heading and `CodeConfig` take
/// `style`) — verified against markdown_widget 2.3.2+8.
class MarkdownTheme {
  static const double bodySize = 16;
  static const double metaSize = 12.5;

  static TextStyle get body => GoogleFonts.bricolageGrotesque(
        fontSize: bodySize,
        color: AppTheme.textPrimary,
        height: 1.6,
      );

  static TextStyle _serif(double size) => GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
        height: 1.3,
      );

  static TextStyle _minorHeading(double size) => GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
        height: 1.4,
      );

  static TextStyle get _mono => GoogleFonts.robotoMono(
        fontSize: 14,
        height: 1.5,
        color: AppTheme.accentLight,
      );

  static MarkdownConfig get response => MarkdownConfig(
        configs: [
          PConfig(textStyle: body),
          H1Config(style: _serif(22)),
          H2Config(style: _serif(20)),
          H3Config(style: _serif(18)),
          H4Config(style: _minorHeading(bodySize + 0.5)),
          H5Config(style: _minorHeading(bodySize)),
          H6Config(style: _minorHeading(bodySize)),
          PreConfig.darkConfig.copy(
            textStyle: _mono,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppTheme.border),
            ),
          ),
          CodeConfig(
            style: _mono.copyWith(backgroundColor: AppTheme.surfaceVariant),
          ),
          const LinkConfig(
            style: TextStyle(
              color: AppTheme.accentLight,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.accentDim,
            ),
          ),
          const ListConfig(marginLeft: 22),
          const BlockquoteConfig(
            sideColor: AppTheme.accentDim,
            textColor: AppTheme.textSecondary,
          ),
          // No headerStyle: in 2.3.2+8 body rows also read headerStyle (and
          // bodyStyle is never used), so a bold header would bold every cell.
          // Cells inherit [ResponseMarkdown]'s DefaultTextStyle instead.
          TableConfig(
            border: TableBorder.all(color: AppTheme.borderStrong),
            headerRowDecoration:
                const BoxDecoration(color: AppTheme.surfaceVariant),
            // Wide tables (spreadsheets, comparisons) scroll sideways instead
            // of crushing every column down to one word per line.
            wrapper: (table) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          ),
        ],
      );
}

/// An AI reply rendered with [MarkdownTheme]. Use this rather than a bare
/// markdown widget so every chat surface shares one type scale.
class ResponseMarkdown extends StatelessWidget {
  final String data;
  const ResponseMarkdown(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: MarkdownTheme.body,
      child: MarkdownBlock(data: data, config: MarkdownTheme.response),
    );
  }
}
