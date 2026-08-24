class ThemeCatalogResponse {
  const ThemeCatalogResponse({
    required this.success,
    required this.message,
    required this.categories,
    required this.total,
  });

  factory ThemeCatalogResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) {
      throw const FormatException('Theme response does not contain data.');
    }
    final categories = data['categories'];
    if (categories is! List) {
      throw const FormatException(
        'Theme response does not contain categories.',
      );
    }

    return ThemeCatalogResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      categories: categories
          .whereType<Map>()
          .map(
            (item) => VideoCategory.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((category) => category.posts.isNotEmpty)
          .toList(growable: false),
      total: _asInt(data['total']),
    );
  }

  final bool success;
  final String message;
  final List<VideoCategory> categories;
  final int total;
}

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
    final themes = json['themes'];
    final posts = themes is List
        ? themes
              .whereType<Map>()
              .map(
                (item) => VideoPost.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((post) => post.thumbnailUrl != null)
              .toList(growable: false)
        : <VideoPost>[];
    posts.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

    return VideoCategory(
      id: json['category_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      posts: posts,
    );
  }
}

class VideoPost {
  const VideoPost({
    required this.id,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.description,
    this.themeKey = '',
    this.serviceType = '',
    this.sortOrder = 0,
  });

  final String id;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String description;
  final String themeKey;
  final String serviceType;
  final int sortOrder;

  factory VideoPost.fromJson(Map<String, dynamic> json) {
    final themeKey = json['theme_key']?.toString() ?? '';
    final rawId = json['id']?.toString() ?? '';
    final thumbnailUrl = _nonEmptyString(json['thumbnail_url']);
    final videoUrl = _nonEmptyString(json['preview_video_url']);

    return VideoPost(
      id: themeKey.isEmpty ? rawId : themeKey,
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      description: json['name']?.toString() ?? 'AI video template',
      themeKey: themeKey,
      serviceType: json['service_type']?.toString() ?? '',
      sortOrder: _asInt(json['sort_order']),
    );
  }
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
