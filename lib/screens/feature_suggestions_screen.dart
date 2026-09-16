import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feature_suggestion.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../utils/error_helper.dart';

class FeatureSuggestionsScreen extends StatefulWidget {
  const FeatureSuggestionsScreen({super.key});

  @override
  State<FeatureSuggestionsScreen> createState() =>
      _FeatureSuggestionsScreenState();
}

class _FeatureSuggestionsScreenState extends State<FeatureSuggestionsScreen> {
  final List<FeatureSuggestion> _suggestions = [];
  Map<String, int> _stats = {};
  String _filter = 'popular';
  bool _isLoading = true;
  bool _isModerator = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final results = await Future.wait([
        api.getFeatureSuggestions(filter: _filter),
        api.getFeatureSuggestionStats(),
        api.getProfile(),
        api.checkIfModerator(),
      ]);
      final profile = results[2] as Map<String, dynamic>;
      final isElectedModerator = results[3] as bool;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(results[0] as List<FeatureSuggestion>);
        _stats = results[1] as Map<String, int>;
        _isModerator = _extractModeratorFlag(profile) || isElectedModerator;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _extractModeratorFlag(Map<String, dynamic> profile) {
    final dynamic directAdmin = profile['is_admin'];
    final dynamic directModerator = profile['is_moderator'];
    final dynamic directTechnician = profile['is_technician'];
    final dynamic directMilitantTechnician = profile['is_militant_technician'];
    final nested = profile['user'];
    final dynamic nestedAdmin = nested is Map ? nested['is_admin'] : null;
    final dynamic nestedModerator = nested is Map
        ? nested['is_moderator']
        : null;
    final dynamic nestedTechnician = nested is Map
        ? nested['is_technician']
        : null;
    final dynamic nestedMilitantTechnician = nested is Map
        ? nested['is_militant_technician']
        : null;
    bool asBool(dynamic value) =>
        value == true || value == 1 || value?.toString() == '1';
    return asBool(directAdmin) ||
        asBool(directModerator) ||
        asBool(directTechnician) ||
        asBool(directMilitantTechnician) ||
        asBool(nestedAdmin) ||
        asBool(nestedModerator) ||
        asBool(nestedTechnician) ||
        asBool(nestedMilitantTechnician);
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _CreateFeatureSuggestionDialog(),
    );
    if (created == true) {
      _loadData();
    }
  }

  Future<void> _openSuggestion(FeatureSuggestion suggestion) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FeatureSuggestionDetailScreen(
          suggestionId: suggestion.id,
          canModerate: _isModerator,
        ),
      ),
    );
    if (changed == true) {
      _loadData();
    }
  }

  Future<void> _vote(FeatureSuggestion suggestion, int vote) async {
    try {
      final api = await ApiService.getInstance();
      final updated = await api.voteFeatureSuggestion(suggestion.id, vote);
      final index = _suggestions.indexWhere((item) => item.id == suggestion.id);
      if (index != -1) {
        setState(() => _suggestions[index] = updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final translate = LanguageService.instance.translate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(title: Text(translate('feature_suggestions'))),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        backgroundColor: const Color(0xFFBE1E1E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFBE1E1E),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _buildIntroCard(context, translate, isDark),
                  const SizedBox(height: 12),
                  _buildFilterRow(context, translate),
                  const SizedBox(height: 12),
                  if (_suggestions.isEmpty)
                    _buildEmptyState(context, translate, isDark)
                  else
                    ..._suggestions.map(
                      (suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SuggestionCard(
                          suggestion: suggestion,
                          translate: translate,
                          isDark: isDark,
                          onTap: () => _openSuggestion(suggestion),
                          onUpvote: () => _vote(suggestion, 1),
                          onDownvote: () => _vote(suggestion, -1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard(
    BuildContext context,
    String Function(String) translate,
    bool isDark,
  ) {
    final cardColor = isDark ? const Color(0xFF171717) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE3E3E3);
    final textColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark ? Colors.white70 : const Color(0xFF5F6368);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFBE1E1E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  translate('suggest_features_desc'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatPill(
                context,
                translate('total'),
                _stats['total'] ?? 0,
                subColor,
              ),
              _buildStatPill(
                context,
                translate('status_pending'),
                _stats['pending'] ?? 0,
                subColor,
              ),
              _buildStatPill(
                context,
                translate('status_planned'),
                _stats['planned'] ?? 0,
                subColor,
              ),
              _buildStatPill(
                context,
                translate('status_done'),
                _stats['done'] ?? 0,
                subColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    BuildContext context,
    String label,
    int value,
    Color subColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(color: subColor, fontSize: 12),
      ),
    );
  }

  Widget _buildFilterRow(
    BuildContext context,
    String Function(String) translate,
  ) {
    final filters = <String, String>{
      'popular': translate('popular'),
      'recent': translate('recent'),
      'planned': translate('status_planned'),
      'done': translate('status_done'),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final selected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) {
                setState(() => _filter = entry.key);
                _loadData();
              },
              selectedColor: const Color(0xFFBE1E1E),
              labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String Function(String) translate,
    bool isDark,
  ) {
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE3E3E3);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 42,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          const SizedBox(height: 12),
          Text(
            translate('no_suggestions'),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }
}

class FeatureSuggestionDetailScreen extends StatefulWidget {
  final int suggestionId;
  final bool canModerate;

  const FeatureSuggestionDetailScreen({
    super.key,
    required this.suggestionId,
    required this.canModerate,
  });

  @override
  State<FeatureSuggestionDetailScreen> createState() =>
      _FeatureSuggestionDetailScreenState();
}

class _FeatureSuggestionDetailScreenState
    extends State<FeatureSuggestionDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  FeatureSuggestion? _suggestion;
  List<FeatureSuggestionComment> _comments = [];
  bool _isLoading = true;
  bool _hasChanged = false;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final data = await api.getFeatureSuggestionDetail(widget.suggestionId);
      if (!mounted) return;
      setState(() {
        _suggestion = data['suggestion'] as FeatureSuggestion;
        _comments = data['comments'] as List<FeatureSuggestionComment>;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _vote(int vote) async {
    if (_suggestion == null) return;
    try {
      final api = await ApiService.getInstance();
      final updated = await api.voteFeatureSuggestion(_suggestion!.id, vote);
      setState(() {
        _suggestion = updated;
        _hasChanged = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.length < 3 || _suggestion == null) return;
    setState(() => _isSubmittingComment = true);
    try {
      final api = await ApiService.getInstance();
      final comment = await api.commentFeatureSuggestion(
        _suggestion!.id,
        content,
      );
      _commentController.clear();
      setState(() {
        _comments = [comment, ..._comments];
        _hasChanged = true;
      });
      await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _openModerationDialog() async {
    if (_suggestion == null) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _SuggestionModerationDialog(suggestion: _suggestion!),
    );
    if (changed == true) {
      _hasChanged = true;
      _loadDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final translate = LanguageService.instance.translate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF5F5F5);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanged);
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(translate('feature_suggestions')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasChanged),
          ),
          actions: [
            if (widget.canModerate && _suggestion != null)
              IconButton(
                onPressed: _openModerationDialog,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: _isLoading || _suggestion == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadDetail,
                      color: const Color(0xFFBE1E1E),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        children: [
                          _buildDetailCard(translate, isDark),
                          const SizedBox(height: 12),
                          Text(
                            translate('comments_title'),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_comments.isEmpty)
                            Text(
                              translate('no_comments'),
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                            )
                          else
                            ..._comments.map(
                              (comment) => _CommentTile(comment: comment),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF171717) : Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE3E3E3),
                          ),
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: translate('add_comment'),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white10
                                    : const Color(0xFFF1F3F4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: _isSubmittingComment
                                ? null
                                : _submitComment,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFBE1E1E),
                            ),
                            icon: _isSubmittingComment
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDetailCard(String Function(String) translate, bool isDark) {
    final suggestion = _suggestion!;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE3E3E3);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111111),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${suggestion.username} · ${_formatDate(suggestion.createdAt)}',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: suggestion.status, translate: translate),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            suggestion.description,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.45,
            ),
          ),
          if (suggestion.adminResponse != null &&
              suggestion.adminResponse!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white10
                    : const Color(0xFFBE1E1E).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('admin_response'),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFFBE1E1E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    suggestion.adminResponse!,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _VoteButton(
                icon: Icons.arrow_upward,
                label: suggestion.votesUp.toString(),
                selected: suggestion.myVote == 1,
                positive: true,
                onTap: () => _vote(1),
              ),
              const SizedBox(width: 10),
              _VoteButton(
                icon: Icons.arrow_downward,
                label: suggestion.votesDown.toString(),
                selected: suggestion.myVote == -1,
                positive: false,
                onTap: () => _vote(-1),
              ),
              const SizedBox(width: 12),
              Text(
                '${translate('comments_title')} ${suggestion.commentCount}',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _SuggestionCard extends StatelessWidget {
  final FeatureSuggestion suggestion;
  final String Function(String) translate;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  const _SuggestionCard({
    required this.suggestion,
    required this.translate,
    required this.isDark,
    required this.onTap,
    required this.onUpvote,
    required this.onDownvote,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF171717) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE3E3E3);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: Column(
                  children: [
                    _MiniVoteButton(
                      icon: Icons.keyboard_arrow_up,
                      selected: suggestion.myVote == 1,
                      onTap: onUpvote,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        suggestion.score.toString(),
                        style: TextStyle(
                          color: suggestion.score > 0
                              ? Colors.green
                              : suggestion.score < 0
                              ? Colors.red
                              : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _MiniVoteButton(
                      icon: Icons.keyboard_arrow_down,
                      selected: suggestion.myVote == -1,
                      onTap: onDownvote,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.title,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111111),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(
                          status: suggestion.status,
                          translate: translate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestion.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          suggestion.username,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF5F6368),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${translate('comments_title')} ${suggestion.commentCount}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF5F6368),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final FeatureSuggestionComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE3E3E3),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.username,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            comment.content,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String Function(String) translate;

  const _StatusBadge({required this.status, required this.translate});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg = Colors.white;
    switch (status) {
      case 'done':
        bg = Colors.green;
        break;
      case 'rejected':
        bg = Colors.red;
        break;
      case 'in_progress':
        bg = Colors.orange;
        break;
      case 'planned':
        bg = Colors.blue;
        break;
      default:
        bg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        translate('status_$status'),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MiniVoteButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MiniVoteButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFBE1E1E) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : const Color(0xFFD8DADF),
          ),
        ),
        child: Icon(icon, color: selected ? Colors.white : null),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool positive;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.positive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = positive ? Colors.green : Colors.red;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? activeColor.withValues(alpha: 0.12) : null,
        side: BorderSide(color: selected ? activeColor : Colors.black12),
      ),
      icon: Icon(icon, size: 18, color: selected ? activeColor : null),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? activeColor : null,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CreateFeatureSuggestionDialog extends StatefulWidget {
  const _CreateFeatureSuggestionDialog();

  @override
  State<_CreateFeatureSuggestionDialog> createState() =>
      _CreateFeatureSuggestionDialogState();
}

class _CreateFeatureSuggestionDialogState
    extends State<_CreateFeatureSuggestionDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSaving = false;
  bool _hasDraft = false;
  Timer? _draftDebounce;

  static const _draftTitleKey = 'draft_feature_suggestion_title';
  static const _draftDescriptionKey = 'draft_feature_suggestion_description';

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleDraftSave);
    _descriptionController.addListener(_scheduleDraftSave);
    _loadDraft();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _titleController.removeListener(_scheduleDraftSave);
    _descriptionController.removeListener(_scheduleDraftSave);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _hasDraftContent =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty;

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_draftTitleKey) ?? '';
    final description = prefs.getString(_draftDescriptionKey) ?? '';
    if (!mounted || (title.trim().isEmpty && description.trim().isEmpty)) {
      return;
    }
    _titleController.text = title;
    _descriptionController.text = description;
    setState(() => _hasDraft = true);
  }

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 350), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_hasDraftContent) {
      await _removeDraft(prefs);
      if (mounted && _hasDraft) {
        setState(() => _hasDraft = false);
      }
      return;
    }

    await prefs.setString(_draftTitleKey, _titleController.text);
    await prefs.setString(_draftDescriptionKey, _descriptionController.text);
    if (mounted && !_hasDraft) {
      setState(() => _hasDraft = true);
    }
  }

  Future<void> _removeDraft([SharedPreferences? prefs]) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    await storage.remove(_draftTitleKey);
    await storage.remove(_draftDescriptionKey);
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    await _removeDraft();
    _titleController.clear();
    _descriptionController.clear();
    if (mounted) {
      setState(() => _hasDraft = false);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.length < 5 || description.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le titre ou la description est trop court.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final api = await ApiService.getInstance();
      await api.createFeatureSuggestion(title, description);
      _draftDebounce?.cancel();
      await _removeDraft();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final translate = LanguageService.instance.translate;
    return AlertDialog(
      title: Text(translate('new_suggestion')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: translate('suggestion_title'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: translate('suggestion_description'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_hasDraft)
          IconButton(
            onPressed: _isSaving ? null : _clearDraft,
            icon: const Icon(Icons.delete_outline),
            tooltip: translate('clear_draft'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(translate('cancel')),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(translate('submit')),
        ),
      ],
    );
  }
}

class _SuggestionModerationDialog extends StatefulWidget {
  final FeatureSuggestion suggestion;

  const _SuggestionModerationDialog({required this.suggestion});

  @override
  State<_SuggestionModerationDialog> createState() =>
      _SuggestionModerationDialogState();
}

class _SuggestionModerationDialogState
    extends State<_SuggestionModerationDialog> {
  late String _status;
  late TextEditingController _responseController;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.suggestion.status;
    _responseController = TextEditingController(
      text: widget.suggestion.adminResponse ?? '',
    );
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final api = await ApiService.getInstance();
      await api.updateFeatureSuggestionStatus(
        widget.suggestion.id,
        _status,
        adminResponse: _responseController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    try {
      final api = await ApiService.getInstance();
      await api.deleteFeatureSuggestion(widget.suggestion.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final translate = LanguageService.instance.translate;
    return AlertDialog(
      title: Text(translate('mod_title')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              items:
                  const [
                    'pending',
                    'planned',
                    'in_progress',
                    'done',
                    'rejected',
                  ].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(translate('status_$status')),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _responseController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: translate('admin_response'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving || _isDeleting ? null : _delete,
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(translate('delete')),
        ),
        TextButton(
          onPressed: _isSaving || _isDeleting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(translate('cancel')),
        ),
        FilledButton(
          onPressed: _isSaving || _isDeleting ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(translate('save')),
        ),
      ],
    );
  }
}
