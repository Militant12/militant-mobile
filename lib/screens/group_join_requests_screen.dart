import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../utils/error_helper.dart';

class GroupJoinRequestsScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupJoinRequestsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupJoinRequestsScreen> createState() =>
      _GroupJoinRequestsScreenState();
}

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      _api ??= await ApiService.getInstance();
      final requests = await _api!.getGroupJoinRequests(widget.groupId);
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } on FormatException {
      if (mounted) {
        setState(() => _isLoading = false);
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_generic')}: Réponse invalide du serveur (FormatException)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    }
  }

  Future<void> _approveRequest(dynamic request) async {
    final lang = LanguageService.instance;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.approveGroupJoinRequest(widget.groupId, request['user_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('request_approved'))),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    }
  }

  Future<void> _rejectRequest(dynamic request) async {
    final lang = LanguageService.instance;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.rejectGroupJoinRequest(widget.groupId, request['user_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('request_rejected'))),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    }
  }

  Widget _buildRequestAvatar(dynamic request) {
    final avatar = request['avatar']?.toString();
    final avatarUrl = avatar == null ? null : _api?.getImageUrl(avatar);

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.endsWith('.svg')) {
        return CircleAvatar(
          backgroundColor: Colors.white,
          child: ClipOval(
            child: SvgPicture.network(
              avatarUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      return CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.white,
      );
    }

    return CircleAvatar(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset('assets/logo.svg', fit: BoxFit.contain),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('join_requests')),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _requests.isEmpty
          ? Center(child: Text(lang.translate('no_join_requests')))
          : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                final username = request['username'] ?? 'User';
                final bio = request['bio'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: _buildRequestAvatar(request),
                    title: Text(username),
                    subtitle: bio.isNotEmpty ? Text(bio) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _approveRequest(request),
                          tooltip: lang.translate('approve'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _rejectRequest(request),
                          tooltip: lang.translate('reject'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
