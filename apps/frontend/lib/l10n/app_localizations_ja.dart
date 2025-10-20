import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([super.locale = 'ja']);

  static const Map<String, String> _localizedValues = {
    'appTitle': 'ParkPie',
    'contribute': '投稿',
    'scan': 'スキャン',
    'uploadSuccessful': 'アップロードに成功しました！',
    'noPhotoCaptured': '写真が撮影されていません',
    'takePhoto': '写真を撮る',
    'retake': '撮り直す',
    'useThisPhoto': 'この写真を使用',
    'nav.parking': '駐車場',
    'nav.scan': 'スキャン',
    'nav.timer': 'タイマー',
    'camera.takePhotoHeader': '駐車標識を撮影',
    'camera.instructions': 'カメラを駐車標識に向け、全体が入るように撮影してください',
    'camera.analyzing': '駐車標識を解析中...',
    'camera.analyzingDetail': 'テキストを抽出し、規則を要約して ParkPie と同期しています。',
    'camera.analysisTitle': '標識サマリー',
    'camera.zoneAdded': 'ゾーンを追加しました',
    'camera.restrictionsSynced': '{count} 件の制限を同期',
    'camera.restrictionsReplaced': '{count} 件の旧制限を置き換え',
    'camera.aiExplanation': 'AI説明',
    'camera.aiExplanationFallback': 'AI がこの標識を要約できませんでした。以下の制限をご確認ください。',
    'camera.locationLabel': '位置',
    'camera.buttonRetake': '撮り直す',
    'camera.buttonDone': '完了',
    'camera.storeMessage': 'ゾーン {zone} を保存しました（{count} 件の時間枠）。',
    'camera.updateMessage': 'ゾーン {zone} を更新しました（{count} 件の時間枠を置き換え）。',
    'camera.manualZoneSaved': '手動ゾーン {zone} を ParkPie に保存しました。',
    'camera.errorTitle': '標識を読み取れませんでした',
    'camera.errorBack': '地図に戻る',
    'camera.errorMessage': '付近に駐車標識が見つかりません。地図で標識を選択するか、再度スキャンしてください。',
    'camera.captureButton': '撮影',
    'camera.retake': '撮り直す',
    'language.settingsTitle': '言語',
    'language.settingsSubtitle': 'アプリの言語を変更',
    'language.pageTitle': '言語',
    'language.description': 'ParkPie 全体で使用する言語を選択してください。変更はすぐに反映されます。',
    'language.settingsAction': '言語を選ぶ',
    'language.english': '英語',
    'language.chineseTraditional': '繁体字中国語',
    'language.chineseSimplified': '簡体字中国語',
    'language.korean': '韓国語',
    'language.japanese': '日本語',
    'language.thai': 'タイ語',
    'language.vietnamese': 'ベトナム語',
    'privacy.settingsTitle': 'プライバシーとコンプライアンス',
    'privacy.settingsSubtitle':
        'ParkPie が App Store と Google Play のデータ開示要件をどのように満たしているかをご確認ください。',
    'privacy.settingsAction': 'プライバシー開示を表示',
  };

  @override
  String getString(String key) {
    return _localizedValues[key] ?? AppLocalizationsEn.lookupDefault(key);
  }
}
