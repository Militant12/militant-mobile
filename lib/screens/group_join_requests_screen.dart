import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../theme/theme_context.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

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
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _api ??= await ApiService.getInstance();
      final requests = await _api!.getGroupJoinRequests(widget.groupId);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      // FormatException comprise : getFriendlyErrorMessage la traduit.
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
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
    return AppAvatar(
      url: avatar == null ? null : _api?.getImageUrl(avatar),
      semanticLabel: request['username']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('join_requests')),
        backgroundColor: context.theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const SkeletonList()
          : _error != null
          ? ErrorState(error: _error, onRetry: _loadRequests)
          : _requests.isEmpty
          ? EmptyState(
              icon: Icons.how_to_reg_outlined,
              title: lang.translate('no_join_requests'),
            )
          : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                final username =
                    request['username'] ?? lang.translate('user');
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
                          icon: Icon(Icons.check, color: context.tokens.success),
                          onPressed: () => _approveRequest(request),
                          tooltip: lang.translate('approve'),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: context.colors.error),
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
