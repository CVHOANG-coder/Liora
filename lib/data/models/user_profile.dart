import 'package:flutter/foundation.dart';

class UserProfileResponse {
  const UserProfileResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException('Profile response does not contain data.');
    }

    return UserProfileResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: UserProfile.fromJson(Map<String, dynamic>.from(rawData)),
    );
  }

  final bool success;
  final String message;
  final UserProfile data;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.userCode,
    required this.platform,
    required this.country,
    required this.countryCode,
    required this.isActive,
    required this.isBanned,
    required this.subscriptionTime,
    required this.subscriptionEndTime,
    required this.subscriptionCreditRemaining,
    required this.boughtCredit,
    required this.createTime,
    required this.generationCount,
    required this.todayGenerationCount,
    required this.userStatus,
    required this.isVIP,
    required this.isSubscribed,
    required this.totalCredit,
    required this.imageToVideoBaseCredit,
    this.durationOptions = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString(),
      userCode: json['user_code'] is String ? json['user_code'] as String : '',
      platform: json['platform']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      countryCode: json['country_code']?.toString(),
      isActive: json['is_actived'] == true,
      isBanned: json['is_banned'] == true,
      subscriptionTime: _parseDate(json['sub_time']),
      subscriptionEndTime: _parseDate(json['sub_end_time']),
      subscriptionCreditRemaining:
          (json['sub_credit_remain'] as num?)?.toInt() ?? 0,
      boughtCredit: (json['bought_credit'] as num?)?.toInt() ?? 0,
      createTime: _parseDate(json['create_time']),
      generationCount: (json['gen_count'] as num?)?.toInt() ?? 0,
      todayGenerationCount: (json['today_gen_count'] as num?)?.toInt() ?? 0,
      userStatus: json['user_status']?.toString() ?? '',
      isVIP: json['isVIP'] == true,
      isSubscribed: json['isSubscribed'] == true,
      totalCredit: (json['total_credit'] as num?)?.toInt() ?? 0,
      imageToVideoBaseCredit: (json['i2v_credit_base'] as num?)?.toInt() ?? 0,
      durationOptions: [
        if (json['duration_options'] is List)
          for (final option in json['duration_options'] as List)
            if (option is Map)
              VideoDurationOption.fromJson(Map<String, dynamic>.from(option)),
      ],
    );
  }

  final int id;
  final String email;
  final String? username;
  final String userCode;
  final String platform;
  final String country;
  final String? countryCode;
  final bool isActive;
  final bool isBanned;
  final DateTime? subscriptionTime;
  final DateTime? subscriptionEndTime;
  final int subscriptionCreditRemaining;
  final int boughtCredit;
  final DateTime? createTime;
  final int generationCount;
  final int todayGenerationCount;
  final String userStatus;
  final bool isVIP;
  final bool isSubscribed;
  final int totalCredit;
  final int imageToVideoBaseCredit;
  final List<VideoDurationOption> durationOptions;

  int? extensionCreditCost({required int duration, required bool isHd}) {
    for (final option in durationOptions) {
      if (option.duration == duration) {
        return isHd ? option.imageToVideoHdCredit : option.imageToVideoCredit;
      }
    }
    return null;
  }

  /// Classifies accelerated subscriptions in debug builds only.
  /// Null leaves the caller's normal plan resolution in place.
  bool? get debugSubscriptionIsYearly {
    if (!kDebugMode || !isSubscribed) return null;
    final startedAt = subscriptionTime;
    final endsAt = subscriptionEndTime;
    if (startedAt == null || endsAt == null || !endsAt.isAfter(startedAt)) {
      return null;
    }
    final duration = endsAt.difference(startedAt);
    if (duration >= const Duration(minutes: 29)) return true;
    if (duration <= const Duration(minutes: 5)) return false;
    return null;
  }

  UserProfile copyWith({int? totalCredit}) {
    return UserProfile(
      id: id,
      email: email,
      username: username,
      userCode: userCode,
      platform: platform,
      country: country,
      countryCode: countryCode,
      isActive: isActive,
      isBanned: isBanned,
      subscriptionTime: subscriptionTime,
      subscriptionEndTime: subscriptionEndTime,
      subscriptionCreditRemaining: subscriptionCreditRemaining,
      boughtCredit: boughtCredit,
      createTime: createTime,
      generationCount: generationCount,
      todayGenerationCount: todayGenerationCount,
      userStatus: userStatus,
      isVIP: isVIP,
      isSubscribed: isSubscribed,
      totalCredit: totalCredit ?? this.totalCredit,
      imageToVideoBaseCredit: imageToVideoBaseCredit,
      durationOptions: durationOptions,
    );
  }
}

class VideoDurationOption {
  const VideoDurationOption({
    required this.duration,
    required this.imageToVideoCredit,
    required this.imageToVideoHdCredit,
  });

  factory VideoDurationOption.fromJson(Map<String, dynamic> json) =>
      VideoDurationOption(
        duration: (json['duration'] as num?)?.toInt() ?? 0,
        imageToVideoCredit: (json['i2v_credit'] as num?)?.toInt(),
        imageToVideoHdCredit: (json['i2v_credit_hd'] as num?)?.toInt(),
      );

  final int duration;
  final int? imageToVideoCredit;
  final int? imageToVideoHdCredit;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
