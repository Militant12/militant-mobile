import 'package:flutter/material.dart';
import '../theme/theme_context.dart';
import '../services/api_service.dart';
import '../models/report.dart';
import '../services/language_service.dart';
import 'post_detail_screen.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Report> _reports = [];
  final List<ModeratorCandidate> _candidates = [];
  final List<ModeratorCandidate> _moderators = [];
  bool _isLoading = false;
  Object? _error;
  bool _isModerator = false;
  List<Map<String, dynamic>> _actions = [];
  List<Map<String, dynamic>> _sanctions = [];
  List<Map<String, dynamic>> _bans = [];
  ApiService? _apiService;
  bool _isCandidate = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _apiService = await ApiService.getInstance();
      final api = _apiService!;

      // Récupérer mon profil pour savoir si je suis déjà candidat
      try {
        final me = await api.getProfile();
        _currentUserId = me['id'];
      } catch (_) {}

      // Charger les signalements
      final reportsData = await api.getReports();
      setState(() {
        _reports.clear();
        _reports.addAll(reportsData.map((r) => Report.fromJson(r)).toList());
      });

      // Charger les candidats
      final candidatesData = await api.getCandidates();
      setState(() {
        _candidates.clear();
        _candidates.addAll(
          candidatesData.map((c) => ModeratorCandidate.fromJson(c)).toList(),
        );
        _isCandidate =
            _currentUserId != null &&
            _candidates.any((c) => c.userId == _currentUserId);
      });

      // Charger les modérateurs
      final moderatorsData = await api.getModerators();
      setState(() {
        _moderators.clear();
        _moderators.addAll(
          moderatorsData.map((m) => ModeratorCandidate.fromJson(m)).toList(),
        );
      });

      // Vérifier si l'utilisateur actuel est modérateur
      final isMod = await api.checkIfModerator();
      setState(() {
        _isModerator = isMod;
      });

      // Charger le journal des actions
      try {
        final actionsData = await api.getModeratorActions();
        setState(() {
          _actions = actionsData
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
        });
      } catch (_) {}

      // Charger les sanctions transparentes
      try {
        final sanctionsData = await api.getAllSanctions();
        setState(() {
          _sanctions = (sanctionsData['warnings'] as List? ?? [])
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
          _bans = (sanctionsData['bans'] as List? ?? [])
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
        });
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      if (_reports.isEmpty && _moderators.isEmpty) {
        setState(() => _error = e);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e, LanguageService.instance)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _voteOnReport(int reportId, String vote) async {
    try {
      final api = await ApiService.getInstance();
      await api.voteOnReport(reportId, vote);

      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(lang.translate('mod_vote_recorded'))));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    }
  }

  Future<void> _voteForModerator(int userId, String vote) async {
    try {
      final api = await ApiService.getInstance();
      final result = await api.voteForModerator(userId, vote);

      if (mounted) {
        final lang = LanguageService.instance;
        String message = lang.translate('mod_vote_recorded');
        if (result['elected'] == true) {
          message = lang.translate('mod_elected_consensus');
        } else if (result['revoked'] == true) {
          message = lang.translate('mod_revoked_consensus');
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);

    return ValueListenableBuilder<Locale>(
      valueListenable: lang,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            title: Text(
              lang.translate('mod_title'),
              style: TextStyle(color: theme.textTheme.titleLarge?.color),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: context.colors.primary,
              labelColor: context.colors.primary,
              // En mode clair, gris, en mode sombre, gris clair
              unselectedLabelColor: theme.unselectedWidgetColor,
              tabs: [
                Tab(text: lang.translate('mod_tab_reports')),
                Tab(text: lang.translate('mod_tab_candidates')),
                Tab(text: lang.translate('mod_tab_moderators')),
                Tab(text: lang.translate('mod_tab_sanctions')),
              ],
            ),
          ),
          body: _isLoading && _reports.isEmpty && _moderators.isEmpty
              ? const SkeletonList()
              : _error != null && _reports.isEmpty && _moderators.isEmpty
              ? ErrorState(error: _error, onRetry: _loadData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportsTab(),
                    _buildCandidatesTab(),
                    _buildModeratorsTab(),
                    _buildSanctionsTab(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildReportsTab() {
    final lang = LanguageService.instance;
    if (_reports.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: lang.translate('mod_no_reports'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.colors.primary,
      child: ListView.builder(
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    final lang = LanguageService.instance;
    final reasonLabels = {
      for (final reason in const [
        'spam',
        'harassment',
        'hate_speech',
        'misinformation',
        'violence',
        'other',
      ])
        reason: lang.translate('live_report_reason_$reason'),
    };

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: context.tokens.cardShadow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    reasonLabels[report.reason] ?? report.reason,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${lang.translate('mod_sanction_by')} ${report.reporterUsername}',
                    style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ),
                Text(
                  lang
                      .translate('mod_votes_count')
                      .replaceAll('{count}', '${report.voteCount}'),
                  style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contenu signalé
            if (report.postContent != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('mod_post_by').replaceAll(
                        '{username}',
                        report.reportedUsername ??
                            lang.translate('mod_deleted_user'),
                      ),
                      style: TextStyle(
                        color: context.colors.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.postContent!,
                      style: TextStyle(color: context.colors.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Lien vers le post
            if (report.postId != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PostDetailScreen(postId: report.postId!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(lang.translate('mod_view_post')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.onSurface,
                    side: BorderSide(color: context.colors.onSurface.withValues(alpha: 0.24)),
                  ),
                ),
              ),
            ],

            // Description
            if (report.description != null) ...[
              Text(
                report.description!,
                style: TextStyle(
                  color: context.colors.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Mon vote
            if (report.myVote != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.how_to_vote,
                      color: context.colors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang
                          .translate('mod_you_voted')
                          .replaceAll('{vote}', _getVoteLabel(report.myVote!)),
                      style: TextStyle(color: context.colors.primary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _voteOnReport(report.id, 'cancel'),
                      child: Text(
                        lang.translate('cancel'),
                        style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Boutons de vote
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _voteOnReport(report.id, 'remove'),
                      icon: const Icon(Icons.delete, size: 16),
                      label: Text(lang.translate('mod_vote_remove')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: context.colors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _voteOnReport(report.id, 'warn'),
                      icon: const Icon(Icons.warning, size: 16),
                      label: Text(lang.translate('mod_vote_warn')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: context.colors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _voteOnReport(report.id, 'keep'),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(lang.translate('mod_vote_keep')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: context.colors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Boutons d'action directe modérateur
            if (_isModerator) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDAA520).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFDAA520).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield,
                          size: 16,
                          color: Color(0xFFDAA520),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lang.translate('mod_action_title'),
                          style: const TextStyle(
                            color: Color(0xFFDAA520),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (report.postId != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _moderatorDeletePost(report.id),
                              icon: const Icon(Icons.delete_forever, size: 16),
                              label: Text(
                                lang.translate('mod_action_direct_delete'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.primary,
                                foregroundColor: context.colors.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        if (report.postId != null) const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _moderatorWarnUser(report.id),
                            icon: const Icon(Icons.warning_amber, size: 16),
                            label: Text(lang.translate('mod_action_warn')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: context.colors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _moderatorDeletePost(int reportId) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang.translate('mod_confirm_delete_title'),
          style: TextStyle(color: context.colors.onSurface),
        ),
        content: Text(
          lang.translate('mod_confirm_delete_text'),
          style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.translate('mod_apply_cancel'),
              style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
            ),
            child: Text(lang.translate('mod_vote_remove')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = await ApiService.getInstance();
      await api.moderatorDeletePost(reportId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.translate('mod_post_deleted_action')),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    }
  }

  Future<void> _moderatorWarnUser(int reportId) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang.translate('mod_confirm_warn_title'),
          style: TextStyle(color: context.colors.onSurface),
        ),
        content: Text(
          lang.translate('mod_confirm_warn_text'),
          style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.translate('mod_apply_cancel'),
              style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: context.colors.onPrimary,
            ),
            child: Text(lang.translate('mod_action_warn')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = await ApiService.getInstance();
      await api.moderatorWarnUser(reportId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.instance.translate('mod_warning_sent'),
            ),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      }
    }
  }

  Widget _buildCandidatesTab() {
    final lang = LanguageService.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            boxShadow: context.tokens.cardShadow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.translate('mod_principles_title'),
                style: TextStyle(
                  color: context.colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.translate('mod_principles_text'),
                style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bouton Se porter candidat / Annuler candidature
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isCandidate
                ? _confirmCancelCandidacy
                : _showCandidacyDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(_isCandidate ? Icons.cancel : Icons.how_to_vote),
            label: Text(
              _isCandidate
                  ? lang.translate('mod_cancel_candidacy')
                  : lang.translate('mod_apply_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Liste des candidats
        if (_candidates.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                lang.translate('mod_no_candidates'),
                style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          )
        else
          ..._candidates.map((candidate) => _buildCandidateCard(candidate)),
      ],
    );
  }

  void _showCandidacyDialog() {
    final controller = TextEditingController();
    final lang = LanguageService.instance;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          lang.translate('mod_apply_dialog_title'),
          style: TextStyle(color: context.colors.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate('mod_apply_dialog_desc'),
              style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              style: TextStyle(color: context.colors.onSurface),
              decoration: InputDecoration(
                hintText: lang.translate('mod_apply_hint'),
                hintStyle: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.38)),
                filled: true,
                fillColor: context.colors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              lang.translate('mod_apply_cancel'),
              style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitCandidacy(controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
            ),
            child: Text(lang.translate('mod_apply_send')),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCandidacy(String motivation) async {
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();
      await api.applyForModerator(motivation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('mod_apply_success'))),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.contains('Already a moderator')) {
          message = LanguageService.instance.translate('mod_already_moderator');
        } else if (message.contains('Already a candidate')) {
          message = LanguageService.instance.translate('mod_already_candidate');
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _confirmCancelCandidacy() async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang.translate('mod_cancel_candidacy_question'),
          style: TextStyle(color: context.colors.onSurface),
        ),
        content: Text(
          lang.translate('mod_cancel_candidacy_warning'),
          style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.translate('cancel'), style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang.translate('mod_cancel_candidacy'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _cancelCandidacy();
    }
  }

  Future<void> _cancelCandidacy() async {
    try {
      final api = await ApiService.getInstance();
      await api.cancelCandidacy();
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(lang.translate('mod_candidacy_cancelled'))));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    }
  }

  Widget _buildModeratorsTab() {
    final lang = LanguageService.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Liste des modérateurs
        if (_moderators.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                lang.translate('mod_no_moderators'),
                style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          )
        else
          ..._moderators.map((m) => _buildCandidateCard(m, isModerator: true)),

        const SizedBox(height: 24),

        // Journal transparent des actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    lang.translate('mod_transparency_title'),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                lang.translate('mod_transparency_desc'),
                style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.38), fontSize: 12),
              ),
              const SizedBox(height: 12),

              if (_actions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      lang.translate('mod_no_actions'),
                      style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.38)),
                    ),
                  ),
                )
              else
                ..._actions.map((action) => _buildActionItem(action)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSanctionsTab() {
    final lang = LanguageService.instance;
    final allSanctions = <Map<String, dynamic>>[];

    // Combiner warnings et bans avec un type
    for (final w in _sanctions) {
      allSanctions.add({...w, '_type': 'warning'});
    }
    for (final b in _bans) {
      allSanctions.add({...b, '_type': 'ban'});
    }

    // Trier par date décroissante
    allSanctions.sort((a, b) {
      final dateA = a['created_at'] ?? '';
      final dateB = b['created_at'] ?? '';
      return dateB.toString().compareTo(dateA.toString());
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // En-tête
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    lang.translate('mod_sanctions_title'),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                lang.translate('mod_sanctions_desc'),
                style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.38), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Statistiques
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_sanctions.length}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      lang.translate('mod_sanction_warning'),
                      style: TextStyle(
                        color: context.colors.onSurface.withValues(alpha: 0.54),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_bans.length}',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      lang.translate('mod_sanction_ban'),
                      style: TextStyle(
                        color: context.colors.onSurface.withValues(alpha: 0.54),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Liste
        if (allSanctions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(
                    lang.translate('mod_no_sanctions'),
                    style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          )
        else
          ...allSanctions.map((s) => _buildSanctionCard(s)),
      ],
    );
  }

  Widget _buildSanctionCard(Map<String, dynamic> sanction) {
    final lang = LanguageService.instance;
    final isBan = sanction['_type'] == 'ban';
    final color = isBan ? context.colors.primary : Colors.orange;
    final label = isBan
        ? lang.translate('mod_sanction_ban')
        : lang.translate('mod_sanction_warning');
    final icon = isBan ? Icons.block : Icons.warning_amber;

    final targetUsername = sanction['target_username'] ?? '?';
    final targetAvatar = sanction['target_avatar'];
    final issuedBy =
        sanction['issued_by_username'] ?? sanction['banned_by_username'] ?? '?';
    final reason = sanction['reason'] ?? '';
    final dateStr = sanction['created_at'] ?? '';

    // Time ago
    String timeAgo = '';
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(date);
      timeAgo = _timeAgo(diff);
    } catch (_) {}

    // Ban expiry
    String? expiryInfo;
    if (isBan) {
      if (sanction['is_permanent'] == 1 || sanction['is_permanent'] == true) {
        expiryInfo = lang.translate('mod_sanction_permanent');
      } else if (sanction['expires_at'] != null) {
        expiryInfo =
            '${lang.translate('mod_sanction_until')} ${sanction['expires_at']}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar de la personne sanctionnée
          AppAvatar(
            url: _apiService?.getImageUrl(targetAvatar),
            semanticLabel: targetUsername,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label + target
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '→ ',
                      style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.38), fontSize: 13),
                    ),
                    Flexible(
                      child: Text(
                        targetUsername,
                        style: TextStyle(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Motif
                if (reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      reason,
                      style: TextStyle(
                        color: context.colors.onSurface.withValues(alpha: 0.54),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Expiry info for bans
                if (expiryInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expiryInfo,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Date + who
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${lang.translate('mod_sanction_by')} $issuedBy · $timeAgo',
                    style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.24), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(Map<String, dynamic> action) {
    final isWarning = action['action_type'] == 'warning';
    final color = isWarning ? Colors.orange : context.colors.primary;
    final lang = LanguageService.instance;
    final label = isWarning
        ? lang.translate('mod_sanction_warning')
        : lang.translate('mod_post_deleted');
    final moderator =
        action['moderator_username'] ?? action['reporter_username'] ?? '?';
    final target = action['target_username'] ?? '?';
    final reason = action['reason'] ?? '';
    final dateStr = action['created_at'] ?? action['resolved_at'] ?? '';

    String timeAgo = '';
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(date);
      timeAgo = _timeAgo(diff);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar du modérateur
          AppAvatar(
            url: _apiService?.getImageUrl(action['moderator_avatar']),
            name: moderator,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: context.colors.onSurface.withValues(alpha: 0.7)),
                    children: [
                      TextSpan(
                        text: label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' — '),
                      TextSpan(
                        text: target,
                        style: TextStyle(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      reason,
                      style: TextStyle(
                        color: context.colors.onSurface.withValues(alpha: 0.38),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isWarning
                        ? '${lang.translate('mod_sanction_by')} $moderator · $timeAgo'
                        : timeAgo,
                    style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.24), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(
    ModeratorCandidate candidate, {
    bool isModerator = false,
  }) {
    final lang = LanguageService.instance;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: context.tokens.cardShadow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                url: _apiService?.getImageUrl(candidate.avatar),
                semanticLabel: candidate.username,
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.username,
                      style: TextStyle(
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isModerator)
                      Text(
                        LanguageService.instance.translate('mod_moderator_badge'),
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (candidate.motivation != null) ...[
            const SizedBox(height: 12),
            Text(
              '"${candidate.motivation}"',
              style: TextStyle(
                color: context.colors.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Votes
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${candidate.votesFor}',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.close, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${candidate.votesAgainst}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Boutons de vote (masqués pour sa propre candidature)
          if (candidate.userId == _currentUserId)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, color: context.colors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    lang.translate('mod_your_candidacy'),
                    style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: candidate.myVote == 'for'
                        ? null
                        : () => _voteForModerator(candidate.userId, 'for'),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(
                      LanguageService.instance.translate('mod_vote_for'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: candidate.myVote == 'for'
                          ? Colors.white
                          : Colors.green,
                      backgroundColor: candidate.myVote == 'for'
                          ? Colors.green
                          : null,
                      side: BorderSide(
                        color: candidate.myVote == 'for'
                            ? Colors.green
                            : Colors.green.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: candidate.myVote == 'against'
                        ? null
                        : () => _voteForModerator(candidate.userId, 'against'),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(
                      isModerator
                          ? LanguageService.instance.translate(
                              'mod_vote_revoke',
                            )
                          : LanguageService.instance.translate(
                              'mod_vote_against',
                            ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: candidate.myVote == 'against'
                          ? Colors.white
                          : Colors.red,
                      backgroundColor: candidate.myVote == 'against'
                          ? Colors.red
                          : null,
                      side: BorderSide(
                        color: candidate.myVote == 'against'
                            ? Colors.red
                            : Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _timeAgo(Duration diff) {
    final lang = LanguageService.instance;
    final String time;
    if (diff.inDays > 0) {
      time = lang
          .translate('time_days_short')
          .replaceAll('{count}', '${diff.inDays}');
    } else if (diff.inHours > 0) {
      time = lang
          .translate('time_hours_short')
          .replaceAll('{count}', '${diff.inHours}');
    } else {
      time = lang
          .translate('time_minutes_short')
          .replaceAll('{count}', '${diff.inMinutes}');
    }
    return lang.translate('time_ago').replaceAll('{time}', time);
  }

  String _getVoteLabel(String vote) {
    switch (vote) {
      case 'remove':
        return LanguageService.instance.translate('mod_vote_remove');
      case 'warn':
        return LanguageService.instance.translate('mod_vote_warn');
      case 'keep':
        return LanguageService.instance.translate('mod_vote_keep');
      default:
        return vote;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
