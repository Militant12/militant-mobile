import 'package:flutter_test/flutter_test.dart';
import 'package:militant/screens/pages_screen.dart';

void main() {
  test('la ligne annonce nom, catégorie, abonnés et description', () {
    final label = pageRowSemanticsLabel({
      'name': 'Réveil Libertaire',
      'category': 'media',
      'followers_count': 10,
      'description': 'Page du blog',
    });
    expect(label, startsWith('Réveil Libertaire, '));
    expect(label, contains('10 abonnés'));
    expect(label, endsWith(', Page du blog'));
  });

  test('un seul abonné, sans catégorie ni description', () {
    expect(
      pageRowSemanticsLabel({'name': 'ruessanssilence', 'follower_count': '1'}),
      'ruessanssilence, 1 abonné',
    );
  });

  test('le rôle affiché sur la ligne est lu aussi', () {
    expect(
      pageRowSemanticsLabel({'name': 'Ma page'}, badge: 'Admin'),
      'Ma page, Admin, 0 abonné',
    );
  });
}
