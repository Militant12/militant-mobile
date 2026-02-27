import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';

class GroupSettingsScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _nameController = TextEditingController();
  int _autoDeleteTime = 0; // minutes
  List<dynamic> _members = [];
  List<dynamic> _requests = [];
  bool _isLoading = true;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.groupName;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _api = await ApiService.getInstance();
      final details = await _api!.getGroupDetails(widget.groupId);
      setState(() {
        _nameController.text = details['name'] ?? widget.groupName;
        _autoDeleteTime = details['auto_delete_time'] ?? 0;
        _members = details['members'] ?? [];
        _requests = details['requests'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _api!.updateGroupSettings(
        widget.groupId,
        name: _nameController.text,
        autoDeleteTime: _autoDeleteTime,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Paramètres')),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Paramètres du groupe'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Général',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBE1E1E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: 'Nom du groupe',
                      labelStyle: TextStyle(color: theme.hintColor),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Partage et Invitation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBE1E1E),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.green),
                  title: Text(
                    'Lien d\'invitation',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text(
                    'Copier le lien pour inviter des membres',
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () {
                    final link =
                        'https://militant.revlibertaire.com/message_groups_v2.php?group=${widget.groupId}';
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lien copié dans le presse-papier'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Confidentialité',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBE1E1E),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.blue),
                  title: Text(
                    'Messages éphémères',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text(
                    _autoDeleteTime == 0
                        ? 'Désactivé'
                        : 'Suppression après $_autoDeleteTime min',
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () async {
                    final val = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        backgroundColor: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        title: const Text('Délai de suppression'),
                        children: [
                          _timeOption(0, 'Désactivé'),
                          _timeOption(1, '1 minute'),
                          _timeOption(5, '5 minutes'),
                          _timeOption(60, '1 heure'),
                          _timeOption(1440, '24 heures'),
                        ],
                      ),
                    );
                    if (val != null) setState(() => _autoDeleteTime = val);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.orange),
                  title: Text(
                    'Tout le monde est Admin',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text(
                    'Donner les pleins pouvoirs à tous les membres',
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        title: const Text('Confirmer ?'),
                        content: const Text(
                          'Cela accordera les droits d\'administration à tous les membres actuels du groupe.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Confirmer',
                              style: TextStyle(color: Color(0xFFBE1E1E)),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await _api!.updateGroupSettings(
                          widget.groupId,
                          makeEveryoneAdmin: true,
                        );
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tous les membres sont désormais admins',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Membres',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFBE1E1E),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.person_add,
                              color: Color(0xFFBE1E1E),
                            ),
                            onPressed: _showAddMemberDialog,
                          ),
                          Text(
                            '${_members.length}',
                            style: TextStyle(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ..._members.map((m) {
                  final avatarUrl = _api?.getImageUrl(m['avatar']);
                  final isAdmin = m['role'] == 'admin';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFBE1E1E),
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? ClipOval(
                              child: SvgPicture.asset(
                                'assets/logo.svg',
                                fit: BoxFit.cover,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      m['username'],
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    ),
                    subtitle: Text(
                      isAdmin ? 'Administrateur' : 'Membre',
                      style: TextStyle(
                        color: isAdmin
                            ? const Color(0xFFBE1E1E)
                            : theme.hintColor,
                        fontWeight: isAdmin
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isAdmin
                        ? IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Color(0xFFBE1E1E),
                            ),
                            onPressed: () =>
                                _removeMember(m['user_id'], m['username']),
                          )
                        : null,
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (_requests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Demandes d\'adhésion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFBE1E1E),
                          ),
                        ),
                        Text(
                          '${_requests.length}',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  ..._requests.map((r) {
                    final avatarUrl = _api?.getImageUrl(r['avatar']);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFBE1E1E),
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? ClipOval(
                                child: SvgPicture.asset(
                                  'assets/logo.svg',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        r['username'],
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () =>
                                _handleRequest(r['request_id'], true),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFFBE1E1E),
                            ),
                            onPressed: () =>
                                _handleRequest(r['request_id'], false),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: ListTile(
              leading: const Icon(Icons.exit_to_app, color: Color(0xFFBE1E1E)),
              title: Text(
                'Quitter le groupe',
                style: TextStyle(
                  color: const Color(0xFFBE1E1E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _leaveGroup,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRequest(int requestId, bool approve) async {
    try {
      if (approve) {
        await _api!.approveGroupRequest(widget.groupId, requestId);
      } else {
        await _api!.rejectGroupRequest(widget.groupId, requestId);
      }
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Demande approuvée' : 'Demande refusée'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
      ),
    );

    try {
      final friendsData = await _api!.getFriends();
      if (mounted) Navigator.pop(context); // close loading

      final friends = friendsData['friends'] ?? friendsData['data'] ?? [];

      if (mounted) {
        bool isSearching = false;
        List<dynamic> displayUsers = List.from(friends);
        final searchController = TextEditingController();

        showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateBuilder) {
              return AlertDialog(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                title: const Text('Ajouter un membre'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un utilisateur...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).hintColor,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).hintColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (value) async {
                          if (value.length > 2) {
                            setStateBuilder(() => isSearching = true);
                            try {
                              final res = await _api!.search(
                                value,
                                type: 'users',
                              );
                              setStateBuilder(() {
                                displayUsers =
                                    res['data'] ?? res['items'] ?? [];
                                isSearching = false;
                              });
                            } catch (e) {
                              setStateBuilder(() => isSearching = false);
                            }
                          } else if (value.isEmpty) {
                            setStateBuilder(() {
                              displayUsers = List.from(friends);
                              isSearching = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: isSearching
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFBE1E1E),
                                ),
                              )
                            : displayUsers.isEmpty
                            ? const Center(
                                child: Text('Aucun utilisateur trouvé'),
                              )
                            : ListView.builder(
                                itemCount: displayUsers.length,
                                itemBuilder: (context, index) {
                                  final user = displayUsers[index];
                                  final avatarUrl = _api!.getImageUrl(
                                    user['avatar'],
                                  );
                                  final username =
                                      user['username'] ??
                                      user['name'] ??
                                      'Utilisateur inconnu';

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFBE1E1E),
                                      backgroundImage: avatarUrl != null
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: avatarUrl == null
                                          ? ClipOval(
                                              child: SvgPicture.asset(
                                                'assets/logo.svg',
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      username,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      try {
                                        await _api!.addGroupMember(
                                          widget.groupId,
                                          user['id'],
                                        );
                                        _loadData();
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '$username ajouté(e)',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Erreur: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _removeMember(int userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Retirer ce membre ?'),
        content: Text('Voulez-vous retirer $username du groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Retirer',
              style: TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api!.removeMemberFromGroup(widget.groupId, userId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$username a été retiré du groupe')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Quitter le groupe ?'),
        content: const Text(
          'Êtes-vous sûr de vouloir quitter ce groupe ? Vous ne pourrez plus accéder aux messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Quitter',
              style: TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api!.leaveMessageGroup(widget.groupId);
        if (mounted) {
          Navigator.pop(context, true); // Return to messages screen
          Navigator.pop(context, true); // Close chat screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous avez quitté le groupe')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  Widget _timeOption(int value, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
