import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// The translations for Traditional Chinese (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizations {
  AppLocalizationsZhHant([super.locale = 'zh_Hant']);

  static const Map<String, String> _localizedValues = {
    'appTitle': 'ParkPie',
    'contribute': '貢獻',
    'scan': '掃描',
    'uploadSuccessful': '上傳成功！',
    'noPhotoCaptured': '沒有拍攝照片',
    'takePhoto': '拍照',
    'retake': '重新拍攝',
    'useThisPhoto': '使用此照片',
    'nav.parking': '停車',
    'nav.scan': '掃描',
    'nav.timer': '計時器',
    'camera.takePhotoHeader': '拍攝停車標誌',
    'camera.instructions': '請將相機對準停車標誌並捕捉完整畫面',
    'camera.analyzing': '正在分析停車標誌…',
    'camera.analyzingDetail': '正在擷取文字、總結規則並同步到 ParkPie。',
    'camera.analysisTitle': '標誌摘要',
    'camera.zoneAdded': '已新增區域',
    'camera.restrictionsSynced': '已同步 {count} 項限制',
    'camera.restrictionsReplaced': '已取代 {count} 項舊限制',
    'camera.aiExplanation': 'AI 說明',
    'camera.aiExplanationFallback': 'AI 無法總結此標誌。請檢視下方限制。',
    'camera.locationLabel': '位置',
    'camera.buttonRetake': '重新拍攝',
    'camera.buttonDone': '完成',
    'camera.storeMessage': '已儲存區域 {zone}（{count} 個時段）。',
    'camera.updateMessage': '已更新區域 {zone}（取代 {count} 個時段）。',
    'camera.manualZoneSaved': '手動區域 {zone} 已儲存至 ParkPie。',
    'camera.errorTitle': '無法讀取該標誌',
    'camera.errorBack': '返回地圖',
    'camera.errorMessage': '找不到附近的停車標誌。請在地圖上選擇標誌或重新掃描。',
    'camera.captureButton': '拍攝',
    'camera.retake': '重新拍攝',
    'language.settingsTitle': '語言',
    'language.settingsSubtitle': '切換應用程式語言',
    'language.pageTitle': '語言',
    'language.description': '選擇 ParkPie 使用的語言。變更會立即生效。',
    'language.settingsAction': '選擇語言',
    'language.english': '英文',
    'language.chineseTraditional': '繁體中文',
    'language.chineseSimplified': '簡體中文',
    'language.korean': '韓文',
    'language.japanese': '日文',
    'language.thai': '泰文',
    'language.vietnamese': '越南文',
    'privacy.settingsTitle': '隱私與合規',
    'privacy.settingsSubtitle':
        '查看 ParkPie 如何針對 App Store 與 Google Play 的資料揭露要求進行說明。',
    'privacy.settingsAction': '查看隱私揭露',
  };

  @override
  String getString(String key) {
    return _localizedValues[key] ?? AppLocalizationsEn.lookupDefault(key);
  }
}
