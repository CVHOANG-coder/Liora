import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_profile.dart';

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => null;

  void setProfile(UserProfile profile) => state = profile;

  void updateTotalCredit(int totalCredit) {
    state = state?.copyWith(totalCredit: totalCredit);
  }

  void clear() => state = null;
}
