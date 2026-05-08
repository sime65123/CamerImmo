import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final conversationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return Supabase.instance.client
      .from('conversations')
      .stream(primaryKey: ['id'])
      .order('updated_at', ascending: false)
      .map((data) => data
          .where((conv) =>
              conv['tenant_id'] == userId ||
              conv['landlord_id'] == userId)
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
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
  final List<String> _tabs = ['Tous', 'Non lus', 'Archivés'];

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Corps
          Expanded(
            child: conversationsAsync.when(
              loading: () => _ConversationsSkeleton(),
              error: (e, __) {
                debugPrint('Conversations error: $e');
                return const Center(
                  child: Text(
                    'Erreur de chargement',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                );
              },
              data: (conversations) {
                // Filtrer selon onglet et recherche
                List<Map<String, dynamic>> filtered =
                    conversations;

                if (_selectedTab == 1) {
                  // Non lus
                  filtered = conversations.where((conv) {
                    final isTenant =
                        conv['tenant_id'] == userId;
                    final unread = isTenant
                        ? (conv['tenant_unread'] as int? ?? 0)
                        : (conv['landlord_unread'] as int? ?? 0);
                    return unread > 0;
                  }).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((conv) {
                    final lastMsg =
                        (conv['last_message'] as String? ?? '')
                            .toLowerCase();
                    return lastMsg
                        .contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return _EmptyConversations(
                    isFiltered: _selectedTab != 0 ||
                        _searchQuery.isNotEmpty,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 84,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    return _ConversationTile(
                      conversation: filtered[index],
                      currentUserId: userId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Titre + bouton nouveau
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 12, 12, 0),
              child: Row(
                children: [
                  // Avatar
                  _buildAvatar(),
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

                  // Cloche notifs
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Titre Messages + bouton +
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 8, 20, 0),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_comment_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Barre de recherche
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
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une discussion...',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    filled: false,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Onglets
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20),
              child: Row(
                children: List.generate(
                  _tabs.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _selectedTab = index),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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

  Widget _buildAvatar() {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl =
        user?.userMetadata?['avatar_url'] as String?;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: avatarUrl != null
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 18,
            ),
    );
  }
}

// ─── Tile de conversation ─────────────────────────────────────────────────────

class _ConversationTile extends ConsumerWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTenant =
        conversation['tenant_id'] == currentUserId;
    final otherUserId = isTenant
        ? conversation['landlord_id'] as String? ?? ''
        : conversation['tenant_id'] as String? ?? '';
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

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchOtherUser(otherUserId),
      builder: (context, snapshot) {
        final otherUser = snapshot.data;
        final otherName =
            otherUser?['full_name'] as String? ??
                'Utilisateur';
        final otherAvatar =
            otherUser?['avatar_url'] as String?;

        return GestureDetector(
          onTap: () => context.go(
            '/chat/${conversation['id']}',
          ),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
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
                                width: 2,
                              )
                            : null,
                      ),
                      child: otherAvatar != null
                          ? ClipOval(
                              child: Image.network(
                                otherAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.textTertiary,
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
                    // Point non lu
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

                      // Titre du bien
                      FutureBuilder<String>(
                        future: _fetchPropertyTitle(
                          conversation['property_id']
                                  as String? ??
                              '',
                        ),
                        builder: (context, snap) {
                          return Text(
                            snap.data ?? 'Bien immobilier',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),

                      const SizedBox(height: 3),

                      Row(
                        children: [
                          // Double coche si lu
                          if (unreadCount == 0 &&
                              lastMessage.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.done_all,
                                size: 14,
                                color: AppColors.primary,
                              ),
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

                          // Badge nb non lus
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(
                                  left: 8),
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
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchOtherUser(
      String userId) async {
    if (userId.isEmpty) return null;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url, is_online')
          .eq('id', userId)
          .maybeSingle();
      return response as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<String> _fetchPropertyTitle(
      String propertyId) async {
    if (propertyId.isEmpty) return 'Bien immobilier';
    try {
      final response = await Supabase.instance.client
          .from('properties')
          .select('title')
          .eq('id', propertyId)
          .maybeSingle();
      return (response as Map<String, dynamic>?)?['title']
              as String? ??
          'Bien immobilier';
    } catch (e) {
      return 'Bien immobilier';
    }
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
                : 'Plus de conversations récentes',
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
                : 'Commencez à discuter avec les\npropriétaires pour concrétiser\nvos projets immo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
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
          horizontal: 20,
          vertical: 14,
        ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
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