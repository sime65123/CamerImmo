import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final conversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId =
      Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('conversations')
        .select('''
          *,
          tenant:profiles!conversations_tenant_id_fkey(
            id, full_name, avatar_url, is_online),
          landlord:profiles!conversations_landlord_id_fkey(
            id, full_name, avatar_url, is_online),
          properties(id, title, monthly_rent)
        ''')
        .or('tenant_id.eq.$userId,landlord_id.eq.$userId')
        .order('updated_at', ascending: false);

    return (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (e) {
    debugPrint('Conversations fetch error: $e');
    return [];
  }
});

// ─── ConversationsScreen ──────────────────────────────────────────────────────

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState
    extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';
  int _selectedTab = 0;
  final List<String> _tabs = [
    'Tous',
    'Non lus',
    'Archivés'
  ];

  @override
  Widget build(BuildContext context) {
    final conversationsAsync =
        ref.watch(conversationsProvider);
    final userId =
        Supabase.instance.client.auth.currentUser?.id ??
            '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: conversationsAsync.when(
              loading: () => _ConversationsSkeleton(),
              error: (e, __) {
                debugPrint('Conv error: $e');
                return _EmptyConversations(
                    isFiltered: false);
              },
              data: (conversations) {
                List<Map<String, dynamic>> filtered =
                    conversations;

                if (_selectedTab == 1) {
                  filtered =
                      conversations.where((conv) {
                    final isTenant =
                        conv['tenant_id'] == userId;
                    final unread = isTenant
                        ? (conv['tenant_unread']
                                as int? ??
                            0)
                        : (conv['landlord_unread']
                                as int? ??
                            0);
                    return unread > 0;
                  }).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((conv) {
                    final lastMsg =
                        (conv['last_message']
                                    as String? ??
                                '')
                            .toLowerCase();
                    final tenant = conv['tenant']
                        as Map<String, dynamic>?;
                    final landlord = conv['landlord']
                        as Map<String, dynamic>?;
                    final tenantName =
                        (tenant?['full_name']
                                    as String? ??
                                '')
                            .toLowerCase();
                    final landlordName =
                        (landlord?['full_name']
                                    as String? ??
                                '')
                            .toLowerCase();
                    final q =
                        _searchQuery.toLowerCase();
                    return lastMsg.contains(q) ||
                        tenantName.contains(q) ||
                        landlordName.contains(q);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return _EmptyConversations(
                    isFiltered: _selectedTab != 0 ||
                        _searchQuery.isNotEmpty,
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(
                        conversationsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(
                      height: 1,
                      indent: 84,
                      endIndent: 20,
                    ),
                    itemBuilder: (context, index) =>
                        _ConversationTile(
                      conversation: filtered[index],
                      currentUserId: userId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user =
        Supabase.instance.client.auth.currentUser;
    final avatarUrl =
        user?.userMetadata?['avatar_url'] as String?;

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          Colors.white.withOpacity(0.2),
                      border: Border.all(
                          color: Colors.white
                              .withOpacity(0.5),
                          width: 2),
                    ),
                    child: avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                                avatarUrl,
                                fit: BoxFit.cover))
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'CamerImmo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        ref.invalidate(conversationsProvider),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (val) =>
                      setState(() => _searchQuery = val),
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                        'Rechercher une discussion...',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color:
                          Colors.white.withOpacity(0.6),
                    ),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.white
                            .withOpacity(0.7),
                        size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            vertical: 12),
                    filled: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20),
              child: Row(
                children: List.generate(
                  _tabs.length,
                  (index) => Padding(
                    padding:
                        const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _selectedTab = index),
                      child: AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == index
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedTab == index
                                ? Colors.white
                                : Colors.white
                                    .withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _selectedTab == index
                                ? AppColors.primary
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isTenant =
        conversation['tenant_id'] == currentUserId;

    final otherUser = isTenant
        ? conversation['landlord']
            as Map<String, dynamic>?
        : conversation['tenant']
            as Map<String, dynamic>?;

    final property = conversation['properties']
        as Map<String, dynamic>?;

    final otherName =
        otherUser?['full_name'] as String? ??
            'Utilisateur';
    final otherAvatar =
        otherUser?['avatar_url'] as String?;
    final isOnline =
        otherUser?['is_online'] as bool? ?? false;
    final propertyTitle =
        property?['title'] as String? ??
            'Bien immobilier';

    final unreadCount = isTenant
        ? (conversation['tenant_unread'] as int? ?? 0)
        : (conversation['landlord_unread'] as int? ?? 0);
    final lastMessage =
        conversation['last_message'] as String? ?? '';
    final lastMessageAt =
        conversation['last_message_at'] as String?;

    String timeLabel = '';
    if (lastMessageAt != null) {
      final diff = DateTime.now()
          .difference(DateTime.parse(lastMessageAt));
      if (diff.inMinutes < 60) {
        timeLabel = '${diff.inMinutes}min';
      } else if (diff.inHours < 24) {
        timeLabel =
            '${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
      } else {
        timeLabel = '${diff.inDays}j';
      }
    }

    return GestureDetector(
      onTap: () =>
          context.go('/chat/${conversation['id']}'),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceVariant,
                    border: unreadCount > 0
                        ? Border.all(
                            color: AppColors.primary,
                            width: 2)
                        : null,
                  ),
                  child: otherAvatar != null
                      ? ClipOval(
                          child: Image.network(
                            otherAvatar,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) =>
                                    const Icon(
                              Icons.person_rounded,
                              color:
                                  AppColors.textTertiary,
                              size: 26,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: AppColors.textTertiary,
                          size: 26,
                        ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.surface,
                            width: 2),
                      ),
                    ),
                  ),
                if (unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        otherName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: unreadCount > 0
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    propertyTitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (unreadCount == 0 &&
                          lastMessage.isNotEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.only(right: 4),
                          child: Icon(Icons.done_all,
                              size: 14,
                              color: AppColors.primary),
                        ),
                      Expanded(
                        child: Text(
                          lastMessage.isEmpty
                              ? 'Démarrer une conversation'
                              : lastMessage,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: unreadCount > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin:
                              const EdgeInsets.only(left: 8),
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9
                                  ? '9+'
                                  : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyConversations extends StatelessWidget {
  final bool isFiltered;
  const _EmptyConversations({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered
                ? 'Aucune conversation trouvée'
                : 'Pas encore de conversations',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Essayez de modifier vos filtres'
                : 'Contactez un propriétaire depuis\nla page d\'un bien pour commencer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/search'),
            child: const Text(
              'Explorer les biens',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _ConversationsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 84),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}