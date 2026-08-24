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
    required this.isVip,
    required this.isSubscribed,
    required this.totalCredit,
    required this.imageToVideoBaseCredit,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString(),
      userCode: json['user_code']?.toString() ?? '',
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
      isVip: json['isVIP'] == true,
      isSubscribed: json['isSubscribed'] == true,
      totalCredit: (json['total_credit'] as num?)?.toInt() ?? 0,
      imageToVideoBaseCredit: (json['i2v_credit_base'] as num?)?.toInt() ?? 0,
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
  final bool isVip;
  final bool isSubscribed;
  final int totalCredit;
  final int imageToVideoBaseCredit;

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
      isVip: isVip,
      isSubscribed: isSubscribed,
      totalCredit: totalCredit ?? this.totalCredit,
      imageToVideoBaseCredit: imageToVideoBaseCredit,
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
