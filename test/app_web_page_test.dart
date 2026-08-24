import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/presentation/screens/support/app_web_view_screen.dart';

void main() {
  test('maps legal and support pages to their public URLs', () {
    expect(
      AppWebPage.privacy.url,
      'https://ai-video.giddychat.com/privacy-policy.html',
    );
    expect(AppWebPage.terms.url, 'https://ai-video.giddychat.com/terms-of-use');
    expect(
      AppWebPage.support.url,
      'https://ai-video.giddychat.com/support.html',
    );
  });
}
