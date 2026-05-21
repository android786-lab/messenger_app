import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _aboutController;

  String? _photoUrl;
  bool _isLoading = false;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthController>(
      context,
      listen: false,
    ).currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _aboutController = TextEditingController(text: user?.about ?? '');
    _photoUrl = user?.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authController = Provider.of<AuthController>(context, listen: false);

    final success = await authController.updateProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      photoUrl: _photoUrl,
      about: _aboutController.text.trim().isEmpty
          ? null
          : _aboutController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authController.errorMessage ?? 'Failed to update profile',
          ),
          backgroundColor: AppTheme.lightErrorColor,
        ),
      );
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      setState(() => _isLoading = true);
      final file = source == ImageSource.camera
          ? await _storageService.pickImageFromCamera()
          : await _storageService.pickImageFromGallery();
      if (file == null) return;
      final uid = context.read<AuthController>().currentUser?.uid;
      if (uid == null) return;
      final url = await _storageService.uploadProfilePicture(
        file,
        userId: uid,
        onProgress: (_) {},
      );
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Profile Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: AppTheme.lightPrimaryColor,
                    ),
                  ),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickAndUploadPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: AppTheme.lightPrimaryColor,
                    ),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickAndUploadPhoto(ImageSource.gallery);
                  },
                ),
                if (_photoUrl != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete, color: Colors.red),
                    ),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _photoUrl = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppTheme.lightTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.lightPrimaryColor,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppTheme.lightPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Photo
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE4E6EB)),
                        image: _photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_photoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _photoUrl == null
                          ? Consumer<AuthController>(
                              builder: (context, authController, child) {
                                final user = authController.currentUser;
                                final initial = user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : 'U';
                                return Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.lightPrimaryColor,
                                    ),
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.lightPrimaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
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

              const SizedBox(height: 32),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: 'Name',
                hintText: 'Enter your name',
                prefixIcon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Phone Field
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                hintText: 'Enter your phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 20),

              // About Field
              _buildTextField(
                controller: _aboutController,
                label: 'About',
                hintText: 'Hey there! I am using this app.',
                prefixIcon: Icons.info_outline,
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              // Email Field (Read-only)
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'Your email address',
                prefixIcon: Icons.email_outlined,
                readOnly: true,
                helperText: 'Email cannot be changed',
              ),

              const SizedBox(height: 32),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.lightTextSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your profile information will be visible to other users when they chat with you.',
                        style: TextStyle(
                          color: AppTheme.lightTextSecondary,
                          fontSize: 13,
                        ),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? helperText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF5F5F5) : const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              prefixIcon: Icon(
                prefixIcon,
                color: readOnly
                    ? Colors.grey.shade400
                    : AppTheme.lightTextSecondary,
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              helperText: helperText,
              helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            style: TextStyle(
              fontSize: 15,
              color: readOnly
                  ? Colors.grey.shade600
                  : AppTheme.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
