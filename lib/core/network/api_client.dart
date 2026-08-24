import 'package:dio/dio.dart';

import '../../data/models/i2v_generation.dart';
import '../../data/models/i2v_request_status.dart';
import '../../data/models/generation_history.dart';
import '../../data/models/sign_in_response.dart';
import '../../data/models/package_catalog.dart';
import '../../data/models/purchase_verification.dart';
import '../../data/models/user_profile.dart';
import '../../data/video_categories.dart';
import '../../data/services/auth_session.dart';
import '../../data/services/i2v_generation_service.dart';
import '../../data/services/i2v_request_status_service.dart';
import '../../data/services/t2v_generation_service.dart';
import '../../data/services/generation_history_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/package_service.dart';
import '../../data/services/purchase_verification_service.dart';
import '../../data/services/theme_service.dart';
import '../../data/services/theme_generation_service.dart';
import '../device/device_identity_service.dart';
import '../storage/token_storage.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient({
    Dio? httpClient,
    Dio? authClient,
    DeviceIdentityProvider? deviceIdentity,
    TokenStorage? tokenStorage,
  }) {
    final options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      headers: const <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    final signInDio = authClient ?? Dio(options.copyWith());
    authSession = AuthSession(
      signInDio,
      deviceIdentity ?? DeviceIdentityService(),
      tokenStorage ?? SharedPreferencesTokenStorage(),
    );

    dio = httpClient ?? Dio(options.copyWith());
    dio.interceptors.add(AuthInterceptor(dio, authSession));
    profileService = ProfileService(dio);
    packageService = PackageService(dio);
    purchaseVerificationService = PurchaseVerificationService(dio);
    themeService = ThemeService(dio);
    i2vGenerationService = I2VGenerationService(dio);
    i2vRequestStatusService = I2VRequestStatusService(dio);
    t2vGenerationService = T2VGenerationService(dio);
    themeGenerationService = ThemeGenerationService(dio);
    generationHistoryService = GenerationHistoryService(dio);
  }

  static final ApiClient instance = ApiClient();

  late final Dio dio;
  late final AuthSession authSession;
  late final ProfileService profileService;
  late final PackageService packageService;
  late final PurchaseVerificationService purchaseVerificationService;
  late final ThemeService themeService;
  late final I2VGenerationService i2vGenerationService;
  late final I2VRequestStatusService i2vRequestStatusService;
  late final T2VGenerationService t2vGenerationService;
  late final ThemeGenerationService themeGenerationService;
  late final GenerationHistoryService generationHistoryService;

  SignInData? get currentUser => authSession.currentUser;

  Future<SignInData> signIn() => authSession.signIn();

  Future<PackageCatalog> fetchPackages() => packageService.fetchPackages();

  Future<PurchaseVerificationResponse> verifyPurchase(
    PurchaseReceipt receipt,
  ) => purchaseVerificationService.verify(receipt);

  Future<UserProfile> fetchProfile() => profileService.fetchProfile();

  Future<List<VideoCategory>> fetchThemes() => themeService.fetchThemes();

  Future<I2VGeneration> generateImageToVideo({
    required String imagePath,
    required String prompt,
    required bool isHd,
    required bool isLongTime,
  }) => i2vGenerationService.generate(
    imagePath: imagePath,
    prompt: prompt,
    isHd: isHd,
    isLongTime: isLongTime,
  );

  Future<I2VRequestStatus> fetchImageToVideoStatus(String requestId) =>
      i2vRequestStatusService.fetch(requestId);

  Future<I2VGeneration> generateTextToVideo({
    required String prompt,
    required bool isHd,
    required bool isLongTime,
  }) => t2vGenerationService.generate(
    prompt: prompt,
    isHd: isHd,
    isLongTime: isLongTime,
  );

  Future<I2VGeneration> generateThemeVideo({
    required String themeId,
    required String firstImagePath,
    required bool isHd,
    required bool isLongTime,
  }) => themeGenerationService.generate(
    themeId: themeId,
    firstImagePath: firstImagePath,
    isHd: isHd,
    isLongTime: isLongTime,
  );

  Future<GenerationHistoryPage> fetchGenerationHistory({
    required int page,
    int limit = 10,
  }) => generationHistoryService.fetch(page: page, limit: limit);

  Future<void> deleteGenerationRequest(String requestId) =>
      generationHistoryService.deleteRequest(requestId);

  /// Restores the saved session if possible. A missing or rejected token is
  /// replaced through /signin before profile is requested again.
  Future<UserProfile> bootstrapSession() async {
    await authSession.initialize();

    if (authSession.hasToken) {
      try {
        return await profileService.fetchProfile(allowAuthRefresh: false);
      } catch (error) {
        if (error is ApiException &&
            (error.hasCode(ApiErrorCode.accountBanned) ||
                error.hasCode(ApiErrorCode.subscriptionExpired))) {
          rethrow;
        }
        // Continue with a fresh device sign-in below.
      }
    }

    await authSession.signIn();
    return profileService.fetchProfile(allowAuthRefresh: false);
  }
}
