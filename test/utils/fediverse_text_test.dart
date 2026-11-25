import 'package:flutter_test/flutter_test.dart';
import 'package:militant/utils/fediverse_text.dart';

void main() {
  test('fediverseHtmlToText decodes numeric, hex, named and double-encoded entities', () {
    const html =
        '<p>I&#8217;m here &#x2014; Durruti &amp;#8211; Espagne 36 &laquo;test&raquo; &hellip;</p>';
    expect(
      fediverseHtmlToText(html),
      'I’m here — Durruti – Espagne 36 «test» …',
    );
  });
}
