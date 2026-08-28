import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';

void main() {
  test('parses API themes and sorts them by sort_order', () {
    final response = ThemeCatalogResponse.fromJson(<String, dynamic>{
      'success': true,
      'message': 'success',
      'data': <String, dynamic>{
        'categories': <Map<String, dynamic>>[
          <String, dynamic>{
            'category_key': 'camera_motion',
            'title': 'Camera motion',
            'theme_count': 2,
            'themes': <Map<String, dynamic>>[
              _theme(id: 2, key: 'zoom_in', name: 'Zoom In', sortOrder: 2),
              _theme(
                id: 1,
                key: 'rotation_360',
                name: 'Rotation 360',
                sortOrder: 1,
              ),
            ],
          },
        ],
        'total': 2,
      },
    });

    expect(response.success, isTrue);
    expect(response.total, 2);
    expect(response.categories.single.id, 'camera_motion');
    expect(
      response.categories.single.posts.map((theme) => theme.themeKey),
      <String>['rotation_360', 'zoom_in'],
    );
    expect(
      response.categories.single.posts.first.videoUrl,
      'https://example.test/rotation_360.mp4',
    );
    expect(
      response.categories.single.posts.first.previewWebpUrl,
      'https://example.test/rotation_360.webp',
    );
    expect(
      response.categories.single.posts.first.previewImageUrl,
      'https://example.test/rotation_360.webp',
    );
    expect(
      response.categories.single.posts.first.thumbnailUrl,
      'https://example.test/rotation_360.jpg',
    );
  });

  for (final preview in [null, '', '  \n  ']) {
    test('falls back to thumbnail when preview_webp_url is $preview', () {
      final post = VideoPost.fromJson({
        'id': 1,
        'thumbnail_url': ' https://example.test/thumbnail.jpg ',
        'preview_webp_url': preview,
      });
      expect(post.previewWebpUrl, isNull);
      expect(post.previewImageUrl, 'https://example.test/thumbnail.jpg');
    });
  }

  test('remains compatible with responses without preview_webp_url', () {
    final post = VideoPost.fromJson({
      'id': 1,
      'thumbnail_url': 'https://example.test/thumbnail.jpg',
    });
    expect(post.previewWebpUrl, isNull);
    expect(post.previewImageUrl, post.thumbnailUrl);
  });

  test('retains WebP-only themes and filters themes without list images', () {
    final response = ThemeCatalogResponse.fromJson({
      'success': true,
      'data': {
        'categories': [
          {
            'category_key': 'preview-only',
            'themes': [
              {
                'id': 2,
                'preview_webp_url': ' https://example.test/preview.webp ',
                'thumbnail_url': '',
                'sort_order': 2,
              },
              {
                'id': 1,
                'thumbnail_url': 'https://example.test/thumbnail.jpg',
                'sort_order': 1,
              },
              {
                'id': 3,
                'preview_video_url': 'https://example.test/only-video.mp4',
                'thumbnail_url': ' ',
                'preview_webp_url': null,
              },
            ],
          },
          {'category_key': 'empty', 'themes': []},
        ],
      },
    });
    expect(response.categories, hasLength(1));
    final posts = response.categories.single.posts;
    expect(posts.map((post) => post.id), ['1', '2']);
    expect(posts.last.thumbnailUrl, isNull);
    expect(posts.last.previewImageUrl, 'https://example.test/preview.webp');
  });
}

Map<String, dynamic> _theme({
  required int id,
  required String key,
  required String name,
  required int sortOrder,
}) {
  return <String, dynamic>{
    'id': id,
    'theme_key': key,
    'name': name,
    'service_type': 'I2V_GENERATOR',
    'preview_video_url': 'https://example.test/$key.mp4',
    'thumbnail_url': 'https://example.test/$key.jpg',
    'preview_webp_url': 'https://example.test/$key.webp',
    'sort_order': sortOrder,
  };
}
