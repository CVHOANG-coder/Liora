class SignInResponse {
  const SignInResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException('Sign-in response does not contain data.');
    }

    return SignInResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: SignInData.fromJson(Map<String, dynamic>.from(rawData)),
    );
  }

  final bool success;
  final String message;
  final SignInData data;
}

class SignInData {
  const SignInData({
    required this.id,
    required this.userCode,
    required this.platform,
    required this.country,
    required this.token,
    required this.isActive,
    required this.isBanned,
    required this.subscriptionCreditRemaining,
    required this.boughtCredit,
  });

  factory SignInData.fromJson(Map<String, dynamic> json) {
    final token = json['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const FormatException('Sign-in response does not contain a token.');
    }

    return SignInData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userCode: json['user_code']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      token: token,
      isActive: json['is_actived'] == true,
      isBanned: json['is_banned'] == true,
      subscriptionCreditRemaining:
          (json['sub_credit_remain'] as num?)?.toInt() ?? 0,
      boughtCredit: (json['bought_credit'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String userCode;
  final String platform;
  final String country;
  final String token;
  final bool isActive;
  final bool isBanned;
  final int subscriptionCreditRemaining;
  final int boughtCredit;
}
