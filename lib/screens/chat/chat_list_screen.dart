import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/helpers.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadChatRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
            },
          ),
        ],
      ),
      body: _buildBody(chatProvider),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chatFab',
        onPressed: () {
          Navigator.pushNamed(context, AppConstants.newChatRoute);
        },
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }

  Widget _buildBody(ChatProvider chatProvider) {
    if (chatProvider.isLoading && chatProvider.chatRooms.isEmpty) {
      return const LoadingWidget();
    }

    if (chatProvider.chatRooms.isEmpty) {
      return EmptyStateWidget(
        title: 'No chats yet',
        subtitle: 'Start a conversation with someone',
        icon: Icons.chat_bubble_outline,
        action: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, AppConstants.newChatRoute);
          },
          icon: const Icon(Icons.add),
          label: const Text('New Chat'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: chatProvider.loadChatRooms,
      child: ListView.builder(
        itemCount: chatProvider.chatRooms.length,
        itemBuilder: (context, index) {
          final room = chatProvider.chatRooms[index];
          return _ChatRoomTile(
            room: room,
            onTap: () => _openChat(room),
          );
        },
      ),
    );
  }

  void _openChat(ChatRoomModel room) {
    context.read<ChatProvider>().openChatRoom(room);
    Navigator.pushNamed(context, AppConstants.chatRoomRoute);
  }
}

class _ChatRoomTile extends StatelessWidget {
  final ChatRoomModel room;
  final VoidCallback onTap;

  const _ChatRoomTile({
    required this.room,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final displayName = chatProvider.getRoomDisplayName(room);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          displayName[0].toUpperCase(),
          style: TextStyle(color: AppColors.primary),
        ),
      ),
      title: Text(displayName),
      subtitle: room.lastMessage != null
          ? Text(
              room.lastMessage!.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : const Text('No messages yet'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (room.lastMessage != null)
            Text(
              Helpers.timeAgo(room.lastMessage!.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (room.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                room.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
