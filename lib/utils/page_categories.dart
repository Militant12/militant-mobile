import '../services/language_service.dart';

/// Page categories as stored by the API (French values), mapped to their
/// translation keys.
const Map<String, String> pageCategoryKeys = {
  'Syndicat': 'category_union',
  'Collectif': 'category_collective',
  'Association': 'category_association',
  'Média': 'category_media',
  'Squat / Lieu': 'category_squat',
  'Infokiosque': 'category_infokiosk',
  'Artiste': 'category_artist',
  'Projet': 'category_project',
  'Autre': 'category_other',
};

/// Translated label for a page category; unknown values are shown as is.
String pageCategoryLabel(String category) {
  final key = pageCategoryKeys[category];
  return key == null ? category : LanguageService.instance.translate(key);
}
