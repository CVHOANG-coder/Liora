import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/video_categories.dart';

final themeCategoriesProvider = FutureProvider<List<VideoCategory>>(
  (ref) => ApiClient.instance.fetchThemes(),
);
