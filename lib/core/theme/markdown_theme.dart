import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';

/// Markdown styling for AI responses.
///
/// Shared by the vault chat and standalone chat so answers render
/// identically everywhere. Headings take the serif display face; body copy
/// stays grotesque at a generous line-height, since these are long-form
/// reading surfaces rather than UI chrome.
///
/// Parameter names here are load-bearing and differ between config classes
/// (`PConfig`/`PreConfig` take `textStyle`; heading and `CodeConfig` take
/// `style`) — verified against markdown_widget 2.3.x. Don't "normalise" them.
class MarkdownTheme {
  static MarkdownConfig get response => MarkdownConfig(
        configs: [
          PConfig(
            textStyle: GoogleFonts.bricolageGrotesque(
              fontSize: 15,
              color: AppTheme.textPrimary,
              height: 1.68,
            ),
          ),
          H1Config(
            style: GoogleFonts.fraunces(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.35,
            ),
          ),
          H2Config(
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.35,
            ),
          ),
          H3Config(
            style: GoogleFonts.fraunces(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.35,
            ),
          ),
          PreConfig(
            textStyle: GoogleFonts.robotoMono(
              fontSize: 12.5,
              height: 1.55,
              color: AppTheme.accentLight,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppTheme.border),
            ),
          ),
          CodeConfig(
            style: GoogleFonts.robotoMono(
              fontSize: 12.5,
              color: AppTheme.accentLight,
              backgroundColor: AppTheme.surfaceVariant,
            ),
          ),
          const BlockquoteConfig(
            sideColor: AppTheme.accentDim,
            textColor: AppTheme.textSecondary,
          ),
        ],
      );
}
