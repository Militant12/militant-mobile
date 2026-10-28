import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/api_service.dart';

void main() {
  const base = 'https://api.militant.revlibertaire.com';
  const site = 'https://militant.revlibertaire.com';

  String? resolve(String? path) =>
      ApiService.resolveImageUrl(path, baseUrl: base);

  test('rien pour un chemin vide ou l’avatar par défaut', () {
    expect(resolve(null), isNull);
    expect(resolve('  '), isNull);
    expect(resolve('default.svg'), isNull);
  });

  test('garde une URL complète', () {
    expect(
      resolve('https://cdn.example.test/a.jpg'),
      'https://cdn.example.test/a.jpg',
    );
  });

  test('range un nom de fichier seul dans son dossier d’uploads', () {
    expect(resolve('media_1.jpg'), '$site/uploads/posts/media_1.jpg');
    expect(resolve('avatar_1.jpg'), '$site/uploads/avatar_1.jpg');
    expect(resolve('story_1.jpg'), '$site/uploads/stories/story_1.jpg');
  });

  test('ajoute « uploads/ » à un média rangé dans son dossier', () {
    expect(resolve('posts/abc.jpg'), '$site/uploads/posts/abc.jpg');
    expect(resolve('/posts/abc.jpg'), '$site/uploads/posts/abc.jpg');
    expect(resolve('stories/abc.mp4'), '$site/uploads/stories/abc.mp4');
    expect(resolve('albums/abc.png'), '$site/uploads/albums/abc.png');
    expect(resolve('messages/abc.jpg'), '$site/uploads/messages/abc.jpg');
  });

  test('ne double pas « uploads/ »', () {
    expect(resolve('uploads/posts/abc.jpg'), '$site/uploads/posts/abc.jpg');
  });

  test('laisse les autres chemins tels quels', () {
    expect(resolve('assets/logo.png'), '$site/assets/logo.png');
  });
}
