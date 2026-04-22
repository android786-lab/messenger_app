import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../chat/chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<UserModel> _selectedMembers = [];
  List<UserModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final authController = Provider.of<AuthController>(context, listen: false);
    List<UserModel> results = await authController.searchUsers(query.trim());

    // Filter out already selected members
    results = results
        .where(
          (user) => !_selectedMembers.any((member) => member.uid == user.uid),
        )
        .toList();

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _addMember(UserModel user) {
    setState(() {
      _selectedMembers.add(user);
      _searchResults.remove(user);
    });
  }

  void _removeMember(UserModel user) {
    setState(() {
      _selectedMembers.remove(user);
    });
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a group name'),
          backgroundColor: AppTheme.lightErrorColor,
        ),
      );
      return;
    }

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one member'),
          backgroundColor: AppTheme.lightErrorColor,
        ),
      );
      return;
    }

    final chatController = Provider.of<ChatController>(context, listen: false);

    List<String> memberIds = _selectedMembers.map((user) => user.uid).toList();

    String? chatId = await chatController.createGroupChat(
      groupName: _groupNameController.text.trim(),
      memberIds: memberIds,
    );

    if (chatId != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            isGroup: true,
            chatTitle: _groupNameController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Group',
          style: TextStyle(
            color: AppTheme.lightTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Group Name Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomTextField(
              hintText: 'Group name',
              controller: _groupNameController,
              prefixIcon: Icon(Icons.group, color: AppTheme.lightTextSecondary),
            ),
          ),

          // Selected Members
          if (_selectedMembers.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Members (${_selectedMembers.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedMembers.length,
                      itemBuilder: (context, index) {
                        final member = _selectedMembers[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Stack(
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
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () => _removeMember(member),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightErrorColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  member.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.lightTextSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomTextField(
              hintText: 'Search by name, email or phone...',
              controller: _searchController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.lightTextSecondary,
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
          ),

          // Search Results
          Expanded(child: _buildSearchResults()),

          // Create Group Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer<ChatController>(
              builder: (context, chatController, child) {
                return CustomButton(
                  text: 'Create Group',
                  onPressed: _createGroup,
                  isLoading: chatController.isLoading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_add,
                size: 64,
                color: AppTheme.lightTextSecondary,
              ),
              SizedBox(height: 16),
              Text(
                'Add members to your group',
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Search for users by email to add them',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.lightPrimaryColor),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_search,
                size: 64,
                color: AppTheme.lightTextSecondary,
              ),
              SizedBox(height: 16),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try searching with a different email',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.lightPrimaryColor,
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            user.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          subtitle: Text(
            user.email,
            style: TextStyle(fontSize: 14, color: AppTheme.lightTextSecondary),
          ),
          trailing: IconButton(
            icon: Icon(Icons.add, color: AppTheme.lightPrimaryColor),
            onPressed: () => _addMember(user),
          ),
        );
      },
    );
  }
}
