import 'dart:convert';

import 'package:flutter/services.dart';

const videoCategoriesAsset = 'assets/data/video_categories.json';

class VideoCategory {
  const VideoCategory({
    required this.id,
    required this.title,
    required this.posts,
  });

  final String id;
  final String title;
  final List<VideoPost> posts;

  factory VideoCategory.fromJson(Map<String, dynamic> json) {
    final posts = json['posts'];

    return VideoCategory(
      id: json['category_id'] as String? ?? '',
      title: json['category_title'] as String? ?? '',
      posts: posts is List
          ? posts
                .whereType<Map<String, dynamic>>()
                .map(VideoPost.fromJson)
                .where((post) => post.thumbnailUrl != null)
                .toList(growable: false)
          : const [],
    );
  }
}

class VideoPost {
  const VideoPost({required this.id, required this.thumbnailUrl});

  final String id;
  final String? thumbnailUrl;

  factory VideoPost.fromJson(Map<String, dynamic> json) {
    final thumbnails = json['thumbnail_urls'];
    final thumbnailUrl = thumbnails is List && thumbnails.isNotEmpty
        ? thumbnails.first as String?
        : null;

    return VideoPost(
      id: json['post_id'] as String? ?? '',
      thumbnailUrl: thumbnailUrl,
    );
  }
}

Future<List<VideoCategory>> loadVideoCategories() async {
  final jsonString = await rootBundle.loadString(videoCategoriesAsset);
  final decoded = jsonDecode(jsonString);

  if (decoded is! List) return const [];

  return decoded
      .whereType<Map<String, dynamic>>()
      .map(VideoCategory.fromJson)
      .where((category) => category.posts.isNotEmpty)
      .toList(growable: false);
}
