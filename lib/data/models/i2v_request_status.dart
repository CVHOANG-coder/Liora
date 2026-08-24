class I2VRequestStatusResponse {
  const I2VRequestStatusResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory I2VRequestStatusResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException(
        'Request status response does not contain data.',
      );
    }

    return I2VRequestStatusResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: I2VRequestStatus.fromJson(Map<String, dynamic>.from(rawData)),
    );
  }

  final bool success;
  final String message;
  final I2VRequestStatus data;
}

class I2VRequestStatus {
  const I2VRequestStatus({
    required this.id,
    required this.requestId,
    required this.runpodJobId,
    required this.userId,
    required this.serviceType,
    required this.status,
    required this.prompt,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.resultUrl,
    required this.errorMessage,
    required this.creditCharged,
    required this.creditRefunded,
    required this.duration,
    required this.isHd,
    required this.isLongTime,
    required this.createTime,
    required this.completedTime,
    required this.lastUpdateTime,
  });

  factory I2VRequestStatus.fromJson(Map<String, dynamic> json) {
    return I2VRequestStatus(
      id: _asInt(json['id']),
      requestId: json['request_id']?.toString() ?? '',
      runpodJobId: json['runpod_job_id']?.toString() ?? '',
      userId: _asInt(json['user_id']),
      serviceType: json['service_type']?.toString() ?? '',
      status: json['request_status']?.toString().trim().toUpperCase() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      resultUrl: json['result_data']?.toString() ?? '',
      errorMessage: json['error_message']?.toString() ?? '',
      creditCharged: _asInt(json['credit_charged']),
      creditRefunded: json['credit_refunded'] == true,
      duration: _asInt(json['duration']),
      isHd: json['is_hd'] == true,
      isLongTime: json['is_long_time'] == true,
      createTime: _asDate(json['create_time']),
      completedTime: _asDate(json['completed_time']),
      lastUpdateTime: _asDate(json['last_update_time']),
    );
  }

  final int id;
  final String requestId;
  final String runpodJobId;
  final int userId;
  final String serviceType;
  final String status;
  final String prompt;
  final String imageUrl;
  final String thumbnailUrl;
  final String resultUrl;
  final String errorMessage;
  final int creditCharged;
  final bool creditRefunded;
  final int duration;
  final bool isHd;
  final bool isLongTime;
  final DateTime? createTime;
  final DateTime? completedTime;
  final DateTime? lastUpdateTime;

  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED' || status == 'FAIL';
  bool get isQueued => status == 'IN_QUEUE';
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());
