import 'i2v_request_status.dart';

class GenerationHistoryPage {
  const GenerationHistoryPage({
    required this.requests,
    required this.pagination,
  });

  factory GenerationHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException(
        'Generation history response does not contain data.',
      );
    }

    final data = Map<String, dynamic>.from(rawData);
    final rawRequests = data['requests'];
    if (rawRequests is! List) {
      throw const FormatException(
        'Generation history response does not contain requests.',
      );
    }

    return GenerationHistoryPage(
      requests: rawRequests
          .whereType<Map>()
          .map(
            (request) =>
                I2VRequestStatus.fromJson(Map<String, dynamic>.from(request)),
          )
          .toList(growable: false),
      pagination: GenerationHistoryPagination.fromJson(
        _asMap(data['pagination']),
      ),
    );
  }

  final List<I2VRequestStatus> requests;
  final GenerationHistoryPagination pagination;
}

class GenerationHistoryPagination {
  const GenerationHistoryPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory GenerationHistoryPagination.fromJson(Map<String, dynamic> json) {
    return GenerationHistoryPagination(
      page: _asInt(json['page'], fallback: 1),
      limit: _asInt(json['limit'], fallback: 10),
      total: _asInt(json['total']),
      totalPages: _asInt(json['total_pages'], fallback: 1),
    );
  }

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
