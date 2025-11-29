import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../models/forum_model.dart';

class ForumService {
  final _client = SupabaseConfig.client;

  Future<List<ForumPostModel>> getPosts({
    int limit = 20,
    int offset = 0,
    String? category,
    String? searchQuery,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      AppLogger.debug('Fetching posts (limit: $limit, offset: $offset)');
      var query = _client
          .from(SupabaseConfig.forumPostsTable)
          .select('''
            *,
            profiles(*),
            comment_count:${SupabaseConfig.forumCommentsTable}(count)
          ''');

      if (category != null) {
        query = query.eq('category', category);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('title.ilike.%$searchQuery%,content.ilike.%$searchQuery%');
      }

      final response = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      AppLogger.success('Fetched ${(response as List).length} posts');
      
      // Fetch user votes for all posts
      List<String> postIds = (response as List).map((p) => p['id'] as String).toList();
      Map<String, int> userVotes = {};
      
      if (userId != null && postIds.isNotEmpty) {
        try {
          final votesResponse = await _client
              .from(SupabaseConfig.votesTable)
              .select('post_id, vote_type')
              .eq('user_id', userId)
              .inFilter('post_id', postIds);
          
          for (var vote in votesResponse) {
            userVotes[vote['post_id']] = vote['vote_type'] == 'up' ? 1 : -1;
          }
        } catch (e) {
          AppLogger.warning('Failed to fetch user votes', e);
        }
      }
      
      return (response).map((json) {
        if (json['comment_count'] is List && (json['comment_count'] as List).isNotEmpty) {
          json['comment_count'] = json['comment_count'][0]['count'];
        } else {
          json['comment_count'] = 0;
        }
        
        // Add user vote if exists
        if (userVotes.containsKey(json['id'])) {
          json['user_vote'] = userVotes[json['id']];
        }
        
        return ForumPostModel.fromJson(json);
      }).toList();
    } catch (e) {
      AppLogger.error('Get posts error', e);
      return [];
    }
  }

  Future<ForumPostModel?> getPost(String postId) async {
    try {
      AppLogger.debug('Fetching post: $postId');
      final response = await _client
          .from(SupabaseConfig.forumPostsTable)
          .select('''
            *,
            profiles(*)
          ''')
          .eq('id', postId)
          .single();

      await _client
          .from(SupabaseConfig.forumPostsTable)
          .update({'view_count': response['view_count'] + 1})
          .eq('id', postId);

      AppLogger.success('Post fetched: $postId');
      return ForumPostModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Get post error', e);
      return null;
    }
  }

