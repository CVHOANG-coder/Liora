class I2VGenerationResponse {
  const I2VGenerationResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory I2VGenerationResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException('I2V response does not contain data.');
    }

    return I2VGenerationResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: I2VGeneration.fromJson(Map<String, dynamic>.from(rawData)),
    );
  }

  final bool success;
  final String message;
  final I2VGeneration data;
}

class I2VGeneration {
  const I2VGeneration({
    required this.requestId,
    required this.runpodJobId,
    required this.userId,
    required this.serviceType,
    required this.prompt,
    required this.imageUrl,
    this.image2Url = '',
    this.theme,
    required this.status,
    required this.createTime,
    required this.remainingCredit,
    required this.creditInfo,
    required this.params,
  });

  factory I2VGeneration.fromJson(Map<String, dynamic> json) {
    return I2VGeneration(
      requestId: json['request_id']?.toString() ?? '',
      runpodJobId: json['runpod_job_id']?.toString() ?? '',
      userId: _asInt(json['user_id']),
      serviceType: json['service_type']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      image2Url: json['image2_url']?.toString() ?? '',
      theme: json['theme'] is Map
          ? GenerationTheme.fromJson(_asMap(json['theme']))
          : null,
      status: json['status']?.toString() ?? '',
      createTime: DateTime.tryParse(json['create_time']?.toString() ?? ''),
      remainingCredit: _asInt(json['remaining_credit']),
      creditInfo: I2VCreditInfo.fromJson(_asMap(json['credit_info'])),
      params: I2VParams.fromJson(_asMap(json['params'])),
    );
  }

  final String requestId;
  final String runpodJobId;
  final int userId;
  final String serviceType;
  final String prompt;
  final String imageUrl;
  final String image2Url;
  final GenerationTheme? theme;
  final String status;
  final DateTime? createTime;
  final int remainingCredit;
  final I2VCreditInfo creditInfo;
  final I2VParams params;
}

class GenerationTheme {
  const GenerationTheme({required this.id, required this.name});

  factory GenerationTheme.fromJson(Map<String, dynamic> json) {
    return GenerationTheme(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
}

class I2VCreditInfo {
  const I2VCreditInfo({
    required this.baseCredit,
    required this.multiplier,
    required this.totalCharged,
  });

  factory I2VCreditInfo.fromJson(Map<String, dynamic> json) {
    return I2VCreditInfo(
      baseCredit: _asInt(json['base_credit']),
      multiplier: _asDouble(json['multiplier']),
      totalCharged: _asInt(json['total_charged']),
    );
  }

  final int baseCredit;
  final double multiplier;
  final int totalCharged;
}

class I2VParams {
  const I2VParams({
    required this.duration,
    required this.megapixels,
    required this.steps,
    required this.aspectRatio,
    required this.seed,
  });

  factory I2VParams.fromJson(Map<String, dynamic> json) {
    return I2VParams(
      duration: _asInt(json['duration']),
      megapixels: _asDouble(json['megapixels']),
      steps: _asInt(json['steps']),
      aspectRatio: json['aspect_ratio']?.toString() ?? '',
      seed: json['seed']?.toString() ?? '',
    );
  }

  final int duration;
  final double megapixels;
  final int steps;
  final String aspectRatio;
  final String seed;
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
