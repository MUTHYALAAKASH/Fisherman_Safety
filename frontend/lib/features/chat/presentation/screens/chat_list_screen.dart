import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../profile/presentation/providers/contacts_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          "EMERGENCY CHATS",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.marineGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card explaining Chat usage
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.skyBlue.withOpacity(0.3), width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security_rounded, color: AppColors.skyBlue, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Secure peer-to-peer distress communications. Coordinates are automatically sent here on SOS activation.",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              // Contacts list
              Expanded(
                child: contactsState.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.aquamarine),
                  ),
                  error: (error, stack) => Center(
                    child: Text(
                      "Error loading contacts: $error",
                      style: const TextStyle(color: AppColors.crimsonAlert),
                    ),
                  ),
                  data: (contacts) {
                    if (contacts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textMuted.withOpacity(0.5), size: 60),
                            const SizedBox(height: 16),
                            const Text(
                              "No active chats",
                              style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Search and add registered accounts as emergency contacts in your profile settings.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.settings_rounded),
                              label: const Text("Go to Profile"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.oceanBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                context.push('/profile');
                              },
                            ),
                          ],
                        ),
                      ).animate().fadeIn();
                    }

                    return ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final name = contact.contactName;
                        final relation = contact.relationship ?? 'Family';
                        final mobile = contact.contactMobile;
                        final contactId = contact.contactUserId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          color: AppColors.cardNavy.withOpacity(0.85),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.oceanNavy, width: 1.5),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (contactId != null) {
                                context.push('/chat/$contactId?name=${Uri.encodeComponent(name)}');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Cannot chat: Contact has no registered account ID"),
                                    backgroundColor: AppColors.crimsonAlert,
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppColors.activeAlertGradient,
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: AppColors.textWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "$relation • $mobile",
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Chat bubble icon
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.skyBlue,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().slideY(begin: 0.1, delay: (index * 80).ms);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
