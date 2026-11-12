import 'package:flutter_test/flutter_test.dart';
import 'package:militant/models/comment.dart';
import 'package:militant/utils/comment_threads.dart';

Comment comment(
  int id,
  String user, {
  int? parentId,
  int minute = 0,
  List<Comment> replies = const [],
  String content = 'texte',
}) => Comment(
  id: id,
  postId: 1,
  userId: id,
  username: user,
  content: content,
  createdAt: DateTime(2026, 11, 11, 10, minute),
  parentId: parentId,
  replies: replies,
);

void main() {
  group('threadsFromTree (posts et groupes)', () {
    test('aplatit les réponses sur un niveau, par ordre chronologique', () {
      final threads = threadsFromTree([
        comment(
          1,
          'alice',
          replies: [
            comment(
              2,
              'bob',
              parentId: 1,
              minute: 1,
              replies: [comment(4, 'carol', parentId: 2, minute: 3)],
            ),
            comment(3, 'dan', parentId: 1, minute: 2),
          ],
        ),
      ]);

      expect(threads, hasLength(1));
      final replies = threads.single.replies;
      expect(replies.map((r) => r.comment.id), [2, 3, 4]);
      expect(replies.map((r) => r.replyToUsername), [null, null, 'bob']);
    });

    test('garde l’ordre des commentaires principaux', () {
      final threads = threadsFromTree([
        comment(1, 'alice'),
        comment(5, 'eve', minute: 4),
      ]);
      expect(threads.map((t) => t.root.id), [1, 5]);
    });
  });

  group('threadsFromFlat (pages)', () {
    test('regroupe une liste à plat par parent_id', () {
      final threads = threadsFromFlat([
        comment(1, 'alice'),
        comment(2, 'bob', parentId: 1, minute: 1),
        comment(3, 'carol', minute: 2),
        comment(4, 'dan', parentId: 2, minute: 3),
      ]);

      expect(threads.map((t) => t.root.id), [1, 3]);
      expect(threads.first.replies.map((r) => r.comment.id), [2, 4]);
      expect(threads.first.replies.last.replyToUsername, 'bob');
      expect(threads.last.replies, isEmpty);
    });

    test('un parent introuvable rend le commentaire principal', () {
      final threads = threadsFromFlat([comment(2, 'bob', parentId: 99)]);
      expect(threads.single.root.id, 2);
    });

    test('une boucle de parents ne bloque pas', () {
      final threads = threadsFromFlat([
        comment(1, 'alice', parentId: 2),
        comment(2, 'bob', parentId: 1, minute: 1),
      ]);
      expect(allComments(threads).map((c) => c.id), containsAll([1, 2]));
    });
  });

  group('repli', () {
    final thread = threadsFromFlat([
      comment(1, 'alice'),
      for (var i = 2; i <= 6; i++) comment(i, 'u$i', parentId: 1, minute: i),
    ]).single;

    test('2 réponses visibles, puis les autres comptées', () {
      expect(thread.visibleReplies(expanded: false), hasLength(2));
      expect(thread.hiddenReplyCount(expanded: false), 3);
    });

    test('déplié, tout est visible', () {
      expect(thread.visibleReplies(expanded: true), hasLength(5));
      expect(thread.hiddenReplyCount(expanded: true), 0);
    });

    test('rien de caché avec 2 réponses ou moins', () {
      final small = threadsFromFlat([
        comment(1, 'alice'),
        comment(2, 'bob', parentId: 1),
      ]).single;
      expect(small.hiddenReplyCount(expanded: false), 0);
    });
  });

  group('@pseudo', () {
    test('préfixe le texte en réponse à une sous-réponse', () {
      final reply = ThreadReply(comment(2, 'b'), replyToUsername: 'bob');
      expect(reply.displayText('salut'), '@bob salut');
    });

    test('pas de doublon si la personne l’a déjà écrit', () {
      final reply = ThreadReply(comment(2, 'b'), replyToUsername: 'bob');
      expect(reply.displayText('@Bob salut'), '@Bob salut');
    });

    test('rien en réponse directe au commentaire principal', () {
      final reply = ThreadReply(comment(2, 'b'));
      expect(reply.displayText('salut'), 'salut');
    });
  });

  test('keepTranslations garde la traduction si le texte est le même', () {
    final before = threadsFromFlat([
      comment(1, 'alice', content: 'hola'),
      comment(2, 'bob', parentId: 1, content: 'adios'),
    ]);
    before.first.root
      ..translatedContent = 'salut'
      ..isTranslated = true;
    before.first.replies.single.comment
      ..translatedContent = 'au revoir'
      ..isTranslated = true;

    final after = threadsFromFlat([
      comment(1, 'alice', content: 'hola'),
      comment(2, 'bob', parentId: 1, content: 'modifié'),
    ]);
    keepTranslations(before, after);

    expect(after.first.root.isTranslated, isTrue);
    expect(after.first.root.translatedContent, 'salut');
    expect(after.first.replies.single.comment.isTranslated, isFalse);
  });

  test('Comment.fromJson lit le format des pages', () {
    final c = Comment.fromJson({
      'id': '7',
      'post_id': 3,
      'user_id': 9,
      'username': 'alice',
      'user_avatar': 'a.jpg',
      'content': 'x',
      'created_at': '2026-11-11 10:00:00',
      'parent_id': null,
      'reactions_count': 2,
      'has_reacted': true,
      'user_reaction': 'love',
    });
    expect(c.id, 7);
    expect(c.userAvatar, 'a.jpg');
    expect(c.parentId, isNull);
    expect(c.userReaction, 'love');
    expect(c.hasReacted, isTrue);
  });
}
