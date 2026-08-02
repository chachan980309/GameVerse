import 'package:flutter/material.dart';

import '../services/mention_service.dart';
import '../services/profile_navigation_service.dart';

class MentionText extends StatelessWidget {
  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  static final RegExp _mentions = RegExp(r'@([A-Za-z0-9_.-]+)');

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _mentions.allMatches(text)) {
      if (match.start > cursor)
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      final username = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _openMention(context, username),
            child: Text(
              '@$username',
              style: (style ?? const TextStyle()).copyWith(
                color: const Color(0xFFBDAAFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length)
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    return Text.rich(
      TextSpan(
        children: spans.isEmpty ? [TextSpan(text: text, style: style)] : spans,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  Future<void> _openMention(BuildContext context, String username) async {
    try {
      final userId = await MentionService().userIdForUsername(username);
      if (userId != null) ProfileNavigationService.instance.openProfile(userId);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir este perfil.')),
        );
    }
  }
}
