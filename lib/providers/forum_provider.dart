import 'package:flutter/material.dart';
import '../models/forum_model.dart';
import '../services/forum_service.dart';
import '../core/utils/logger.dart';

class ForumProvider extends ChangeNotifier {
  final ForumService _forumService = ForumService();

  List<ForumPostModel> _posts = [];
  ForumPostModel? _currentPost;
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  String? _selectedCategory;
  String _searchQuery = '';

  List<ForumPostModel> get posts => _posts;
  ForumPostModel? get currentPost => _currentPost;
  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  Future<void> loadPosts({bool refresh = false}) async {
    if (refresh) {
      _posts = [];
      _hasMore = true;
    }

    if (!_hasMore || _isLoading) return;

    AppLogger.info('Loading posts (offset: ${_posts.length})');
    _isLoading = true;
    notifyListeners();

    try {
      const pageSize = 20; // Default limit from forum_service.dart
      final newPosts = await _forumService.getPosts(
        offset: _posts.length,
        category: _selectedCategory,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // If we got fewer posts than requested, we've reached the end
      if (newPosts.isEmpty || newPosts.length < pageSize) {
        _hasMore = false;
      }
      
      if (newPosts.isNotEmpty) {
        _posts.addAll(newPosts);
      }
      _error = null;
      AppLogger.success('Loaded ${newPosts.length} posts (hasMore: $_hasMore)');
    } catch (e) {
      AppLogger.error('Load posts failed', e);
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshPosts() async {
    AppLogger.info('Refreshing posts');
    await loadPosts(refresh: true);
  }

  void setCategory(String? category) {
    AppLogger.debug('Category changed: $category');
    _selectedCategory = category;
    loadPosts(refresh: true);
  }

  void setSearchQuery(String query) {
    AppLogger.debug('Search query: $query');
    _searchQuery = query;
    loadPosts(refresh: true);
  }

  Future<void> loadPost(String postId) async {
    AppLogger.info('Loading post: $postId');
    _isLoading = true;
    notifyListeners();

    try {
      _currentPost = await _forumService.getPost(postId);
      if (_currentPost != null) {
        await loadComments(postId);
      }
      _error = null;
      AppLogger.success('Post loaded: $postId');
    } catch (e) {
      AppLogger.error('Load post failed', e);
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadComments(String postId) async {
    AppLogger.debug('Loading comments for post: $postId');
    try {
      _comments = await _forumService.getComments(postId);
      _error = null;
      AppLogger.info('Loaded ${_comments.length} comments');
    } catch (e) {
      AppLogger.error('Load comments failed', e);
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<ForumPostModel?> createPost({
    required String title,
    required String content,
    String? category,
    List<String>? tags,
  }) async {
    AppLogger.info('Creating post: $title');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await _forumService.createPost(
        title: title,
        content: content,
        category: category,
        tags: tags,
      );

      if (post != null) {
        _posts.insert(0, post);
        AppLogger.success('Post created: ${post.id}');
      }

      _isLoading = false;
      notifyListeners();
      return post;
    } catch (e) {
      AppLogger.error('Create post failed', e);
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<ForumPostModel?> updatePost({
    required String postId,
    String? title,
    String? content,
    String? category,
    List<String>? tags,
  }) async {
    AppLogger.info('Updating post: $postId');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await _forumService.updatePost(
        postId: postId,
        title: title,
        content: content,
        category: category,
        tags: tags,
      );

      if (post != null) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _posts[index] = post;
        }
        if (_currentPost?.id == postId) {
          _currentPost = post;
        }
        AppLogger.success('Post updated: ${post.id}');
      }

      _isLoading = false;
      notifyListeners();
      return post;
    } catch (e) {
      AppLogger.error('Update post failed', e);
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> addComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    AppLogger.info('Adding comment to post: $postId');
    try {
      final comment = await _forumService.addComment(
        postId: postId,
        content: content,
        parentId: parentId,
      );

      if (comment != null) {
        _comments.add(comment);
        if (_currentPost != null) {
          _currentPost = _currentPost!.copyWith(
            commentCount: _currentPost!.commentCount + 1,
          );
        }
        AppLogger.success('Comment added: ${comment.id}');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Add comment failed', e);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> voteOnPost(String postId, bool isUpvote) async {
    AppLogger.debug('Voting on post: $postId (up: $isUpvote)');
    try {
      await _forumService.voteOnPost(postId, isUpvote ? 'up' : 'down');
      
      // Optimistically update UI
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final currentUserVote = post.userVote;
        
        // Calculate new vote counts based on voting logic
        int newUpvotes = post.upvotes;
        int newDownvotes = post.downvotes;
        int? newUserVote;
        
        if (isUpvote) {
          if (currentUserVote == 1) {
            // Remove upvote
            newUpvotes--;
            newUserVote = null;
          } else if (currentUserVote == -1) {
            // Change from downvote to upvote
            newUpvotes++;
            newDownvotes--;
            newUserVote = 1;
          } else {
            // Add new upvote
            newUpvotes++;
            newUserVote = 1;
          }
        }
        
        _posts[index] = post.copyWith(
          upvotes: newUpvotes,
          downvotes: newDownvotes,
          userVote: newUserVote,
        );
      }

      if (_currentPost?.id == postId) {
        final post = _currentPost!;
        final currentUserVote = post.userVote;
        
        int newUpvotes = post.upvotes;
        int newDownvotes = post.downvotes;
        int? newUserVote;
        
        if (isUpvote) {
          if (currentUserVote == 1) {
            newUpvotes--;
            newUserVote = null;
          } else if (currentUserVote == -1) {
            newUpvotes++;
            newDownvotes--;
            newUserVote = 1;
          } else {
            newUpvotes++;
            newUserVote = 1;
          }
        }
        
        _currentPost = post.copyWith(
          upvotes: newUpvotes,
          downvotes: newDownvotes,
          userVote: newUserVote,
        );
      }

      AppLogger.success('Vote recorded on post');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Vote on post failed', e);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> voteOnComment(String commentId, bool isUpvote) async {
    AppLogger.debug('Voting on comment: $commentId (up: $isUpvote)');
    try {
      await _forumService.voteOnComment(commentId, isUpvote ? 'up' : 'down');
      
      final index = _comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        final comment = _comments[index];
        _comments[index] = comment.copyWith(
          upvotes: isUpvote ? comment.upvotes + 1 : comment.upvotes,
          downvotes: !isUpvote ? comment.downvotes + 1 : comment.downvotes,
          userVote: isUpvote ? 1 : -1,
        );
        AppLogger.success('Vote recorded on comment');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Vote on comment failed', e);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markBestAnswer(String postId, String commentId) async {
    AppLogger.info('Marking best answer: $commentId');
    try {
      await _forumService.markBestAnswer(postId, commentId);
      
      for (int i = 0; i < _comments.length; i++) {
        _comments[i] = _comments[i].copyWith(
          isBestAnswer: _comments[i].id == commentId,
        );
      }
      AppLogger.success('Best answer marked');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Mark best answer failed', e);
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearCurrentPost() {
    _currentPost = null;
    _comments = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
