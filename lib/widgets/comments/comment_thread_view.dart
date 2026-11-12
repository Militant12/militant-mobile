import 'package:flutter/material.dart';

import '../../models/comment.dart';
import '../../services/language_service.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';
import '../../utils/comment_threads.dart';
import '../../utils/date_formatter.dart';
import '../common/common.dart';
import '../linkable_text.dart';
import '../militant_badge.dart';
import '../technician_badge.dart';

/// Ce qu'on peut faire sur un commentaire. Les écrans (posts, groupes,
/// pages) branchent leurs propres appels à l'API.
class CommentActions {
  const CommentActions({
    required this.avatarUrl,
    required this.onLike,
    required this.onReply,
    required this.onTranslate,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = _never,
    this.canDelete = _never,
  });

  /// Adresse complète d'un avatar à partir du chemin renvoyé par l'API.
  final String? Function(String? path) avatarUrl;
  final ValueChanged<Comment> onLike;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onTranslate;
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;
  final bool Function(Comment) canEdit;
  final bool Function(Comment) canDelete;

  static bool _never(Comment _) => false;
}

/// Émoji des réactions des pages.
const Map<String, String> commentReactionEmojis = {
  'like': '👍',
  'love': '❤️',
  'haha': '😂',
  'wow': '😮',
  'sad': '😢',
  'angry': '😠',
};

// Géométrie du fil : l'avatar principal, puis les réponses alignées sur le
// texte du commentaire principal.
const double _sidePadding = AppTokens.space16;
const double _rootAvatarRadius = 18;
const double _replyAvatarRadius = 14;
const double _avatarGap = 10;
const double _replyIndent = _sidePadding + _rootAvatarRadius * 2 + _avatarGap;
const double _threadX = _sidePadding + _rootAvatarRadius;

/// Un commentaire principal, ses réponses sur un seul niveau et le bouton
/// pour afficher les autres.
class CommentThreadView extends StatelessWidget {
  const CommentThreadView({
    super.key,
    required this.thread,
    required this.expanded,
    required this.onToggleExpanded,
    required this.actions,
  });

  final CommentThread thread;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final CommentActions actions;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final visible = thread.visibleReplies(expanded: expanded);
    final hidden = thread.hiddenReplyCount(expanded: expanded);
    final canCollapse = expanded && thread.replies.length > collapsedReplyCount;
    final hasToggle = hidden > 0 || canCollapse;

    final rows = <Widget>[
      for (var i = 0; i < visible.length; i++)
        _ThreadBranch(
          // Centre de l'avatar de la réponse : marge du haut + rayon.
          elbowY: AppTokens.space4 + _replyAvatarRadius,
          continues: i < visible.length - 1 || hasToggle,
          child: _CommentTile(
            comment: visible[i].comment,
            text: visible[i].displayText,
            avatarRadius: _replyAvatarRadius,
            actions: actions,
          ),
        ),
      if (hasToggle)
        _ThreadBranch(
          elbowY: 24,
          continues: false,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onToggleExpanded,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space8,
                ),
                textStyle: context.text.labelLarge,
              ),
              child: Text(
                hidden == 0
                    ? lang.translate('comment_hide_replies')
                    : hidden == 1
                    ? lang.translate('comment_one_more_reply')
                    : lang
                          .translate('comment_more_replies')
                          .replaceAll('{count}', '$hidden'),
              ),
            ),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomPaint(
            painter: rows.isEmpty
                ? null
                : _ThreadPainter(
                    color: context.colors.outlineVariant,
                    // Sous l'avatar principal (marge du haut + diamètre +
                    // espace) jusqu'en bas.
                    startY: AppTokens.space4 + _rootAvatarRadius * 2 + 4,
                  ),
            child: Padding(
              padding: const EdgeInsets.only(left: _sidePadding),
              child: _CommentTile(
                comment: thread.root,
                text: (t) => t,
                avatarRadius: _rootAvatarRadius,
                actions: actions,
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.base),
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne sous le commentaire principal : le fil descend, puis tourne à
/// 45° vers la réponse, comme la diagonale du logo.
class _ThreadBranch extends StatelessWidget {
  const _ThreadBranch({
    required this.elbowY,
    required this.continues,
    required this.child,
  });

  final double elbowY;
  final bool continues;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ElbowPainter(
        color: context.colors.outlineVariant,
        elbowY: elbowY,
        continues: continues,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: _replyIndent),
        child: child,
      ),
    );
  }
}

Paint _threadPaint(Color color) => Paint()
  ..color = color
  ..strokeWidth = 1.5
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _ThreadPainter extends CustomPainter {
  _ThreadPainter({required this.color, required this.startY});

  final Color color;
  final double startY;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= startY) return;
    canvas.drawLine(
      const Offset(_threadX, 0) + Offset(0, startY),
      Offset(_threadX, size.height),
      _threadPaint(color),
    );
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.color != color || old.startY != startY;
}

class _ElbowPainter extends CustomPainter {
  _ElbowPainter({
    required this.color,
    required this.elbowY,
    required this.continues,
  });

  final Color color;
  final double elbowY;
  final bool continues;

  /// Longueur de la diagonale (même chose à l'horizontale et à la verticale).
  static const double _diagonal = 10;

