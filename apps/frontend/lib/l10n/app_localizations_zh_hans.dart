import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// The translations for Simplified Chinese (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizations {
  AppLocalizationsZhHans([super.locale = 'zh_Hans']);

  static const Map<String, String> _localizedValues = {
    'appTitle': 'ParkPie',
    'contribute': '贡献',
    'scan': '扫描',
    'uploadSuccessful': '上传成功！',
    'noPhotoCaptured': '尚未拍摄照片',
    'takePhoto': '拍照',
    'retake': '重新拍摄',
    'useThisPhoto': '使用此照片',
    'nav.parking': '停车',
    'nav.scan': '扫描',
    'nav.timer': '计时器',
    'camera.takePhotoHeader': '拍摄停车标志',
    'camera.instructions': '请将相机对准停车标志并捕捉完整画面',
    'camera.analyzing': '正在分析停车标志…',
    'camera.analyzingDetail': '正在提取文字、总结规则并同步到 ParkPie。',
    'camera.analysisTitle': '标志摘要',
    'camera.zoneAdded': '已新增区域',
    'camera.restrictionsSynced': '已同步 {count} 项限制',
    'camera.restrictionsReplaced': '已替换 {count} 项旧限制',
    'camera.aiExplanation': 'AI 说明',
    'camera.aiExplanationFallback': 'AI 无法总结此标志。请查看下方限制。',
    'camera.locationLabel': '位置',
    'camera.buttonRetake': '重新拍摄',
    'camera.buttonDone': '完成',
    'camera.storeMessage': '已保存区域 {zone}（{count} 个时段）。',
    'camera.updateMessage': '已更新区域 {zone}（替换 {count} 个时段）。',
    'camera.manualZoneSaved': '手动区域 {zone} 已保存到 ParkPie。',
    'camera.errorTitle': '无法读取该标志',
    'camera.errorBack': '返回地图',
    'camera.errorMessage': '找不到附近的停车标志。请在地图上选择标志或重新扫描。',
    'camera.captureButton': '拍摄',
    'camera.retake': '重新拍摄',
    'language.settingsTitle': '语言',
    'language.settingsSubtitle': '切换应用语言',
    'language.pageTitle': '语言',
    'language.description': '选择 ParkPie 使用的语言。变更会立即生效。',
    'language.settingsAction': '选择语言',
    'language.english': '英文',
    'language.chineseTraditional': '繁体中文',
    'language.chineseSimplified': '简体中文',
    'language.korean': '韩文',
    'language.japanese': '日文',
    'privacy.settingsTitle': '隐私与合规',
    'privacy.settingsSubtitle':
        '了解 ParkPie 如何满足 App Store 与 Google Play 的数据披露要求。',
    'privacy.settingsAction': '查看隐私说明',
  };

  @override
  String getString(String key) {
    return _localizedValues[key] ?? AppLocalizationsEn.lookupDefault(key);
  }
}
