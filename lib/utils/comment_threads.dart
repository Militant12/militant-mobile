import '../models/comment.dart';

/// Réponses visibles sous un commentaire tant que le fil est replié.
const int collapsedReplyCount = 2;

/// Une réponse affichée sous le commentaire principal.
class ThreadReply {
  const ThreadReply(this.comment, {this.replyToUsername});

  final Comment comment;

  /// Pseudo de la sous-réponse à laquelle elle répond, `null` quand elle
  /// répond directement au commentaire principal.
  final String? replyToUsername;

  /// Texte à afficher : `@pseudo` devant quand on répond à une sous-réponse,
  /// sauf si la personne l'a déjà écrit elle-même.
  String displayText(String text) {
    final name = replyToUsername;
    if (name == null || name.isEmpty) return text;
    if (text.trimLeft().toLowerCase().startsWith('@${name.toLowerCase()}')) {
      return text;
    }
    return '@$name $text';
  }
}

/// Un commentaire principal et toutes ses réponses, sur un seul niveau.
class CommentThread {
  const CommentThread(this.root, this.replies);

  final Comment root;

  /// Réponses par ordre chronologique, quelle que soit leur profondeur.
  final List<ThreadReply> replies;

  /// Réponses à montrer selon que le fil est déplié ou non.
  List<ThreadReply> visibleReplies({required bool expanded}) =>
      expanded ? replies : replies.take(collapsedReplyCount).toList();

  int hiddenReplyCount({required bool expanded}) =>
      expanded ? 0 : (replies.length - collapsedReplyCount).clamp(0, 1 << 30);

  bool contains(int commentId) =>
      root.id == commentId || replies.any((r) => r.comment.id == commentId);
}

int _chronological(Comment a, Comment b) {
  final byDate = a.createdAt.compareTo(b.createdAt);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

/// Fils à partir de l'arbre renvoyé par l'API des posts et des groupes
/// (`replies` imbriquées sur plusieurs niveaux).
List<CommentThread> threadsFromTree(List<Comment> roots) {
  return [for (final root in roots) CommentThread(root, _flattenReplies(root))];
}

List<ThreadReply> _flattenReplies(Comment root) {
  final replies = <ThreadReply>[];
  void visit(Comment parent) {
    for (final reply in parent.replies) {
      replies.add(
        ThreadReply(
          reply,
          replyToUsername: identical(parent, root) ? null : parent.username,
        ),
      );
      visit(reply);
    }
  }

  visit(root);
  replies.sort((a, b) => _chronological(a.comment, b.comment));
  return replies;
}

/// Fils à partir d'une liste à plat avec `parent_id` (commentaires des
/// pages). Un commentaire dont le parent est introuvable devient principal.
List<CommentThread> threadsFromFlat(List<Comment> comments) {
  final byId = {for (final c in comments) c.id: c};

  Comment? parentOf(Comment c) {
    final parentId = c.parentId;
    if (parentId == null || parentId == c.id) return null;
    return byId[parentId];
  }

  Comment rootOf(Comment c) {
    var current = c;
    final seen = <int>{current.id};
    while (true) {
      final parent = parentOf(current);
      if (parent == null) return current;
      // Boucle de parents (données incohérentes) : le commentaire reste seul.
      if (!seen.add(parent.id)) return c;
      current = parent;
    }
  }

  final roots = <Comment>[];
  final repliesByRoot = <int, List<ThreadReply>>{};
  for (final comment in comments) {
    final root = rootOf(comment);
    if (identical(root, comment)) {
      roots.add(comment);
      continue;
    }
    final parent = parentOf(comment)!;
    repliesByRoot
        .putIfAbsent(root.id, () => [])
        .add(
          ThreadReply(
            comment,
            replyToUsername: identical(parent, root) ? null : parent.username,
          ),
        );
  }

  roots.sort(_chronological);
  return [
    for (final root in roots)
      CommentThread(
        root,
        (repliesByRoot[root.id] ?? [])
          ..sort((a, b) => _chronological(a.comment, b.comment)),
      ),
  ];
}

/// Tous les commentaires des fils, principaux et réponses.
Iterable<Comment> allComments(List<CommentThread> threads) sync* {
  for (final thread in threads) {
    yield thread.root;
    for (final reply in thread.replies) {
      yield reply.comment;
    }
  }
}

/// Garde les traductions déjà affichées quand la liste est rechargée (après
/// un envoi ou une modification), tant que le texte n'a pas changé.
void keepTranslations(List<CommentThread> previous, List<CommentThread> next) {
  final old = {for (final c in allComments(previous)) c.id: c};
  for (final comment in allComments(next)) {
    final before = old[comment.id];
    if (before == null || before.content != comment.content) continue;
    comment.translatedContent = before.translatedContent;
    comment.isTranslated = before.isTranslated;
  }
}
