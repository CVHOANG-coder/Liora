abstract final class IapProductIds {
  static const namespace = 'com.lioraai.videogenerator';

  static const weekly = '$namespace.weekly';
  static const annually = '$namespace.annually';
  static const annuallySale = '$namespace.annuallysale';

  static const credits70 = '$namespace.70_credits';
  static const credits150 = '$namespace.150_credits';
  static const credits500 = '$namespace.500_credits';
  static const credits1000 = '$namespace.1000_credits';
  static const credits5000 = '$namespace.5000_credits';

  static const credits70Vip = '$namespace.70_credits_vip';
  static const credits150Vip = '$namespace.150_credits_vip';
  static const credits500Vip = '$namespace.500_credits_vip';
  static const credits1000Vip = '$namespace.1000_credits_vip';
  static const credits5000Vip = '$namespace.5000_credits_vip';

  static const subscriptionProductIds = <String>{
    weekly,
    annually,
    annuallySale,
  };

  static const consumableNewProductIds = <String>{
    credits70,
    credits150,
    credits500,
    credits1000,
    credits5000,
  };

  static const consumableVipProductIds = <String>{
    credits70Vip,
    credits150Vip,
    credits500Vip,
    credits1000Vip,
    credits5000Vip,
  };

  static const consumableProductIds = <String>{
    ...consumableNewProductIds,
    ...consumableVipProductIds,
  };

  static const allProductIds = <String>{
    ...subscriptionProductIds,
    ...consumableProductIds,
  };

  static const _legacyAnnuallySale = 'com.nostalia.videogenerator.annuallysale';

  static String canonicalize(String productId) {
    final normalized = productId.trim();
    return normalized == _legacyAnnuallySale ? annuallySale : normalized;
  }
}
