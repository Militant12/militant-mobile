import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'profile_screen.dart';

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

  File? _newGroupImageFile;
  String? _groupAvatar;
  bool _isSaving = false;

  String _errorText(Object error) => '${LanguageService.instance.translate('error')}: $error';

  String _replacePlaceholder(String template, String key, String value) {
    return template.replaceAll('{$key}', value);
  }

  String _autoDeleteLabel() {
    final lang = LanguageService.instance;
    switch (_autoDeleteTime) {
      case 0:
        return lang.translate('disabled');
      case 1:
        return '${lang.translate('ephemeral_delete_after')} ${lang.translate('duration_1_minute')}';
      case 5:
        return '${lang.translate('ephemeral_delete_after')} ${lang.translate('duration_5_minutes')}';
      case 60:
        return '${lang.translate('ephemeral_delete_after')} ${lang.translate('duration_1_hour')}';
      case 1440:
        return '${lang.translate('ephemeral_delete_after')} ${lang.translate('duration_24_hours')}';
      case 10080:
        return '${lang.translate('ephemeral_delete_after')} ${lang.translate('duration_1_week')}';
      default:
        return '${lang.translate('ephemeral_delete_after')} $_autoDeleteTime min';
    }
  }

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
        _groupAvatar = details['avatar'];
        _autoDeleteTime = details['auto_delete_time'] ?? 0;
        _members = details['members'] ?? [];
        _requests = details['requests'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      String? uploadedPath;
      if (_newGroupImageFile != null) {
        uploadedPath = await _api!.uploadFile(_newGroupImageFile!.path, type: 'group');
      }
      await _api!.updateGroupSettings(
        widget.groupId,
        name: _nameController.text,
        avatar: uploadedPath,
        autoDeleteTime: _autoDeleteTime,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newGroupImageFile = File(image.path);
      });
    }
  }

  Widget _buildAvatarPreview() {
    final avatarUrl = _api?.getImageUrl(_groupAvatar);
    if (avatarUrl != null) {
      return Image.network(
        avatarUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return SvgPicture.asset(
      'assets/logo.svg',
      width: 100,
      height: 100,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(lang.translate('settings'))),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(lang.translate('group_settings')),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFBE1E1E),
                      ),
                    ),
                  ),
                )
              : IconButton(icon: const Icon(Icons.check), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      border: Border.all(color: const Color(0xFFBE1E1E), width: 2),
                    ),
                    child: ClipOval(
                      child: _newGroupImageFile != null
                          ? Image.file(
                              _newGroupImageFile!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : _buildAvatarPreview(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFBE1E1E),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('general'),
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
                      labelText: lang.translate('group_name_label'),
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
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    lang.translate('sharing_and_invitation'),
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
                    lang.translate('invite_link'),
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text(
                    lang.translate('copy_invite_link'),
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () {
                    final link =
                        'https://militant.revlibertaire.com/message_groups_v2.php?group=${widget.groupId}';
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.translate('link_copied'))),
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
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    lang.translate('privacy'),
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
                    lang.translate('ephemeral_messages'),
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text(
                    _autoDeleteLabel(),
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () async {
                    final val = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        backgroundColor: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        title: Text(lang.translate('deletion_delay')),
                        children: [
                          _timeOption(0, lang.translate('disabled')),
                          _timeOption(1, lang.translate('duration_1_minute')),
                          _timeOption(5, lang.translate('duration_5_minutes')),
                          _timeOption(60, lang.translate('duration_1_hour')),
                          _timeOption(1440, lang.translate('duration_24_hours')),
                          _timeOption(10080, lang.translate('duration_1_week')),
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
                    lang.translate('everyone_is_admin'),
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text(
                    lang.translate('grant_full_powers_to_members'),
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        title: Text(lang.translate('confirm_question')),
                        content: Text(
                          lang.translate('grant_admin_rights'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(lang.translate('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              lang.translate('confirm'),
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
                            SnackBar(
                              content: Text(
                                lang.translate('all_members_now_admins'),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(_errorText(e))));
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
                      Text(
                        lang.translate('members_title'),
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
                    onTap: () {
                      final memberId = m['user_id'] is int
                          ? m['user_id']
                          : int.tryParse(m['user_id']?.toString() ?? '');
                      if (memberId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(userId: memberId),
                          ),
                        );
                      }
                    },
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
                      isAdmin
                          ? lang.translate('administrator')
                          : lang.translate('member'),
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
                        Text(
                          lang.translate('join_requests'),
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
                      onTap: () {
                        final reqUserId = r['user_id'] is int
                            ? r['user_id']
                            : int.tryParse(r['user_id']?.toString() ?? '');
                        if (reqUserId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userId: reqUserId),
                            ),
                          );
                        }
                      },
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
                lang.translate('leave_group_action'),
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
    final lang = LanguageService.instance;
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
            content: Text(
              approve
                  ? lang.translate('request_approved')
                  : lang.translate('request_rejected'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
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
                title: Text(LanguageService.instance.translate('add_member')),
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
                          hintText: LanguageService.instance.translate(
                            'search_user',
                          ),
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
                            ? Center(
                                child: Text(
                                  LanguageService.instance.translate(
                                    'no_user_found',
                                  ),
                                ),
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
                                      LanguageService.instance.translate(
                                        'unknown_user',
                                      );

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
                                                '$username ${LanguageService.instance.translate('member_added')}',
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
                                              content: Text(_errorText(e)),
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
                    child: Text(LanguageService.instance.translate('close')),
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
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
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
        title: Text(LanguageService.instance.translate('remove_member_question')),
        content: Text(
          _replacePlaceholder(
            LanguageService.instance.translate('remove_member_confirm'),
            'username',
            username,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LanguageService.instance.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              LanguageService.instance.translate('remove'),
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
            SnackBar(
              content: Text(
                '$username ${LanguageService.instance.translate('remove_member')}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorText(e))));
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
        title: Text(LanguageService.instance.translate('leave_group_title')),
        content: Text(
          LanguageService.instance.translate('leave_group_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LanguageService.instance.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              LanguageService.instance.translate('leave'),
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
            SnackBar(
              content: Text(LanguageService.instance.translate('left_group')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorText(e))));
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
