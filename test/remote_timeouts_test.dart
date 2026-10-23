import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/config/app_config.dart';

void main() {
  test('ask timeout is longer than transport / soft wait', () {
    expect(AppConfig.remoteTransportTimeout, const Duration(seconds: 8));
    expect(AppConfig.remoteAskSoftWait, const Duration(seconds: 12));
    expect(AppConfig.remoteAskTimeout, const Duration(seconds: 120));
    expect(
      AppConfig.remoteAskTimeout > AppConfig.remoteAskSoftWait,
      isTrue,
    );
    expect(
      AppConfig.remoteAskSoftWait > AppConfig.remoteTransportTimeout,
      isTrue,
    );
  });
}
