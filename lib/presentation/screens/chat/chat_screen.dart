import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final messagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, conversationId) {
  return Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true)
      .map((data) => data
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
});

final conversationDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, conversationId) async {
  final response = await Supabase.instance.client
      .from('conversations')
      .select('''
        *,
        properties(title, monthly_rent, neighborhood, city,
          property_images(url, is_primary)),
        tenant:profiles!conversations_tenant_id_fkey(
          id, full_name, avatar_url, is_online, last_seen),
        landlord:profiles!conversations_landlord_id_fkey(
          id, full_name, avatar_url, is_online, last_seen)
      ''')
      .eq('id', conversationId)
      .maybeSingle();
  return response as Map<String, dynamic>?;
});

// ─── ChatScreen ───────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await Supabase.instance.client.functions.invoke(
        'send_message',
        body: {
          'conversation_id': widget.conversationId,
          'content': content,
          'message_type': 'texte',
        },
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send message error: $e');
      // Fallback — insertion directe
      try {
        await Supabase.instance.client
            .from('messages')
            .insert({
          'conversation_id': widget.conversationId,
          'sender_id': _currentUserId,
          'content': content,
          'message_type': 'texte',
        });
        _scrollToBottom();
      } catch (e2) {
        debugPrint('Direct insert error: $e2');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Erreur d\'envoi. Réessayez.',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // Marquer messages comme lus
  Future<void> _markAsRead() async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', widget.conversationId)
          .neq('sender_id', _currentUserId)
          .eq('is_read', false);

      // Reset unread count
      final conv = await Supabase.instance.client
          .from('conversations')
          .select('tenant_id, landlord_id')
          .eq('id', widget.conversationId)
          .maybeSingle();

      if (conv != null) {
        final isTenant = conv['tenant_id'] == _currentUserId;
        await Supabase.instance.client
            .from('conversations')
            .update(
              isTenant
                  ? {'tenant_unread': 0}
                  : {'landlord_unread': 0},
            )
            .eq('id', widget.conversationId);
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final convAsync = ref.watch(
      conversationDetailProvider(widget.conversationId),
    );
    final messagesAsync = ref.watch(
      messagesProvider(widget.conversationId),
    );

    // Marquer comme lu à l'ouverture
    _markAsRead();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: convAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
        error: (e, __) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: const Text('Chat'),
          ),
          body: const Center(child: Text('Erreur')),
        ),
        data: (conversation) {
          if (conversation == null) {
            return const Center(
              child: Text('Conversation introuvable'),
            );
          }

          final isTenant =
              conversation['tenant_id'] == _currentUserId;
          final otherUser = isTenant
              ? conversation['landlord'] as Map<String, dynamic>?
              : conversation['tenant'] as Map<String, dynamic>?;

          final otherName =
              otherUser?['full_name'] as String? ??
                  'Utilisateur';
          final otherAvatar =
              otherUser?['avatar_url'] as String?;
          final isOnline =
              otherUser?['is_online'] as bool? ?? false;
          final property =
              conversation['properties'] as Map<String, dynamic>?;

          return Column(
            children: [
              // Header
              _buildHeader(
                context: context,
                name: otherName,
                avatarUrl: otherAvatar,
                isOnline: isOnline,
                lastSeen: otherUser?['last_seen'] as String?,
              ),

              // Card bien en cours
              if (property != null)
                _PropertyContextCard(property: property),

              // Messages
              Expanded(
                child: messagesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                  error: (e, __) {
                    debugPrint('Messages error: $e');
                    return const Center(
                      child: Text('Erreur de chargement'),
                    );
                  },
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const _EmptyChat();
                    }

                    _scrollToBottom();

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message['sender_id'] ==
                            _currentUserId;

                        // Afficher date si changement de jour
                        final showDate = index == 0 ||
                            _isDifferentDay(
                              messages[index - 1]['created_at']
                                  as String,
                              message['created_at'] as String,
                            );

                        return Column(
                          children: [
                            if (showDate)
                              _DateSeparator(
                                date: message['created_at']
                                    as String,
                              ),
                            _MessageBubble(
                              message: message,
                              isMe: isMe,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Suggestions rapides
              _QuickReplies(
                onTap: (text) {
                  _messageController.text = text;
                },
              ),

              // Zone de saisie
              _MessageInput(
                controller: _messageController,
                isSending: _isSending,
                onSend: _sendMessage,
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isDifferentDay(String date1, String date2) {
    final d1 = DateTime.parse(date1);
    final d2 = DateTime.parse(date2);
    return d1.day != d2.day ||
        d1.month != d2.month ||
        d1.year != d2.year;
  }

  Widget _buildHeader({
    required BuildContext context,
    required String name,
    required String? avatarUrl,
    required bool isOnline,
    required String? lastSeen,
  }) {
    String statusText = 'Hors ligne';
    if (isOnline) {
      statusText = 'En ligne';
    } else if (lastSeen != null) {
      final diff = DateTime.now()
          .difference(DateTime.parse(lastSeen));
      if (diff.inMinutes < 60) {
        statusText = 'Vu il y a ${diff.inMinutes}min';
      } else if (diff.inHours < 24) {
        statusText = 'Vu il y a ${diff.inHours}h';
      } else {
        statusText = 'Vu il y a ${diff.inDays}j';
      }
    }

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
          child: Row(
            children: [
              // Retour
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () => context.pop(),
              ),

              // Avatar
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 10),

              // Nom + statut
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: isOnline
                            ? AppColors.successLight
                            : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: const Icon(
                  Icons.call_outlined,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card bien en discussion ──────────────────────────────────────────────────

class _PropertyContextCard extends StatelessWidget {
  final Map<String, dynamic> property;
  const _PropertyContextCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final images = property['property_images'] as List?;
    String imageUrl = '';
    if (images != null && images.isNotEmpty) {
      final primary = images.firstWhere(
        (img) => (img as Map)['is_primary'] == true,
        orElse: () => images.first,
      );
      imageUrl = (primary as Map)['url'] as String? ?? '';
    }

    final rent = property['monthly_rent'] as num? ?? 0;
    final rentFormatted = rent
        .toInt()
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Étiquette
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'EN COURS DE DISCUSSION',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Image miniature
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.home_rounded,
                      color: AppColors.border),
                ),
              ),
            ),

          const SizedBox(width: 10),

          // Titre + prix
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['title'] as String? ?? '',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$rentFormatted FCFA / mois',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final messageType =
        message['message_type'] as String? ?? 'texte';
    final createdAt = message['created_at'] as String?;
    final isRead = message['is_read'] as bool? ?? false;
    final mediaUrl = message['media_url'] as String?;

    String timeLabel = '';
    if (createdAt != null) {
      final dt = DateTime.parse(createdAt).toLocal();
      timeLabel =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 8),

          // Bulle
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: messageType == 'image'
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Contenu selon type
                  if (messageType == 'image' &&
                      mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Text(
                      content,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: isMe
                            ? Colors.white
                            : AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Heure + statut lu
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textTertiary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: isRead
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Séparateur de date ───────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(date).toLocal();
    final now = DateTime.now();
    String label;

    if (dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year) {
      label = "Aujourd'hui";
    } else if (dt.day == now.day - 1) {
      label = 'Hier';
    } else {
      label =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.borderLight),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.borderLight),
          ),
        ],
      ),
    );
  }
}

// ─── Suggestions rapides ──────────────────────────────────────────────────────

class _QuickReplies extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _QuickReplies({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Toujours disponible?',
      'Quelles sont les modalités ?',
      'Puis-je visiter ce week-end ?',
    ];

    return Container(
      height: 40,
      color: AppColors.background,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onTap(suggestions[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: index == 0
                    ? AppColors.primaryLight
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: index == 0
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.border,
                ),
              ),
              child: Text(
                suggestions[index],
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: index == 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Zone de saisie ───────────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bouton pièce jointe
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Champ texte
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  filled: false,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Bouton appareil photo
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Bouton envoi
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSending
                    ? AppColors.primary.withOpacity(0.6)
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Chat ───────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'CONVERSATION DÉMARRÉE',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Envoyez un message pour commencer',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}