import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/models/comment.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/utils/comment_threads.dart';
import 'package:militant/widgets/comments/comment_thread_view.dart';

Comment _comment(int id, String user, {int? parentId, String? text}) => Comment(
  id: id,
  postId: 1,
  userId: id,
  username: user,
  content: text ?? 'message $id',
  createdAt: DateTime(2026, 11, 11, 10, id),
  parentId: parentId,
);

void main() {
  final liked = <int>[];
  final replied = <int>[];
  final actions = CommentActions(
    avatarUrl: (_) => null,
    onLike: (c) => liked.add(c.id),
    onReply: (c) => replied.add(c.id),
    onTranslate: (_) {},
    onEdit: (_) {},
    onDelete: (_) {},
  );

  // alice ← bob, carol, dan, eve ; erin répond à bob.
  final thread = threadsFromFlat([
    _comment(1, 'alice'),
    _comment(2, 'bob', parentId: 1),
    _comment(3, 'carol', parentId: 1),
    _comment(4, 'dan', parentId: 1),
    _comment(5, 'erin', parentId: 2, text: 'd’accord'),
  ]).single;

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('replié : 2 réponses puis « Voir les 2 autres réponses »', (
    tester,
  ) async {
    var expanded = false;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => CommentThreadView(
            thread: thread,
            expanded: expanded,
            onToggleExpanded: () => setState(() => expanded = !expanded),
            actions: actions,
          ),
        ),
      ),
    );

    expect(find.text('bob'), findsOneWidget);
    expect(find.text('carol'), findsOneWidget);
    expect(find.text('dan'), findsNothing);
    expect(find.text('Voir les 2 autres réponses'), findsOneWidget);

    await tester.tap(find.text('Voir les 2 autres réponses'));
    await tester.pumpAndSettle();

    expect(find.text('dan'), findsOneWidget);
    expect(find.text('erin'), findsOneWidget);
    // erin répond à une sous-réponse : @bob devant son texte.
    expect(
      find.textContaining('@bob d’accord', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Masquer les réponses'), findsOneWidget);
  });

  testWidgets('les actions renvoient le bon commentaire', (tester) async {
    await tester.pumpWidget(
      app(
        CommentThreadView(
          thread: thread,
          expanded: true,
          onToggleExpanded: () {},
          actions: actions,
        ),
      ),
    );

    await tester.tap(find.text('J\'aime').first);
    await tester.tap(find.text('Répondre').last);
    expect(liked, [1]);
    expect(replied, [5]);
  });

  testWidgets('pas de bouton avec 2 réponses ou moins', (tester) async {
    final small = threadsFromFlat([
      _comment(1, 'alice'),
      _comment(2, 'bob', parentId: 1),
    ]).single;
    await tester.pumpWidget(
      app(
        CommentThreadView(
          thread: small,
          expanded: false,
          onToggleExpanded: () {},
          actions: actions,
        ),
      ),
    );
    expect(find.textContaining('Voir'), findsNothing);
    expect(find.textContaining('Masquer'), findsNothing);
  });

  testWidgets('tient sur un petit écran sans débordement', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        CommentThreadView(
          thread: thread,
          expanded: true,
          onToggleExpanded: () {},
          actions: actions,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
