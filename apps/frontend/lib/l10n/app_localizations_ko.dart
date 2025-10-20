import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([super.locale = 'ko']);

  static const Map<String, String> _localizedValues = {
    'appTitle': 'ParkPie',
    'contribute': '기여',
    'scan': '스캔',
    'uploadSuccessful': '업로드 완료!',
    'noPhotoCaptured': '촬영된 사진이 없습니다',
    'takePhoto': '사진 촬영',
    'retake': '다시 촬영',
    'useThisPhoto': '이 사진 사용',
    'nav.parking': '주차',
    'nav.scan': '스캔',
    'nav.timer': '타이머',
    'camera.takePhotoHeader': '주차 표지판을 촬영하세요',
    'camera.instructions': '카메라를 주차 표지판에 맞추고 전체가 보이도록 촬영하세요',
    'camera.analyzing': '주차 표지판 분석 중...',
    'camera.analyzingDetail': '텍스트 추출, 규칙 요약 후 ParkPie와 동기화합니다.',
    'camera.analysisTitle': '표지판 요약',
    'camera.zoneAdded': '구역이 추가되었습니다',
    'camera.restrictionsSynced': '{count}개의 제한이 동기화됨',
    'camera.restrictionsReplaced': '{count}개의 이전 제한이 교체됨',
    'camera.aiExplanation': 'AI 설명',
    'camera.aiExplanationFallback': 'AI가 이 표지판을 요약하지 못했습니다. 아래 제한을 확인하세요.',
    'camera.locationLabel': '위치',
    'camera.buttonRetake': '다시 촬영',
    'camera.buttonDone': '완료',
    'camera.storeMessage': '구역 {zone}이 저장되었으며 {count}개의 시간 창이 포함됩니다.',
    'camera.updateMessage': '구역 {zone}이 업데이트되었고 {count}개의 시간 창이 교체되었습니다.',
    'camera.manualZoneSaved': '수동 구역 {zone}이 ParkPie에 저장되었습니다.',
    'camera.errorTitle': '표지판을 읽지 못했습니다',
    'camera.errorBack': '지도로 돌아가기',
    'camera.errorMessage': '근처에서 주차 표지판을 찾을 수 없습니다. 지도에서 표지판을 선택하거나 다시 스캔하세요.',
    'camera.captureButton': '촬영',
    'camera.retake': '다시 촬영',
    'language.settingsTitle': '언어',
    'language.settingsSubtitle': '앱 언어 변경',
    'language.pageTitle': '언어',
    'language.description': 'ParkPie에서 사용할 언어를 선택하세요. 변경 사항은 즉시 적용됩니다.',
    'language.settingsAction': '언어 선택',
    'language.english': '영어',
    'language.chineseTraditional': '번체 중국어',
    'language.chineseSimplified': '간체 중국어',
    'language.korean': '한국어',
    'language.japanese': '일본어',
    'language.thai': '태국어',
    'language.vietnamese': '베트남어',
    'privacy.settingsTitle': '개인정보 및 준수',
    'privacy.settingsSubtitle':
        'ParkPie가 App Store 및 Google Play 데이터 공개 요구사항을 어떻게 충족하는지 확인하세요.',
    'privacy.settingsAction': '개인정보 공개 보기',
  };

  @override
  String getString(String key) {
    return _localizedValues[key] ?? AppLocalizationsEn.lookupDefault(key);
  }
}
