import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/package_catalog.dart';

void main() {
  test('parses packages and selects credit group by subscription status', () {
    final response = PackageCatalogResponse.fromJson(<String, dynamic>{
      'success': true,
      'message': 'success',
      'data': <String, dynamic>{
        'ANDROID': <String, dynamic>{
          'SUBSCRIPTION': <Map<String, dynamic>>[
            _package(name: 'Weekly Pro', price: 7.99, days: 7),
            _package(name: 'Annually Pro', price: 49.99, days: 365),
          ],
          'SALE': <Map<String, dynamic>>[
            _package(name: 'Annually Sale', price: 29.99, days: 365),
          ],
          'CONSUMABLE_VIP': <Map<String, dynamic>>[
            _package(name: '70 Credits VIP', price: 2.59, credit: 70),
          ],
          'CONSUMABLE_NEW': <Map<String, dynamic>>[
            _package(name: '70 Credits', price: 5.19, credit: 70),
          ],
        },
      },
    });

    final android = response.data.forPlatform('android');

    expect(response.success, isTrue);
    expect(android, isNotNull);
    expect(android!.weeklySubscription?.price, 7.99);
    expect(android.yearlySubscription?.price, 29.99);
    expect(android.creditsFor(isSubscribed: true).single.price, 2.59);
    expect(android.creditsFor(isSubscribed: false).single.price, 5.19);
  });

  test('handles missing package groups as empty lists', () {
    final catalog = PackageCatalog.fromJson(<String, dynamic>{
      'IOS': <String, dynamic>{},
    });

    final ios = catalog.forPlatform('IOS');

    expect(ios, isNotNull);
    expect(ios!.subscriptions, isEmpty);
    expect(ios.consumableVip, isEmpty);
  });
}

Map<String, dynamic> _package({
  required String name,
  required double price,
  int days = 0,
  int credit = 0,
}) {
  return <String, dynamic>{
    'id': 1,
    'product_id': 'com.nostalia.${name.toLowerCase().replaceAll(' ', '.')}',
    'product_type': days == 0 ? 'CONSUMABLE' : 'SUBSCRIPTION',
    'name': name,
    'price': price,
    'platform': 'ANDROID',
    'description': '',
    'credit': credit,
    'pack_duration_day': days,
  };
}
