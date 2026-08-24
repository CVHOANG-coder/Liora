abstract final class ApiConfig {
  static const baseUrl = 'https://ai-video.giddychat.com';
  static const signInPath = '/signin';
  static const profilePath = '/users/user-status';
  static const packagesPath = '/get-all-package';
  static const verifyPurchasePath = '/users/verify-purchase';
  static const generateI2VPath = '/users/gen-i2v';
  static const generateT2VPath = '/users/gen-t2v';
  static const generateThemePath = '/users/gen-theme';
  static const requestStatusPath = '/users/request-status';
  static const generationHistoryPath = '/users/gen-history';
  static const deleteGenerationRequestPath = '/users/delete-request';
  static const themesPath = '/users/get-themes';

  /// Request extra used by startup profile validation to handle refresh in a
  /// deterministic login -> profile sequence.
  static const skipAuthRefreshKey = 'skip_auth_refresh';

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const sendTimeout = Duration(seconds: 30);

  /// Used only when the operating system does not expose a region code.
  static const fallbackCountryCode = 'VN';
}
