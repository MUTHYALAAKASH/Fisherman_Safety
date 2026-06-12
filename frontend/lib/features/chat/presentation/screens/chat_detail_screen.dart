import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../map/services/location_service.dart';
import '../providers/chat_provider.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final int recipientId;
  final String recipientName;

  const ChatDetailScreen({
    Key? key,
    required this.recipientId,
    required this.recipientName,
  }) : super(key: key);

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(chatHistoryProvider(widget.recipientId));

    // Scroll to bottom once messages finish loading/updating
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.recipientName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Text(
              "Distress Failsafe Active",
              style: TextStyle(color: AppColors.aquamarine, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.marineGradient,
        ),
        child: Column(
          children: [
            // Chat history area
            Expanded(
              child: chatHistory.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.aquamarine),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    "Error loading messages: $err",
                    style: const TextStyle(color: AppColors.crimsonAlert),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_chat_read_rounded, color: AppColors.textMuted.withOpacity(0.4), size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            "No messages yet",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.recipientId == widget.recipientId;

                      if (msg.isSos) {
                        return _buildSosDistressCard(msg);
                      }

                      return _buildStandardBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),

            // Message writing bar
            _buildInputBar(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardBubble(ChatMessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.oceanBlue.withOpacity(0.85) : AppColors.cardNavy.withOpacity(0.9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
          border: Border.all(
            color: isMe ? AppColors.skyBlue.withOpacity(0.5) : AppColors.oceanNavy,
            width: 1,
          ),
        ),
        child: Text(
          msg.message,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildSosDistressCard(ChatMessageModel msg) {
    final lat = msg.latitude;
    final lon = msg.longitude;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.crimsonAlert.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.crimsonAlert, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.crimsonAlert.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.crimsonAlert, size: 28)
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15), duration: 800.ms),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🚨 ACTIVE SOS SIGNAL",
                        style: TextStyle(
                          color: AppColors.crimsonAlert,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        "Vessel coordinate broadcast",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.crimsonAlert, height: 20, thickness: 1),
            Text(
              msg.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (lat != null && lon != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGpsField("LATITUDE", lat.toStringAsFixed(6)),
                  const SizedBox(width: 16),
                  _buildGpsField("LONGITUDE", lon.toStringAsFixed(6)),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text("LOCATE SIGNAL ON MAP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.crimsonAlert,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Override map position to distress coordinate
                  ref.read(locationProvider.notifier).setManualPosition(LatLng(lat, lon));
                  // Route back to map view
                  context.go('/map');
                },
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildGpsField(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: AppColors.sunlightHighContrast, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildInputBar(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withOpacity(0.95),
        border: const Border(top: BorderSide(color: AppColors.oceanNavy, width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Type a secure message...",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardNavy,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.oceanBlue,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: () async {
                final txt = _messageController.text.trim();
                if (txt.isNotEmpty) {
                  _messageController.clear();
                  await ref.read(chatHistoryProvider(widget.recipientId).notifier).sendMessage(txt);
                  _scrollToBottom();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