  /// Espace laissé entre le bout du fil et l'avatar.
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _threadPaint(color);
    final turnY = elbowY - _diagonal;
    final path = Path()
      ..moveTo(_threadX, 0)
      ..lineTo(_threadX, turnY)
      ..lineTo(_threadX + _diagonal, elbowY)
      ..lineTo(_replyIndent - _gap, elbowY);
    canvas.drawPath(path, paint);
    if (continues) {
      canvas.drawLine(
        Offset(_threadX, turnY),
        Offset(_threadX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ElbowPainter old) =>
      old.color != color || old.elbowY != elbowY || old.continues != continues;
}

/// Avatar, bulle et actions d'un commentaire.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.text,
    required this.avatarRadius,
    required this.actions,
  });

  final Comment comment;

  /// Transforme le texte avant affichage (`@pseudo` des sous-réponses).
  final String Function(String) text;
  final double avatarRadius;
  final CommentActions actions;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final muted = context.tokens.textMuted;
    final body = comment.isTranslated && comment.translatedContent != null
        ? comment.translatedContent!
        : comment.content;
    final canEdit = actions.canEdit(comment);
    final canDelete = actions.canDelete(comment);

    return Padding(
      padding: const EdgeInsets.only(
        top: AppTokens.space4,
        right: AppTokens.space8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            url: actions.avatarUrl(comment.userAvatar),
            name: comment.username,
            radius: avatarRadius,
          ),
          const SizedBox(width: _avatarGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space12,
                    AppTokens.space8,
                    AppTokens.space4,
                    AppTokens.space8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    // Coin serré du côté de l'avatar : la bulle « parle ».
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(AppTokens.radius16),
                      bottomLeft: Radius.circular(AppTokens.radius16),
                      bottomRight: Radius.circular(AppTokens.radius16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              comment.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ..._badges(context),
                          const Spacer(),
                          if (comment.reactionsCount > 0)
                            _ReactionCount(comment: comment),
                          if (canEdit || canDelete)
                            _CommentMenu(
                              canEdit: canEdit,
                              canDelete: canDelete,
                              onEdit: () => actions.onEdit(comment),
                              onDelete: () => actions.onDelete(comment),
                            )
                          else
                            const SizedBox(height: 24),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: AppTokens.space8),
                        child: LinkableText(
                          text: text(body),
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionRow(
                  comment: comment,
                  date: DateFormatter.formatRelative(comment.createdAt),
                  actions: actions,
                  muted: muted,
                  lang: lang,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _badges(BuildContext context) => [
    if (comment.militantBadge != null) ...[
      const SizedBox(width: 4),
      MilitantBadge(badgeId: comment.militantBadge, size: 14),
    ],
    if (comment.isMilitantTechnician) ...[
      const SizedBox(width: 4),
      const TechnicianBadge(size: 14),
    ],
    if (comment.isModerator) ...[
      const SizedBox(width: 4),
      Tooltip(
        message: LanguageService.instance.translate('post_elected_moderator'),
        child: Icon(
          Icons.shield,
          size: 14,
          color: context.colors.onPrimaryContainer,
        ),
      ),
    ],
  ];
}

class _CommentMenu extends StatelessWidget {
  const _CommentMenu({
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return SizedBox(
      height: 24,
      child: PopupMenuButton<String>(
        tooltip: lang.translate('a11y_comment_options'),
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_horiz, color: context.tokens.textMuted),
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 24),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => [
          if (canEdit)
            PopupMenuItem(value: 'edit', child: Text(lang.translate('edit'))),
          if (canDelete)
            PopupMenuItem(
              value: 'delete',
              child: Text(
                lang.translate('delete'),
                style: TextStyle(color: context.colors.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// `2 h · J'aime · Répondre · Traduire`, en petit, avec des zones tactiles
/// de 40 px de haut.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.comment,
    required this.date,
    required this.actions,
    required this.muted,
    required this.lang,
  });

  final Comment comment;
  final String date;
  final CommentActions actions;
  final Color muted;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    final active = context.colors.onPrimaryContainer;

    Widget action(String label, VoidCallback onTap, {bool on = false}) =>
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(40, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: on ? active : muted,
            textStyle: context.text.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        );

    // Wrap : en espagnol ou sur un petit écran, les actions passent à la
    // ligne au lieu de déborder.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTokens.space12,
            right: AppTokens.space4,
          ),
          child: Text(
            date,
            style: context.text.labelMedium?.copyWith(color: muted),
          ),
        ),
        action(
          lang.translate('like_action'),
          () => actions.onLike(comment),
          on: comment.hasReacted,
        ),
        action(lang.translate('reply'), () => actions.onReply(comment)),
        action(
          comment.isTranslated
              ? lang.translate('original_label')
              : lang.translate('translate_action'),
          () => actions.onTranslate(comment),
          on: comment.isTranslated,
        ),
      ],
    );
  }
}

/// Compteur de réactions, en haut à droite de la bulle.
class _ReactionCount extends StatelessWidget {
  const _ReactionCount({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final color = comment.hasReacted
        ? context.colors.onPrimaryContainer
        : context.tokens.textMuted;
    final emoji = commentReactionEmojis[comment.userReaction];
    return Semantics(
      label: LanguageService.instance
          .translate('a11y_comment_reactions')
          .replaceAll('{count}', '${comment.reactionsCount}'),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: AppTokens.space8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji, style: context.text.labelMedium)
            else
              Icon(Icons.thumb_up, size: 14, color: color),
            const SizedBox(width: 4),
            RollingCount(
              count: comment.reactionsCount,
              style: context.text.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
