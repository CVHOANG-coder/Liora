import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';

void main() {
  test('profile provider exposes the current profile globally', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final profile = UserProfile.fromJson(<String, dynamic>{
      'id': 2,
      'user_code': 'USER001',
      'is_actived': true,
      'total_credit': 100,
      'i2v_credit_base': 35,
    });

    expect(container.read(profileProvider), isNull);

    container.read(profileProvider.notifier).setProfile(profile);

    expect(container.read(profileProvider), same(profile));
    expect(container.read(profileProvider)!.totalCredit, 100);

    container.read(profileProvider.notifier).updateTotalCredit(65);

    expect(container.read(profileProvider)!.totalCredit, 65);
  });
}
