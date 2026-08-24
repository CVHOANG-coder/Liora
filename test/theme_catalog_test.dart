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
    'sort_order': sortOrder,
  };
}
