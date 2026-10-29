import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_launcher_icons.dart';

void main() {
  test('write all platform launcher icons', () async {
    await generateAllPlatformIcons();
  });
}
