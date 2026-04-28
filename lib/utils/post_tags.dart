List<String> extractPostTags(String text) {
  final matches = RegExp(r'(^|[\s\n])#([A-Za-z0-9_]{2,})').allMatches(text);
  final tags = <String>{};

  for (final match in matches) {
    final tag = match.group(2)?.trim().toLowerCase();
    if (tag != null && tag.isNotEmpty) {
      tags.add(tag);
    }
  }

  return tags.toList()..sort();
}

