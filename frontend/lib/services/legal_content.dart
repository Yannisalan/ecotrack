import 'package:flutter/services.dart' show rootBundle;

/// A single rendered block of the legal document.
///
/// The source file (`assets/legal/EcoTrack_Terms_and_Privacy.md`) is parsed
/// verbatim — no wording is added, removed, or reordered.
sealed class LegalBlock {
  const LegalBlock();
}

/// A `#` heading (document part title).
class LegalTitle extends LegalBlock {
  const LegalTitle(this.text);
  final String text;
}

/// A `##` heading (section heading).
class LegalHeading extends LegalBlock {
  const LegalHeading(this.text);
  final String text;
}

/// A `**...**` line rendered as emphasised lead-in (e.g. "Effective Date:").
class LegalMeta extends LegalBlock {
  const LegalMeta(this.text);
  final String text;
}

/// A block of paragraph text (may contain inline `**bold**` runs).
class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);
  final String text;
}

/// A bullet list item.
class LegalBullet extends LegalBlock {
  const LegalBullet(this.text);
  final String text;
}

/// A horizontal rule (`---`).
class LegalDivider extends LegalBlock {
  const LegalDivider();
}

/// A parsed legal document: the shared metadata plus the selected part.
class LegalDocument {
  const LegalDocument({required this.effectiveDate, required this.lastUpdated, required this.blocks});

  final String effectiveDate;
  final String lastUpdated;
  final List<LegalBlock> blocks;
}

/// Which half of the shared file to render.
enum LegalPart { terms, privacy }

/// Loads and parses the bundled legal document. The text is the single source
/// of truth and is never rewritten.
class LegalContent {
  const LegalContent._();

  static const _assetPath = 'assets/legal/EcoTrack_Terms_and_Privacy.md';

  /// Fallbacks used only if the file omits an explicit value.
  static const _fallbackEffective = '21 October 2026';
  static const _fallbackUpdated = '21 October 2026';

  static String? _cache;

  static Future<LegalDocument> load(LegalPart part) async {
    final raw = _cache ??= await rootBundle.loadString(_assetPath);
    return _parse(raw, part);
  }

  static LegalDocument _parse(String raw, LegalPart part) {
    final lines = raw.split(RegExp(r'\r?\n'));

    var effective = _fallbackEffective;
    var updated = _fallbackUpdated;
    final all = <LegalBlock>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == '---') {
        if (trimmed == '---') all.add(const LegalDivider());
        continue;
      }

      // Metadata lines at the top: "**Effective Date:** ..."
      if (trimmed.startsWith('**Effective Date:**')) {
        effective = trimmed.replaceFirst('**Effective Date:**', '').trim();
        continue;
      }
      if (trimmed.startsWith('**Last Updated:**')) {
        updated = trimmed.replaceFirst('**Last Updated:**', '').trim();
        continue;
      }

      if (trimmed.startsWith('# ')) {
        all.add(LegalTitle(trimmed.substring(2).trim()));
      } else if (trimmed.startsWith('## ')) {
        all.add(LegalHeading(trimmed.substring(3).trim()));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        all.add(LegalBullet(trimmed.substring(2).trim()));
      } else if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
        all.add(LegalMeta(trimmed.substring(2, trimmed.length - 2).trim()));
      } else {
        all.add(LegalParagraph(trimmed));
      }
    }

    final blocks = _selectPart(all, part);
    return LegalDocument(effectiveDate: effective, lastUpdated: updated, blocks: blocks);
  }

  /// Splits the flat block list on the `# PART 1` / `# PART 2` titles and
  /// returns the requested part (its own `#` title included, so the screen can
  /// show the part heading).
  static List<LegalBlock> _selectPart(List<LegalBlock> all, LegalPart part) {
    final titleIndexes = <int>[];
    for (var i = 0; i < all.length; i++) {
      final b = all[i];
      if (b is LegalTitle && b.text.toUpperCase().contains('PART ')) {
        titleIndexes.add(i);
      }
    }
    if (titleIndexes.isEmpty) return all;

    final start = part == LegalPart.terms ? titleIndexes.first : (titleIndexes.length > 1 ? titleIndexes[1] : titleIndexes.first);
    final end = part == LegalPart.terms
        ? (titleIndexes.length > 1 ? titleIndexes[1] : all.length)
        : all.length;
    return all.sublist(start, end);
  }
}
