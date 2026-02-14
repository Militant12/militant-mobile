import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/report.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final api = await ApiService.getInstance();

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
      });

      // Charger les modérateurs
      final moderatorsData = await api.getModerators();
      setState(() {
        _moderators.clear();
        _moderators.addAll(
          moderatorsData.map((m) => ModeratorCandidate.fromJson(m)).toList(),
        );
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Modération Collective'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFBE1E1E),
          labelColor: const Color(0xFFBE1E1E),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Signalements'),
            Tab(text: 'Candidats'),
            Tab(text: 'Modérateurs'),
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
              ],
            ),
    );
  }

  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Aucun signalement', style: TextStyle(color: Colors.white70)),
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
                      label: const Text('Supprimer'),
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
                      label: const Text('Avertir'),
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
                      label: const Text('Garder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesTab() {
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
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Principes de modération',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Égalité totale\n'
                '• Pas de hiérarchie\n'
                '• Décisions par consensus (70%)\n'
                '• Tout le monde peut voter\n'
                '• Modérateurs révocables',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Liste des candidats
        if (_candidates.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Aucun candidat',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ..._candidates.map((candidate) => _buildCandidateCard(candidate)),
      ],
    );
  }

  Widget _buildModeratorsTab() {
    if (_moderators.isEmpty) {
      return const Center(
        child: Text(
          'Aucun modérateur élu',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _moderators.length,
      itemBuilder: (context, index) {
        return _buildCandidateCard(_moderators[index], isModerator: true);
      },
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
                backgroundImage: candidate.avatar != null
                    ? NetworkImage(candidate.avatar!)
                    : null,
                child: candidate.avatar == null
                    ? Text(
                        candidate.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
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

          // Boutons de vote
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: candidate.myVote == 'for'
                      ? null
                      : () => _voteForModerator(candidate.userId, 'for'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Pour'),
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
                  label: Text(isModerator ? 'Révoquer' : 'Contre'),
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
