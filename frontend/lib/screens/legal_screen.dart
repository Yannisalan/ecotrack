import 'package:flutter/material.dart';
import '../services/legal_content.dart';
import '../theme/app_theme.dart';
import '../widgets/neon.dart';

/// Renders either the Terms and Conditions (Part 1) or the Privacy Policy
/// (Part 2) of the bundled legal document. The text is loaded verbatim from
/// `assets/legal/EcoTrack_Terms_and_Privacy.md`.
///
/// Opened as `/terms` or `/privacy`; expose a route helper so the register
/// consent links can push it without touching the form state.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.part});

  final LegalPart part;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late Future<LegalDocument> _future;

  @override
  void initState() {
    super.initState();
    _future = LegalContent.load(widget.part);
  }

  String get _title => widget.part == LegalPart.terms
      ? 'Terms and Conditions'
      : 'Privacy Policy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NeonAppBar(title: _title),
      body: FutureBuilder<LegalDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState(message: 'Loading…');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorState(
              message: 'Could not load the document. Please try again.',
              onRetry: () => setState(
                () => _future = LegalContent.load(widget.part),
              ),
            );
          }
          final doc = snapshot.data!;
          return _LegalBody(document: doc);
        },
      ),
    );
  }
}

class _LegalBody extends StatelessWidget {
  const _LegalBody({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      children: [
        Text(
          'Last Updated: ${document.lastUpdated}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: eco.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        for (final block in document.blocks) _buildBlock(context, block),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, LegalBlock block) {
    final eco = context.eco;
    final theme = Theme.of(context);

    switch (block) {
      case LegalTitle(:final text):
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(text, style: theme.textTheme.headlineSmall),
        );
      case LegalHeading(:final text):
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: eco.textPrimary,
            ),
          ),
        );
      case LegalMeta(:final text):
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case LegalBullet(:final text):
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 10),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: eco.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: _RichText(
                  text: text,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: eco.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      case LegalParagraph(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RichText(
            text: text,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: eco.textPrimary,
              height: 1.5,
            ),
          ),
        );
      case LegalDivider():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(color: eco.border, height: 1),
        );
    }
  }
}

/// Renders a paragraph/bullet, honouring inline `**bold**` runs without
/// altering the surrounding wording.
class _RichText extends StatelessWidget {
  const _RichText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// Convenience helpers for the consent links.
void openTerms(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LegalScreen(part: LegalPart.terms)),
  );
}

void openPrivacy(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const LegalScreen(part: LegalPart.privacy),
    ),
  );
}
