import 'package:all_commerce/core/utils/share_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => dotenv.loadFromString(envString: 'PUBLIC_BASE_URL='));

  test('builds catalog and product URLs on the link base', () {
    expect(
      ShareService.catalogUrl('demo'),
      'https://${ShareService.linkBase}/s/demo',
    );
    expect(
      ShareService.productUrl('demo', 'p1'),
      'https://${ShareService.linkBase}/s/demo/p/p1',
    );
  });

  test('shareLink returns shared when the sender succeeds', () async {
    String? sentText;
    String? sentUrl;
    final ShareService service = ShareService(
      sender: (String text, String url) async {
        sentText = text;
        sentUrl = url;
      },
    );
    final ShareResult result = await service.shareLink(
      url: ShareService.catalogUrl('demo'),
      text: 'Mirá el catálogo de Demo',
    );
    expect(result, ShareResult.shared);
    expect(sentText, 'Mirá el catálogo de Demo');
    expect(sentUrl, contains('/s/demo'));
  });

  test('shareLink falls back to copied when the sender throws', () async {
    final ShareService service = ShareService(
      sender: (String text, String url) =>
          Future<void>.error(StateError('unsupported')),
    );
    final ShareResult result = await service.shareLink(
      url: ShareService.productUrl('demo', 'p1'),
      text: 'Vaso — \$100 en Demo',
    );
    expect(result, ShareResult.copied);
  });
}
