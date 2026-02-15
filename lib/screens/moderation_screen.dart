import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../models/report.dart';
import '../services/language_service.dart';
import 'post_detail_screen.dart';

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
    setState(() => _isLoading = true);

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _voteOnReport(int reportId, String vote) async {
    try {
      final api = await ApiService.getInstance();
      await api.voteOnReport(reportId, vote);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vote enregistré!')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _voteForModerator(int userId, String vote) async {
    try {
      final api = await ApiService.getInstance();
      final result = await api.voteForModerator(userId, vote);

      if (mounted) {
        String message = 'Vote enregistré!';
        if (result['elected'] == true) {
          message = 'Modérateur·ice élu·e par consensus!';
        } else if (result['revoked'] == true) {
          message = 'Modérateur·ice révoqué·e par consensus!';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);

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
          indicatorColor: const Color(0xFFBE1E1E),
          labelColor: const Color(0xFFBE1E1E),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
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
  }

  Widget _buildReportsTab() {
    final lang = LanguageService.instance;
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              lang.translate('mod_no_reports'),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFBE1E1E),
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
    final reasonLabels = {
      'spam': 'Spam',
      'harassment': 'Harcèlement',
      'hate_speech': 'Discours haineux',
      'misinformation': 'Désinformation',
      'violence': 'Violence',
      'other': 'Autre',
    };

    final lang = LanguageService.instance;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
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
                    'par ${report.reporterUsername}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Text(
                  '${report.voteCount} votes',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contenu signalé
            if (report.postContent != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publication de ${report.reportedUsername ?? "[Supprimé]"}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.postContent!,
                      style: const TextStyle(color: Colors.white),
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
                  label: const Text('Voir le post'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],

            // Description
            if (report.description != null) ...[
              Text(
                report.description!,
                style: const TextStyle(
                  color: Colors.white70,
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
                  color: const Color(0xFFBE1E1E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.how_to_vote,
                      color: Color(0xFFBE1E1E),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tu as voté: ${_getVoteLabel(report.myVote!)}',
                      style: const TextStyle(color: Color(0xFFBE1E1E)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _voteOnReport(report.id, 'cancel'),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(color: Colors.white70),
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
                        foregroundColor: Colors.white,
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
                        foregroundColor: Colors.white,
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
                        foregroundColor: Colors.white,
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
                  color: const Color(0xFFDAA520).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFDAA520).withOpacity(0.3),
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
                                backgroundColor: const Color(0xFFBE1E1E),
                                foregroundColor: Colors.white,
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
                              foregroundColor: Colors.white,
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('mod_confirm_delete_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('mod_confirm_delete_text'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.translate('mod_apply_cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE1E1E),
              foregroundColor: Colors.white,
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
          const SnackBar(
            content: Text('Post supprimé par action de modérateur'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _moderatorWarnUser(int reportId) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('mod_confirm_warn_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('mod_confirm_warn_text'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.translate('mod_apply_cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
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
        ).showSnackBar(const SnackBar(content: Text('Avertissement envoyé')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
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
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.translate('mod_principles_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.translate('mod_principles_text'),
                style: const TextStyle(color: Colors.white70, height: 1.5),
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
              backgroundColor: const Color(0xFFBE1E1E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(_isCandidate ? Icons.cancel : Icons.how_to_vote),
            label: Text(
              _isCandidate
                  ? 'Annuler ma candidature'
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
                style: const TextStyle(color: Colors.white70),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('mod_apply_dialog_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate('mod_apply_dialog_desc'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: lang.translate('mod_apply_hint'),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
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
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitCandidacy(controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE1E1E),
              foregroundColor: Colors.white,
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
          message = 'Tu es déjà modérateur·ice !';
        } else if (message.contains('Already a candidate')) {
          message = 'Tu es déjà candidat·e !';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _confirmCancelCandidacy() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Annuler la candidature ?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Veux-tu vraiment retirer ta candidature ?\nTu perdras tous les votes reçus.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Oui, retirer',
              style: TextStyle(color: Colors.red),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Candidature annulée.')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
                style: const TextStyle(color: Colors.white70),
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
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
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
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),

              if (_actions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Aucune action enregistrée',
                      style: TextStyle(color: Colors.white38),
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
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                style: const TextStyle(color: Colors.white38, fontSize: 12),
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
                  color: Colors.orange.withOpacity(0.1),
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
                      style: const TextStyle(
                        color: Colors.white54,
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
                  color: const Color(0xFFBE1E1E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_bans.length}',
                      style: const TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      lang.translate('mod_sanction_ban'),
                      style: const TextStyle(
                        color: Colors.white54,
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
                    style: const TextStyle(color: Colors.white70),
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
    final color = isBan ? const Color(0xFFBE1E1E) : Colors.orange;
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
      if (diff.inDays > 0) {
        timeAgo = 'il y a ${diff.inDays}j';
      } else if (diff.inHours > 0) {
        timeAgo = 'il y a ${diff.inHours}h';
      } else {
        timeAgo = 'il y a ${diff.inMinutes}min';
      }
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
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar de la personne sanctionnée
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.2),
            backgroundImage:
                _apiService != null &&
                    targetAvatar != null &&
                    targetAvatar != 'default.svg' &&
                    _apiService!.getImageUrl(targetAvatar) != null
                ? NetworkImage(_apiService!.getImageUrl(targetAvatar)!)
                : null,
            child:
                _apiService == null ||
                    targetAvatar == null ||
                    targetAvatar == 'default.svg' ||
                    _apiService!.getImageUrl(targetAvatar) == null
                ? ClipOval(
                    child: SvgPicture.asset(
                      'assets/logo.svg',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
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
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    Flexible(
                      child: Text(
                        targetUsername,
                        style: const TextStyle(
                          color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white54,
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
                        color: color.withOpacity(0.15),
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
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
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
    final color = isWarning ? Colors.orange : const Color(0xFFBE1E1E);
    final label = isWarning ? 'Avertissement' : 'Post supprimé';
    final moderator =
        action['moderator_username'] ?? action['reporter_username'] ?? '?';
    final target = action['target_username'] ?? '?';
    final reason = action['reason'] ?? '';
    final dateStr = action['created_at'] ?? action['resolved_at'] ?? '';

    String timeAgo = '';
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) {
        timeAgo = 'il y a ${diff.inDays}j';
      } else if (diff.inHours > 0) {
        timeAgo = 'il y a ${diff.inHours}h';
      } else {
        timeAgo = 'il y a ${diff.inMinutes}min';
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar du modérateur
          CircleAvatar(
            radius: 16,
            backgroundImage:
                _apiService != null && action['moderator_avatar'] != null
                ? NetworkImage(
                    _apiService!.getImageUrl(action['moderator_avatar'])!,
                  )
                : null,
            backgroundColor: color.withOpacity(0.2),
            child: _apiService == null || action['moderator_avatar'] == null
                ? Text(
                    moderator.isNotEmpty ? moderator[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
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
                        style: const TextStyle(
                          color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isWarning ? 'par $moderator · $timeAgo' : timeAgo,
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFBE1E1E),
                backgroundImage:
                    _apiService != null &&
                        candidate.avatar != null &&
                        candidate.avatar != 'default.svg' &&
                        _apiService!.getImageUrl(candidate.avatar) != null
                    ? NetworkImage(_apiService!.getImageUrl(candidate.avatar)!)
                    : null,
                child:
                    _apiService == null ||
                        candidate.avatar == null ||
                        candidate.avatar == 'default.svg' ||
                        _apiService!.getImageUrl(candidate.avatar) == null
                    ? ClipOval(
                        child: SvgPicture.asset(
                          'assets/logo.svg',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isModerator)
                      const Text(
                        'Modérateur·ice',
                        style: TextStyle(
                          color: Color(0xFFBE1E1E),
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
              style: const TextStyle(
                color: Colors.white70,
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
                  color: Colors.green.withOpacity(0.2),
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
                  color: Colors.red.withOpacity(0.2),
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
                color: const Color(0xFFBE1E1E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, color: Color(0xFFBE1E1E), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'C\'est ta candidature',
                    style: TextStyle(
                      color: Color(0xFFBE1E1E),
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
                            : Colors.green.withOpacity(0.5),
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
                            : Colors.red.withOpacity(0.5),
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

  String _getVoteLabel(String vote) {
    switch (vote) {
      case 'remove':
        return 'Supprimer';
      case 'warn':
        return 'Avertir';
      case 'keep':
        return 'Garder';
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
