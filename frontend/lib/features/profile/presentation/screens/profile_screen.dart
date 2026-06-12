import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/custom_button.dart';
import '../../../../shared/custom_textfield.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/contacts_provider.dart';
import 'package:fishermen_safety/features/chat/presentation/providers/chat_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _relationshipController = TextEditingController();
  SearchedUser? _selectedUser;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _addContact() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select a registered user account first.'),
          backgroundColor: AppColors.crimsonAlert,
        ),
      );
      return;
    }

    if (_relationshipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter relationship details.'),
          backgroundColor: AppColors.crimsonAlert,
        ),
      );
      return;
    }

    final success = await ref.read(contactsProvider.notifier).addContact(
      contactUserId: _selectedUser!.id,
      contactName: _selectedUser!.fullName,
      contactMobile: _selectedUser!.mobileNumber,
      relationship: _relationshipController.text.trim(),
    );

    if (success) {
      setState(() {
        _selectedUser = null;
        _searchController.clear();
        _searchQuery = '';
        _relationshipController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contact saved successfully!'),
          backgroundColor: AppColors.safetyGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save contact.'),
          backgroundColor: AppColors.crimsonAlert,
        ),
      );
    }
  }

  void _changeLanguage(String langCode) {
    setState(() {
      AppLocalizations.currentLanguage = langCode;
    });
  }

  void _showEditBoatDetailsDialog(UserModel? user) {
    final boatNameEditController = TextEditingController(text: user?.boatName ?? '');
    final regNumEditController = TextEditingController(text: user?.registrationNumber ?? '');
    final harborEditController = TextEditingController(text: user?.harborLocation ?? '');
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.oceanNavy, width: 2),
          ),
          title: const Text(
            "EDIT VESSEL DETAILS",
            style: TextStyle(
              color: AppColors.sunlightHighContrast,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    labelText: "Boat Name",
                    hintText: "Enter vessel name",
                    controller: boatNameEditController,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter boat name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    labelText: "Registration Number",
                    hintText: "Enter registration number",
                    controller: regNumEditController,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter registration number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    labelText: "Harbor / Port Location",
                    hintText: "Enter port/harbor",
                    controller: harborEditController,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter harbor location';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.oceanBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (dialogFormKey.currentState!.validate()) {
                  Navigator.pop(context);
                  
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Updating vessel details on server...'),
                      duration: Duration(seconds: 1),
                    ),
                  );

                  final success = await ref.read(authProvider.notifier).updateProfile(
                    fullName: user?.fullName ?? '',
                    mobileNumber: user?.mobileNumber ?? '',
                    email: user?.email,
                    boatName: boatNameEditController.text.trim(),
                    registrationNumber: regNumEditController.text.trim(),
                    harborLocation: harborEditController.text.trim(),
                  );

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vessel details updated successfully!'),
                        backgroundColor: AppColors.safetyGreen,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update vessel details.'),
                        backgroundColor: AppColors.crimsonAlert,
                      ),
                    );
                  }
                }
              },
              child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          AppLocalizations.translate('profile').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.marineGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fisherman Profile Badge
              Card(
                color: AppColors.cardNavy,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.oceanBlue.withOpacity(0.2),
                          border: Border.all(color: AppColors.aquamarine, width: 2),
                        ),
                        child: const Icon(Icons.anchor_rounded, color: AppColors.aquamarine, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Suresh Kumar',
                              style: const TextStyle(
                                color: AppColors.sunlightHighContrast,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user?.mobileNumber ?? '9876543210',
                              style: const TextStyle(color: AppColors.skyBlue, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Vessel Type: ${user?.role ?? "FISHERMAN"}',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Boat details Card
              Card(
                color: AppColors.cardNavy,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_boat_filled_outlined, color: AppColors.aquamarine, size: 22),
                              SizedBox(width: 8),
                              Text(
                                "REGISTERED BOAT DETAILS",
                                style: TextStyle(
                                  color: AppColors.sunlightHighContrast,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: AppColors.skyBlue, size: 20),
                            onPressed: () => _showEditBoatDetailsDialog(user),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.oceanNavy, height: 16),
                      _buildProfileRow(AppLocalizations.translate('boatName'), user?.boatName ?? 'No Boat Registered'),
                      const SizedBox(height: 12),
                      _buildProfileRow(AppLocalizations.translate('regNumber'), user?.registrationNumber ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildProfileRow(AppLocalizations.translate('harbor'), user?.harborLocation ?? 'N/A'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Dynamic Language Switching panel
              Card(
                color: AppColors.cardNavy,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language_rounded, color: AppColors.aquamarine, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.translate('changeLanguage').toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.sunlightHighContrast,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.oceanNavy, height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildLangChip("English", "en"),
                          _buildLangChip("தமிழ்", "ta"),
                          _buildLangChip("తెలుగు", "te"),
                          _buildLangChip("ಕನ್ನಡ", "kn"),
                          _buildLangChip("മലയാളം", "ml"),
                          _buildLangChip("हिन्दी", "hi"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Emergency Contact Manager
              Card(
                color: AppColors.cardNavy,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_alt_outlined, color: AppColors.aquamarine, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.translate('contacts').toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.sunlightHighContrast,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.oceanNavy, height: 24),
                        
                        // Contact entries list
                        contactsState.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: CircularProgressIndicator(color: AppColors.aquamarine),
                            ),
                          ),
                          error: (err, stack) => Center(
                            child: Text(
                              "Error loading contacts: $err",
                              style: const TextStyle(color: AppColors.crimsonAlert),
                            ),
                          ),
                          data: (contacts) {
                            if (contacts.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Text(
                                  "No emergency contacts registered.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: contacts.length,
                              separatorBuilder: (c, idx) => const Divider(color: AppColors.oceanNavy),
                              itemBuilder: (c, index) {
                                final ctc = contacts[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    ctc.contactName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    "${ctc.relationship ?? 'Contact'} | ${ctc.contactMobile}",
                                    style: const TextStyle(color: AppColors.textMuted),
                                  ),
                                  trailing: const Icon(Icons.contact_phone_outlined, color: AppColors.skyBlue),
                                );
                              },
                            );
                          },
                        ),
                        
                        const Divider(color: AppColors.oceanNavy, height: 24),
                        
                        // Search User bar
                        if (_selectedUser == null) ...[
                          CustomTextField(
                            labelText: 'Search Registered Accounts',
                            hintText: 'Search by name or mobile...',
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          if (_searchQuery.trim().isNotEmpty)
                            ref.watch(userSearchProvider(_searchQuery)).when(
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(color: AppColors.aquamarine),
                                  ),
                                  error: (err, stack) => const Text(
                                    "Error searching accounts",
                                    style: TextStyle(color: AppColors.crimsonAlert, fontSize: 12),
                                  ),
                                  data: (users) {
                                    if (users.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          "No registered users found matching query.",
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                        ),
                                      );
                                    }
                                     return Container(
                                       constraints: const BoxConstraints(maxHeight: 180),
                                       decoration: BoxDecoration(
                                         color: AppColors.oceanNavy,
                                         borderRadius: BorderRadius.circular(12),
                                         border: Border.all(color: AppColors.oceanBlue, width: 1),
                                       ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: users.length,
                                        separatorBuilder: (c, idx) => const Divider(color: AppColors.oceanBlue, height: 1),
                                        itemBuilder: (context, index) {
                                          final u = users[index];
                                          return ListTile(
                                            dense: true,
                                            title: Text(u.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            subtitle: Text("${u.role} • ${u.mobileNumber}", style: const TextStyle(color: AppColors.textMuted)),
                                            onTap: () {
                                              setState(() {
                                                _selectedUser = u;
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ] else ...[
                          // Selected Contact Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.skyBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.skyBlue, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.safetyGreen, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedUser!.fullName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        "${_selectedUser!.role} • ${_selectedUser!.mobileNumber}",
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.crimsonAlert),
                                  onPressed: () {
                                    setState(() {
                                      _selectedUser = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            labelText: 'Relationship (e.g. Wife, Son)',
                            hintText: 'Enter relationship',
                            controller: _relationshipController,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter relationship';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: "Register Emergency Contact",
                            color: AppColors.oceanBlue,
                            onPressed: _addContact,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Sign out actions
              CustomButton(
                text: AppLocalizations.translate('logout'),
                color: AppColors.crimsonAlert,
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) {
                    context.go(AppRouter.loginPath);
                  }
                },
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLangChip(String label, String code) {
    final isSelected = AppLocalizations.currentLanguage == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeLanguage(code),
      selectedColor: AppColors.aquamarine,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.deepNavy : Colors.white,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: AppColors.oceanNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