  Future<ForumPostModel?> createPost({
    required String title,
    required String content,
    String? category,
    List<String>? tags,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      AppLogger.info('Creating post: $title');
      final response = await _client
          .from(SupabaseConfig.forumPostsTable)
          .insert({
            'author_id': userId,
            'title': title,
            'content': content,
            'category': category,
            'tags': tags,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('''
            *,
            profiles(*)
          ''')
          .single();

      AppLogger.success('Post created');
      return ForumPostModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Create post error', e);
      rethrow;
    }
  }

  Future<ForumPostModel?> updatePost({
    required String postId,
    String? title,
    String? content,
    String? category,
    List<String>? tags,
  }) async {
    try {
      AppLogger.info('Updating post: $postId');
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (category != null) updates['category'] = category;
      if (tags != null) updates['tags'] = tags;

      final response = await _client
          .from(SupabaseConfig.forumPostsTable)
          .update(updates)
          .eq('id', postId)
          .select('''
            *,
            profiles(*)
          ''')
          .single();

      AppLogger.success('Post updated');
      return ForumPostModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Update post error', e);
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      AppLogger.info('Deleting post: $postId');
      await _client
          .from(SupabaseConfig.forumPostsTable)
          .delete()
          .eq('id', postId);
      AppLogger.success('Post deleted');
    } catch (e) {
      AppLogger.error('Delete post error', e);
      rethrow;
    }
  }

  Future<List<CommentModel>> getComments(String postId) async {
    try {
      AppLogger.debug('Fetching comments for post: $postId');
      final response = await _client
          .from(SupabaseConfig.forumCommentsTable)
          .select('''
            *,
            profiles(*)
          ''')
          .eq('post_id', postId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: true);

      AppLogger.success('Fetched ${(response as List).length} comments');
      return (response).map((json) => CommentModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Get comments error', e);
      return [];
    }
  }

  Future<CommentModel?> addComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      AppLogger.info('Adding comment to post: $postId');
      final response = await _client
          .from(SupabaseConfig.forumCommentsTable)
          .insert({
            'post_id': postId,
            'author_id': userId,
            'parent_id': parentId,
            'content': content,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('''
            *,
            profiles(*)
          ''')
          .single();

      AppLogger.success('Comment added');
      return CommentModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Add comment error', e);
      rethrow;
    }
  }

  Future<void> voteOnPost(String postId, String voteType) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      AppLogger.debug('Voting on post: $postId ($voteType)');
      final existing = await _client
          .from(SupabaseConfig.votesTable)
          .select()
          .eq('user_id', userId)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        if (existing['vote_type'] == voteType) {
          await _client
              .from(SupabaseConfig.votesTable)
              .delete()
              .eq('id', existing['id']);
          
          final field = voteType == 'up' ? 'upvotes' : 'downvotes';
          await _client.rpc('decrement_$field', params: {'row_id': postId});
        } else {
          await _client
              .from(SupabaseConfig.votesTable)
              .update({'vote_type': voteType})
              .eq('id', existing['id']);
          
          if (voteType == 'up') {
            await _client.rpc('increment_upvotes', params: {'row_id': postId});
            await _client.rpc('decrement_downvotes', params: {'row_id': postId});
          } else {
            await _client.rpc('increment_downvotes', params: {'row_id': postId});
            await _client.rpc('decrement_upvotes', params: {'row_id': postId});
          }
        }
      } else {
        await _client.from(SupabaseConfig.votesTable).insert({
          'user_id': userId,
          'post_id': postId,
          'vote_type': voteType,
          'created_at': DateTime.now().toIso8601String(),
        });

        final field = voteType == 'up' ? 'upvotes' : 'downvotes';
        await _client.rpc('increment_$field', params: {'row_id': postId});
      }
      AppLogger.success('Vote recorded');
    } catch (e) {
      AppLogger.error('Vote on post error', e);
      rethrow;
    }
  }

  Future<void> voteOnComment(String commentId, String voteType) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      AppLogger.debug('Voting on comment: $commentId ($voteType)');
      final existing = await _client
          .from(SupabaseConfig.votesTable)
          .select()
          .eq('user_id', userId)
          .eq('comment_id', commentId)
          .maybeSingle();

      if (existing != null) {
        if (existing['vote_type'] == voteType) {
          await _client
              .from(SupabaseConfig.votesTable)
              .delete()
              .eq('id', existing['id']);
        } else {
          await _client
              .from(SupabaseConfig.votesTable)
              .update({'vote_type': voteType})
              .eq('id', existing['id']);
        }
      } else {
        await _client.from(SupabaseConfig.votesTable).insert({
          'user_id': userId,
          'comment_id': commentId,
          'vote_type': voteType,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      AppLogger.success('Comment vote recorded');
    } catch (e) {
      AppLogger.error('Vote on comment error', e);
      rethrow;
    }
  }

  Future<void> markBestAnswer(String postId, String commentId) async {
    try {
      AppLogger.info('Marking best answer: $commentId');
      await _client
          .from(SupabaseConfig.forumCommentsTable)
          .update({'is_best_answer': false})
          .eq('post_id', postId);

      await _client
          .from(SupabaseConfig.forumCommentsTable)
          .update({'is_best_answer': true})
          .eq('id', commentId);

      AppLogger.success('Best answer marked');
    } catch (e) {
      AppLogger.error('Mark best answer error', e);
      rethrow;
    }
  }
}
