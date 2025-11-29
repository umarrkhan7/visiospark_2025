import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';

class DashboardService {
  final _client = SupabaseConfig.client;

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      AppLogger.debug('Fetching dashboard stats for: $userId');

      // Get forum posts count
      final postsCount = await _client
          .from(SupabaseConfig.forumPostsTable)
          .select('id')
          .eq('author_id', userId)
          .count();

      // Get messages count
      final messagesCount = await _client
          .from(SupabaseConfig.messagesTable)
          .select('id')
          .eq('sender_id', userId)
          .count();

      // Get AI conversations count (from ai_messages table if exists, or use estimate)
      int aiQueriesCount = 0;
      try {
        final aiCount = await _client
            .from('ai_messages')
            .select('id')
            .eq('user_id', userId)
            .count();
        aiQueriesCount = aiCount.count;
      } catch (e) {
        // ai_messages table might not exist, use 0
        aiQueriesCount = 0;
      }

      // Get chat rooms count (connections)
      final chatRooms = await _client
          .from(SupabaseConfig.chatParticipantsTable)
          .select('room_id')
          .eq('user_id', userId);
      
      final chatRoomsList = chatRooms as List<dynamic>?;
      final connectionsCount = chatRoomsList?.length ?? 0;

      // Get weekly activity (posts + messages per day for last 7 days)
      final weeklyActivity = await _getWeeklyActivity(userId);

      // Get recent activity
      final recentActivity = await getRecentActivity();

      // Get activity distribution
      final distribution = {
        'posts': postsCount.count,
        'chats': messagesCount.count,
        'ai': aiQueriesCount,
      };

      AppLogger.success('Dashboard stats fetched');

      return {
        'totalPosts': postsCount.count,
        'totalMessages': messagesCount.count,
        'aiQueries': aiQueriesCount,
        'connections': connectionsCount,
        'weeklyActivity': weeklyActivity,
        'distribution': distribution,
        'recentActivity': recentActivity,
      };
    } catch (e) {
      AppLogger.error('Get dashboard stats error', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getWeeklyActivity(String userId) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      // Get posts per day
      final posts = await _client
          .from(SupabaseConfig.forumPostsTable)
          .select('created_at')
          .eq('author_id', userId)
          .gte('created_at', weekAgo.toIso8601String());

      // Get messages per day
      final messages = await _client
          .from(SupabaseConfig.messagesTable)
          .select('created_at')
          .eq('sender_id', userId)
          .gte('created_at', weekAgo.toIso8601String());

      // Group by day
      final activityByDay = <String, int>{};
      final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      // Initialize all days to 0
      for (var i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: 6 - i));
        final dayName = daysOfWeek[day.weekday - 1];
        activityByDay[dayName] = 0;
      }

      // Count posts - handle null response
      final postsList = posts as List<dynamic>?;
      if (postsList != null) {
        for (final post in postsList) {
          final date = DateTime.parse(post['created_at'] as String);
          final dayName = daysOfWeek[date.weekday - 1];
          activityByDay[dayName] = (activityByDay[dayName] ?? 0) + 1;
        }
      }

      // Count messages - handle null response
      final messagesList = messages as List<dynamic>?;
      if (messagesList != null) {
        for (final message in messagesList) {
          final date = DateTime.parse(message['created_at'] as String);
          final dayName = daysOfWeek[date.weekday - 1];
          activityByDay[dayName] = (activityByDay[dayName] ?? 0) + 1;
        }
      }

      // Convert to list
      return daysOfWeek.map((day) {
        return {'label': day, 'value': activityByDay[day] ?? 0};
      }).toList();
    } catch (e) {
      AppLogger.error('Get weekly activity error', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return [];

      AppLogger.debug('Fetching recent activity');

      // Get recent posts
      final recentPosts = await _client
          .from(SupabaseConfig.forumPostsTable)
          .select('id, title, created_at')
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      // Combine and sort by time
      final activities = <Map<String, dynamic>>[];

      final postsList = recentPosts as List<dynamic>?;
      if (postsList != null) {
        for (final post in postsList) {
          activities.add({
            'title': 'Posted: ${post['title']}',
            'time': _formatTimeAgo(DateTime.parse(post['created_at'] as String)),
            'icon': 'article',
            'type': 'post',
          });
        }
      }

      AppLogger.success('Recent activity fetched');
      return activities.take(5).toList();
    } catch (e) {
      AppLogger.error('Get recent activity error', e);
      return [];
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
