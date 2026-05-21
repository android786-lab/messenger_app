import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  // Live chat data from stream
  ChatModel? _chat;
  // Resolved member objects
  Map<String, UserModel> _memberMap = {};
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    // Listen to the chat stream so admins + participants stay live
    _chatService.getChatStream(widget.chatId).listen((chat) {
      if (!mounted) return;
      final prevParticipants = _chat?.participants ?? [];
      setState(() => _chat = chat);
      // Reload member objects only when participants list changes
      if (chat != null) {
        final newIds = chat.participants.toSet();
        final oldIds = prevParticipants.toSet();
        if (newIds != oldIds) _loadMembers(chat.participants);
      }
    });
    // Initial load
    _chatService.getChatStream(widget.chatId).first.then((chat) {
      if (chat != null && mounted) {
        setState(() => _chat = chat);
        _loadMembers(chat.participants);
      }
    });
  }

  String get _currentUserId =>
      Provider.of<AuthController>(context, listen: false).currentUser?.uid ?? '';

  Future<void> _loadMembers(List<String> participantIds) async {
    if (!mounted) return;
    setState(() => _loadingMembers = true);
    final futures = participantIds.map((id) => _authService.getUserById(id));
    final users = await Future.wait(futures);
    if (!mounted) return;
    final map = <String, UserModel>{};
    for (final u in users) {
      if (u != null) map[u.uid] = u;
    }
    setState(() {
      _memberMap = map;
      _loadingMembers = false;
    });
  }

  // ── Admin actions ──────────────────────────────────────────────

  Future<void> _makeAdmin(UserModel member) async {
    await _chatService.makeGroupAdmin(widget.chatId, member.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} is now an admin')),
      );
    }
  }

  Future<void> _removeAdmin(UserModel member) async {
    await _chatService.removeGroupAdmin(widget.chatId, member.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} is no longer an admin')),
      );
    }
  }

  Future<void> _removeMember(UserModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${member.name} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Remove from Firestore — stream will update _chat and trigger _loadMembers
    await _chatService.removeMemberFromGroup(widget.chatId, member.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} removed from group')),
      );
    }
  }

  Future<void> _exitGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit Group'),
        content: const Text('Are you sure you want to exit this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _chatService.exitGroup(widget.chatId);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ── Member tap — admin-only bottom sheet ───────────────────────

  void _onMemberTap(UserModel member) {
    final admins = _chat?.admins ?? [];
    final creatorId = _chat?.createdBy ?? '';

    // Tapping yourself — no options
    if (member.uid == _currentUserId) return;
    // Non-admins see nothing
    if (!admins.contains(_currentUserId)) return;

    final isMemberAdmin = admins.contains(member.uid);
    final isMemberCreator = member.uid == creatorId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Member header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.lightPrimaryColor,
                    backgroundImage: member.photoUrl != null
                        ? NetworkImage(member.photoUrl!)
                        : null,
                    child: member.photoUrl == null
                        ? Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      if (isMemberAdmin)
                        Text(
                          isMemberCreator ? 'Group creator' : 'Group admin',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.lightPrimaryColor),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Make / Remove admin — creator cannot be demoted
            if (!isMemberCreator)
              ListTile(
                leading: Icon(
                  isMemberAdmin
                      ? Icons.remove_moderator_outlined
                      : Icons.admin_panel_settings_outlined,
                  color: AppTheme.lightPrimaryColor,
                ),
                title: Text(
                    isMemberAdmin ? 'Remove as admin' : 'Make group admin'),
                onTap: () {
                  Navigator.pop(context);
                  isMemberAdmin ? _removeAdmin(member) : _makeAdmin(member);
                },
              ),

            // Remove from group
            ListTile(
              leading: const Icon(Icons.person_remove_outlined,
                  color: Colors.red),
              title: Text('Remove ${member.name}',
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeMember(member);
              },
            ),

            // Verify security code
            ListTile(
              leading: const Icon(Icons.verified_user_outlined,
                  color: AppTheme.lightTextSecondary),
              title: const Text('Verify security code'),
              onTap: () {
                Navigator.pop(context);
                _showVerifyDialog(member.name);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyDialog(String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Security Code'),
        content: Text('Messages with $name are end-to-end encrypted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Group name / description ───────────────────────────────────

  void _editGroupName() {
    final ctrl = TextEditingController(
        text: _chat?.groupName ?? widget.groupName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change group name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await _chatService.updateGroupName(widget.chatId, name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editGroupDescription() {
    final ctrl = TextEditingController(
        text: _chat?.groupDescription ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Group description'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Add a group description...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _chatService.updateGroupDescription(
                  widget.chatId, ctrl.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Add members ────────────────────────────────────────────────

  void _addMembers() {
    final currentParticipants = List<String>.from(_chat?.participants ?? []);
    final searchCtrl = TextEditingController();
    List<UserModel> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, scrollCtrl) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              children: [
                const Text('Add Members',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (q) async {
                    if (q.trim().isEmpty) {
                      setModal(() => results = []);
                      return;
                    }
                    setModal(() => searching = true);
                    final authCtrl =
                        Provider.of<AuthController>(context, listen: false);
                    final found = await authCtrl.searchUsers(q.trim());
                    setModal(() {
                      results = found
                          .where((u) => !currentParticipants.contains(u.uid))
                          .toList();
                      searching = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: searching
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final u = results[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.lightPrimaryColor,
                                backgroundImage: u.photoUrl != null
                                    ? NetworkImage(u.photoUrl!)
                                    : null,
                                child: u.photoUrl == null
                                    ? Text(
                                        u.name.isNotEmpty
                                            ? u.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text(u.name),
                              subtitle: Text(u.email),
                              trailing: IconButton(
                                icon: const Icon(Icons.add,
                                    color: AppTheme.lightPrimaryColor),
                                onPressed: () async {
                                  await _chatService.addMemberToGroup(
                                      widget.chatId, u.uid);
                                  setModal(() => results
                                      .removeWhere((r) => r.uid == u.uid));
                                  currentParticipants.add(u.uid);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          '${u.name} added to group'),
                                    ));
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final admins = chat?.admins ?? [];
    final creatorId = chat?.createdBy ?? '';
    final isAdmin = admins.contains(_currentUserId);
    final groupName = chat?.groupName ?? widget.groupName;
    final memberCount = chat?.participants.length ?? 0;
    final description = chat?.groupDescription ?? '';

    // Build sorted member list from the live map
    final participants = chat?.participants ?? [];
    final members = participants
        .map((id) => _memberMap[id])
        .whereType<UserModel>()
        .toList()
      ..sort((a, b) {
        if (a.uid == creatorId) return -1;
        if (b.uid == creatorId) return 1;
        final aAdmin = admins.contains(a.uid);
        final bAdmin = admins.contains(b.uid);
        if (aAdmin && !bAdmin) return -1;
        if (!aAdmin && bAdmin) return 1;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: AppTheme.lightTextPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Group Info',
                style: TextStyle(
                    color: AppTheme.lightTextPrimary,
                    fontWeight: FontWeight.w600)),
            actions: [
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppTheme.lightTextPrimary),
                  onSelected: (v) {
                    if (v == 'add') _addMembers();
                    if (v == 'rename') _editGroupName();
                    if (v == 'desc') _editGroupDescription();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'add', child: Text('Add members')),
                    PopupMenuItem(
                        value: 'rename',
                        child: Text('Change group name')),
                    PopupMenuItem(
                        value: 'desc',
                        child: Text('Edit description')),
                  ],
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppTheme.lightPrimaryColor,
                        backgroundImage: chat?.groupPhotoUrl != null
                            ? NetworkImage(chat!.groupPhotoUrl!)
                            : null,
                        child: chat?.groupPhotoUrl == null
                            ? const Icon(Icons.group,
                                color: Colors.white, size: 48)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(groupName,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.lightTextPrimary)),
                      const SizedBox(height: 4),
                      Text('Group - $memberCount members',
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.lightTextSecondary)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(description,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.lightTextSecondary),
                              textAlign: TextAlign.center),
                        ),
                      ] else if (isAdmin) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _editGroupDescription,
                          child: const Text('Add group description',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.lightPrimaryColor)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildActionButton(Icons.call_outlined, 'Audio', () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Group voice calls: use a dedicated group room (coming soon).',
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 24),
                          _buildActionButton(Icons.videocam_outlined, 'Video', () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Group video calls: use a dedicated group room (coming soon).',
                                ),
                              ),
                            );
                          }),
                          if (isAdmin) ...[
                            const SizedBox(width: 24),
                            _buildActionButton(
                                Icons.person_add_outlined, 'Add',
                                _addMembers),
                          ],
                          const SizedBox(width: 24),
                          _buildActionButton(
                              Icons.search, 'Search', () {}),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Media row ──────────────────────────────────
                Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.photo_library_outlined,
                        color: AppTheme.lightTextPrimary),
                    title: const Text('Media, links, and docs'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.lightTextSecondary),
                    onTap: () {},
                  ),
                ),

                const SizedBox(height: 8),

                // ── Members list ───────────────────────────────
                Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('$memberCount members',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.lightTextSecondary)),
                      ),
                      // Add members shortcut (admin only)
                      if (isAdmin)
                        ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F3FF),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(Icons.person_add_outlined,
                                color: AppTheme.lightPrimaryColor),
                          ),
                          title: const Text('Add members',
                              style: TextStyle(
                                  color: AppTheme.lightPrimaryColor,
                                  fontWeight: FontWeight.w600)),
                          onTap: _addMembers,
                        ),
                      // Member tiles
                      if (_loadingMembers)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ...members.map((member) => _buildMemberTile(
                              member: member,
                              isAdmin: admins.contains(member.uid),
                              isSelf: member.uid == _currentUserId,
                              isCreator: member.uid == creatorId,
                              onTap: () => _onMemberTap(member),
                            )),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Settings ───────────────────────────────────
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.storage_outlined,
                            color: AppTheme.lightTextPrimary),
                        title: const Text('Manage Storage'),
                        subtitle: const Text('0 B',
                            style: TextStyle(
                                color: AppTheme.lightTextSecondary,
                                fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.lightTextSecondary),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined,
                            color: AppTheme.lightTextPrimary),
                        title: const Text('Notifications'),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.lightTextSecondary),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_outline,
                            color: AppTheme.lightTextPrimary),
                        title: const Text('Encryption'),
                        subtitle: const Text(
                          'Messages and calls are end-to-end encrypted.',
                          style: TextStyle(
                              color: AppTheme.lightTextSecondary,
                              fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.lightTextSecondary),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Exit group ─────────────────────────────────
                Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.exit_to_app,
                        color: Colors.red),
                    title: const Text('Exit group',
                        style: TextStyle(color: Colors.red)),
                    onTap: _exitGroup,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widget builders ─────────────────────────────────────

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.lightPrimaryColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.lightTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildMemberTile({
    required UserModel member,
    required bool isAdmin,
    required bool isSelf,
    required bool isCreator,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.lightPrimaryColor,
        backgroundImage: member.photoUrl != null
            ? NetworkImage(member.photoUrl!)
            : null,
        child: member.photoUrl == null
            ? Text(
                member.name.isNotEmpty
                    ? member.name[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(
        isSelf ? '${member.name} (You)' : member.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        member.email,
        style: const TextStyle(
            fontSize: 12, color: AppTheme.lightTextSecondary),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isAdmin
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50)),
              ),
              child: const Text(
                'Group admin',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
}
