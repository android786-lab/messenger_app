import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/contacts_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/local_contact_model.dart';

class EditContactScreen extends StatefulWidget {
  final LocalContact contact;

  const EditContactScreen({super.key, required this.contact});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _companyController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  DateTime? _selectedBirthday;
  bool _showMoreFields = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c.name);
    _phoneController = TextEditingController(text: c.phone);
    _emailController = TextEditingController(text: c.email ?? '');
    _nicknameController = TextEditingController(text: c.nickname ?? '');
    _companyController = TextEditingController(text: c.company ?? '');
    _jobTitleController = TextEditingController(text: c.jobTitle ?? '');
    _addressController = TextEditingController(text: c.address ?? '');
    _notesController = TextEditingController(text: c.notes ?? '');
    _selectedBirthday = c.birthday;

    // Auto-expand if any optional field has data
    if ((c.email ?? '').isNotEmpty ||
        (c.nickname ?? '').isNotEmpty ||
        (c.company ?? '').isNotEmpty ||
        (c.jobTitle ?? '').isNotEmpty ||
        (c.address ?? '').isNotEmpty ||
        (c.notes ?? '').isNotEmpty ||
        c.birthday != null) {
      _showMoreFields = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nicknameController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ctrl = Provider.of<ContactsController>(context, listen: false);
    ctrl.clearMessages();

    final updated = widget.contact.copyWith(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      nickname: _nicknameController.text.trim().isEmpty
          ? null
          : _nicknameController.text.trim(),
      company: _companyController.text.trim().isEmpty
          ? null
          : _companyController.text.trim(),
      jobTitle: _jobTitleController.text.trim().isEmpty
          ? null
          : _jobTitleController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      birthday: _selectedBirthday,
    );

    final success = await ctrl.updateContact(updated);
    if (!mounted) return;

    final msg = success
        ? ctrl.successMessage ?? 'Contact updated.'
        : ctrl.errorMessage ?? 'Could not update contact.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : AppTheme.lightErrorColor,
      ),
    );

    if (success) Navigator.of(context).pop(updated);
  }

  Future<void> _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              ColorScheme.light(primary: AppTheme.lightPrimaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedBirthday = picked);
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
          'Edit Contact',
          style: TextStyle(
            color: AppTheme.lightTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Consumer<ContactsController>(
            builder: (_, ctrl, __) => TextButton(
              onPressed: ctrl.isLoading ? null : _save,
              child: ctrl.isLoading
                  ? const SizedBox(
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
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar placeholder
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.lightPrimaryColor,
                  backgroundImage: widget.contact.photoUrl != null
                      ? NetworkImage(widget.contact.photoUrl!)
                      : null,
                  child: widget.contact.photoUrl == null
                      ? Text(
                          widget.contact.name.isNotEmpty
                              ? widget.contact.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionTitle('Required Information'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _nameController,
                hintText: 'Full Name',
                prefixIcon: Icons.person_outline,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                hintText: 'Phone Number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a phone number';
                  if (v.replaceAll(RegExp(r'\D'), '').length < 7) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              InkWell(
                onTap: () => setState(() => _showMoreFields = !_showMoreFields),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showMoreFields ? 'Show Less' : 'More Details',
                      style: const TextStyle(
                        color: AppTheme.lightPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Icon(
                      _showMoreFields ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.lightPrimaryColor,
                    ),
                  ],
                ),
              ),

              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildSectionTitle('Additional Information'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nicknameController,
                      hintText: 'Nickname',
                      prefixIcon: Icons.face_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _companyController,
                      hintText: 'Company',
                      prefixIcon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _jobTitleController,
                      hintText: 'Job Title',
                      prefixIcon: Icons.work_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _addressController,
                      hintText: 'Address',
                      prefixIcon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildBirthdayPicker(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      hintText: 'Notes',
                      prefixIcon: Icons.notes_outlined,
                      maxLines: 3,
                    ),
                  ],
                ),
                crossFadeState: _showMoreFields
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.lightTextSecondary,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          prefixIcon: Icon(prefixIcon, color: AppTheme.lightTextSecondary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(fontSize: 15, color: AppTheme.lightTextPrimary),
      ),
    );
  }

  Widget _buildBirthdayPicker() {
    return InkWell(
      onTap: _selectBirthday,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: AppTheme.lightTextSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _selectedBirthday == null
                    ? 'Birthday'
                    : DateFormat('MMMM d, yyyy').format(_selectedBirthday!),
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedBirthday == null
                      ? Colors.grey.shade500
                      : AppTheme.lightTextPrimary,
                ),
              ),
            ),
            if (_selectedBirthday != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() => _selectedBirthday = null),
              ),
          ],
        ),
      ),
    );
  }
}
