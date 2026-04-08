import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/contacts_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/local_contact_model.dart';
import 'add_contact_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactsController>(context, listen: false).loadContacts();
    });
  }

  void _confirmRemove(LocalContact contact) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text('Remove ${contact.name} from your contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ContactsController>(
                context,
                listen: false,
              ).removeContact(contact.id);
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppTheme.lightErrorColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactsController>(
      builder: (context, ctrl, _) {
        if (ctrl.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.lightPrimaryColor,
              ),
            ),
          );
        }

        if (ctrl.contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.contacts_outlined,
                  size: 64,
                  color: AppTheme.lightTextSecondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No contacts yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Save a contact\'s name and phone number.\nIf they use this app, you can chat with them.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddContactScreen()),
                  ).then((_) => ctrl.loadContacts()),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: ctrl.contacts.length,
          itemBuilder: (context, index) {
            final contact = ctrl.contacts[index];
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.lightPrimaryColor,
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                contact.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                contact.phone,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.lightErrorColor,
                ),
                onPressed: () => _confirmRemove(contact),
              ),
            );
          },
        );
      },
    );
  }
}
