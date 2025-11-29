import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../models/chat_model.dart';

class ChatService {
  final _client = SupabaseConfig.client;
  RealtimeChannel? _messagesChannel;

  Future<ChatRoomModel?> getOrCreateDirectChat(String otherUserId) async {
    try {
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId == null) throw Exception('User not authenticated');

      AppLogger.info('Getting/creating direct chat with: $otherUserId');
      final existingRooms = await _client
          .from(SupabaseConfig.chatRoomsTable)
          .select('''
            *,
            participants:${SupabaseConfig.chatParticipantsTable}(
              *,
              profiles(*)
            )
          ''')
          .eq('is_group', false);

      for (final room in existingRooms) {
        final participants = room['participants'] as List;
        if (participants.length == 2) {
          final userIds = participants.map((p) => p['user_id']).toSet();
          if (userIds.contains(currentUserId) && userIds.contains(otherUserId)) {
            AppLogger.success('Found existing chat room');
            return ChatRoomModel.fromJson(room);
          }
        }
      }

      AppLogger.debug('Creating new chat room');
      final roomResponse = await _client
          .from(SupabaseConfig.chatRoomsTable)
          .insert({
            'is_group': false,
            'created_by': currentUserId,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final roomId = roomResponse['id'];

      await _client.from(SupabaseConfig.chatParticipantsTable).insert([
        {
          'room_id': roomId,
          'user_id': currentUserId,
          'joined_at': DateTime.now().toIso8601String(),
        },
        {
          'room_id': roomId,
          'user_id': otherUserId,
          'joined_at': DateTime.now().toIso8601String(),
        },
      ]);

      final room = await _client
          .from(SupabaseConfig.chatRoomsTable)
          .select('''
            *,
            participants:${SupabaseConfig.chatParticipantsTable}(
              *,
              profiles(*)
            )
          ''')
          .eq('id', roomId)
          .single();

      AppLogger.success('Direct chat created: $roomId');
      return ChatRoomModel.fromJson(room);
    } catch (e) {
      AppLogger.error('Get or create direct chat error', e);
      rethrow;
    }
  }

  Future<ChatRoomModel?> createGroupChat({
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId == null) throw Exception('User not authenticated');

      AppLogger.info('Creating group chat: $name');
      final roomResponse = await _client
          .from(SupabaseConfig.chatRoomsTable)
          .insert({
            'name': name,
            'is_group': true,
            'created_by': currentUserId,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final roomId = roomResponse['id'];

      final allMembers = {...memberIds, currentUserId};
      await _client.from(SupabaseConfig.chatParticipantsTable).insert(
        allMembers.map((userId) => {
          'room_id': roomId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        }).toList(),
      );

      final room = await _client
          .from(SupabaseConfig.chatRoomsTable)
          .select('''
            *,
            participants:${SupabaseConfig.chatParticipantsTable}(
              *,
              profiles(*)
            )
          ''')
          .eq('id', roomId)
          .single();

      AppLogger.success('Group chat created: $roomId');
      return ChatRoomModel.fromJson(room);
    } catch (e) {
      AppLogger.error('Create group chat error', e);
      rethrow;
    }
  }

  Future<List<ChatRoomModel>> getChatRooms() async {
    try {
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId == null) return [];

      AppLogger.debug('Fetching chat rooms for: $currentUserId');
      final participantRooms = await _client
          .from(SupabaseConfig.chatParticipantsTable)
          .select('room_id')
          .eq('user_id', currentUserId);

      final roomIds = (participantRooms as List)
          .map((p) => p['room_id'] as String)
          .toList();

      if (roomIds.isEmpty) return [];

      final rooms = await _client
          .from(SupabaseConfig.chatRoomsTable)
          .select('''
            *,
            participants:${SupabaseConfig.chatParticipantsTable}(
              *,
              profiles(*)
            )
          ''')
          .inFilter('id', roomIds)
          .order('created_at', ascending: false);

      // Fetch last message for each room
      final roomsWithMessages = <ChatRoomModel>[];
      for (final roomJson in (rooms as List)) {
        try {
          // Get last message for this room
          final lastMessageQuery = await _client
              .from(SupabaseConfig.messagesTable)
              .select('*, profiles(*)')
              .eq('room_id', roomJson['id'])
              .order('created_at', ascending: false)
              .limit(1);
          
          if (lastMessageQuery.isNotEmpty) {
            roomJson['last_message'] = lastMessageQuery.first;
          }
          
          // Get unread count
          final unreadCount = await _client
              .from(SupabaseConfig.messagesTable)
              .select('id')
              .eq('room_id', roomJson['id'])
              .neq('sender_id', currentUserId)
              .eq('is_read', false)
              .count();
          
          roomJson['unread_count'] = unreadCount.count;
        } catch (e) {
          AppLogger.error('Error fetching room details', e);
        }
        
        roomsWithMessages.add(ChatRoomModel.fromJson(roomJson));
      }

      AppLogger.success('Fetched ${roomsWithMessages.length} chat rooms');
      return roomsWithMessages;
    } catch (e) {
      AppLogger.error('Get chat rooms error', e);
      return [];
    }
  }

  Future<List<MessageModel>> getMessages(String roomId, {int limit = 50}) async {
    try {
      AppLogger.debug('Fetching messages for room: $roomId');
      final response = await _client
          .from(SupabaseConfig.messagesTable)
          .select('''
            *,
            profiles(*)
          ''')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(limit);

      AppLogger.success('Fetched ${(response as List).length} messages');
      return (response)
          .map((json) => MessageModel.fromJson(json))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      AppLogger.error('Get messages error', e);
      return [];
    }
  }

  Future<MessageModel?> sendMessage({
    required String roomId,
    required String content,
    String messageType = 'text',
    String? fileUrl,
  }) async {
    try {
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId == null) throw Exception('User not authenticated');

      AppLogger.info('Sending message to room: $roomId');
      final response = await _client
          .from(SupabaseConfig.messagesTable)
          .insert({
            'room_id': roomId,
            'sender_id': currentUserId,
            'content': content,
            'message_type': messageType,
            'file_url': fileUrl,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('''
            *,
            profiles(*)
          ''')
          .single();

      AppLogger.success('Message sent');
      return MessageModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Send message error', e);
      rethrow;
    }
  }

  Stream<MessageModel> subscribeToMessages(String roomId) {
    final controller = StreamController<MessageModel>.broadcast();

    AppLogger.info('Subscribing to messages: $roomId');
    _messagesChannel = _client
        .channel('messages:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            try {
              final message = await _client
                  .from(SupabaseConfig.messagesTable)
                  .select('''
                    *,
                    profiles(*)
                  ''')
                  .eq('id', payload.newRecord['id'])
                  .single();

              AppLogger.debug('Realtime message received');
              controller.add(MessageModel.fromJson(message));
            } catch (e) {
              AppLogger.error('Error processing real-time message', e);
            }
          },
        )
        .subscribe();

    return controller.stream;
  }

  Future<void> markMessagesAsRead(String roomId) async {
    try {
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId == null) return;

      AppLogger.debug('Marking messages as read: $roomId');
      await _client
          .from(SupabaseConfig.messagesTable)
          .update({'is_read': true})
          .eq('room_id', roomId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);
    } catch (e) {
      AppLogger.error('Mark messages as read error', e);
    }
  }

  void unsubscribe() {
    AppLogger.debug('Unsubscribing from messages');
    _messagesChannel?.unsubscribe();
    _messagesChannel = null;
  }
}
