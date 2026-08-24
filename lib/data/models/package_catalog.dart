class PackageCatalogResponse {
  const PackageCatalogResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory PackageCatalogResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException('Package response does not contain data.');
    }

    return PackageCatalogResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: PackageCatalog.fromJson(Map<String, dynamic>.from(rawData)),
    );
  }

  final bool success;
  final String message;
  final PackageCatalog data;
}

class PackageCatalog {
  const PackageCatalog(this.platforms);

  factory PackageCatalog.fromJson(Map<String, dynamic> json) {
    return PackageCatalog(
      json.map((key, value) {
        final packages = value is Map
            ? PlatformPackages.fromJson(Map<String, dynamic>.from(value))
            : const PlatformPackages.empty();
        return MapEntry(key.toUpperCase(), packages);
      }),
    );
  }

  final Map<String, PlatformPackages> platforms;

  PlatformPackages? forPlatform(String? platform) {
    final key = platform?.trim().toUpperCase();
    if (key == null || key.isEmpty) return null;
    return platforms[key];
  }
}

class PlatformPackages {
  const PlatformPackages({
    required this.subscriptions,
    required this.sales,
    required this.consumableVip,
    required this.consumableNew,
  });

  const PlatformPackages.empty()
    : subscriptions = const [],
      sales = const [],
      consumableVip = const [],
      consumableNew = const [];

  factory PlatformPackages.fromJson(Map<String, dynamic> json) {
    return PlatformPackages(
      subscriptions: _parsePackages(json['SUBSCRIPTION']),
      sales: _parsePackages(json['SALE']),
      consumableVip: _parsePackages(json['CONSUMABLE_VIP']),
      consumableNew: _parsePackages(json['CONSUMABLE_NEW']),
    );
  }

  final List<AppPackage> subscriptions;
  final List<AppPackage> sales;
  final List<AppPackage> consumableVip;
  final List<AppPackage> consumableNew;

  List<AppPackage> creditsFor({required bool isSubscribed}) =>
      isSubscribed ? consumableVip : consumableNew;

  AppPackage? get weeklySubscription =>
      _firstWhere(subscriptions, (package) => package.durationDays <= 14);

  AppPackage? get yearlySubscription =>
      _firstWhere(sales, (package) => package.durationDays >= 300) ??
      _firstWhere(subscriptions, (package) => package.durationDays >= 300);
}

class AppPackage {
  const AppPackage({
    required this.id,
    required this.productId,
    required this.productType,
    required this.name,
    required this.price,
    required this.platform,
    required this.description,
    required this.credit,
    required this.durationDays,
  });

  factory AppPackage.fromJson(Map<String, dynamic> json) {
    return AppPackage(
      id: _asInt(json['id']),
      productId: json['product_id']?.toString() ?? '',
      productType: json['product_type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _asDouble(json['price']),
      platform: json['platform']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      credit: _asInt(json['credit']),
      durationDays: _asInt(json['pack_duration_day']),
    );
  }

  final int id;
  final String productId;
  final String productType;
  final String name;
  final double price;
  final String platform;
  final String description;
  final int credit;
  final int durationDays;
}

List<AppPackage> _parsePackages(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => AppPackage.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

AppPackage? _firstWhere(
  List<AppPackage> packages,
  bool Function(AppPackage package) test,
) {
  for (final package in packages) {
    if (test(package)) return package;
  }
  return null;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
