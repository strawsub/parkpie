import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([super.locale = 'vi']);

  static const Map<String, String> _localizedValues = {
    'appTitle': 'ParkPie',
    'contribute': 'Đóng góp',
    'scan': 'Quét',
    'uploadSuccessful': 'Tải lên thành công!',
    'noPhotoCaptured': 'Chưa chụp ảnh',
    'takePhoto': 'Chụp ảnh',
    'retake': 'Chụp lại',
    'useThisPhoto': 'Dùng ảnh này',
    'nav.parking': 'Bãi đỗ',
    'nav.scan': 'Quét',
    'nav.timer': 'Bộ hẹn giờ',
    'camera.takePhotoHeader': 'Chụp biển báo đỗ xe',
    'camera.instructions':
        'Hãy hướng máy ảnh vào biển báo và chụp toàn bộ biển.',
    'camera.analyzing': 'Đang phân tích biển báo...',
    'camera.analyzingDetail':
        'Đang trích xuất văn bản, tóm tắt quy định và đồng bộ với ParkPie.',
    'camera.analysisTitle': 'Tóm tắt biển báo',
    'camera.zoneAdded': 'Đã thêm khu vực',
    'camera.restrictionsSynced': 'Đã đồng bộ {count} hạn chế',
    'camera.restrictionsReplaced': 'Đã thay thế {count} hạn chế cũ',
    'camera.aiExplanation': 'Giải thích từ AI',
    'camera.aiExplanationFallback':
        'AI không thể tóm tắt biển báo này. Vui lòng xem các hạn chế bên dưới.',
    'camera.locationLabel': 'Vị trí',
    'camera.buttonRetake': 'Chụp lại',
    'camera.buttonDone': 'Xong',
    'camera.storeMessage': 'Đã lưu khu vực {zone} với {count} khung thời gian.',
    'camera.updateMessage':
        'Đã cập nhật khu vực {zone} (đã thay thế {count} khung thời gian).',
    'camera.manualZoneSaved': 'Đã lưu thủ công khu vực {zone} vào ParkPie.',
    'camera.errorTitle': 'Không thể đọc biển báo đó',
    'camera.errorBack': 'Quay lại bản đồ',
    'camera.errorMessage':
        'Không tìm thấy biển báo đỗ xe gần đó. Vui lòng chọn trên bản đồ hoặc quét lại.',
    'camera.captureButton': 'Chụp',
    'camera.retake': 'Chụp lại',
    'language.settingsTitle': 'Ngôn ngữ',
    'language.settingsSubtitle': 'Thay đổi ngôn ngữ của ứng dụng',
    'language.pageTitle': 'Ngôn ngữ',
    'language.description':
        'Chọn ngôn ngữ sử dụng trong ParkPie. Thay đổi có hiệu lực ngay.',
    'language.settingsAction': 'Chọn ngôn ngữ',
    'language.english': 'Tiếng Anh',
    'language.chineseTraditional': 'Tiếng Trung phồn thể',
    'language.chineseSimplified': 'Tiếng Trung giản thể',
    'language.korean': 'Tiếng Hàn',
    'language.japanese': 'Tiếng Nhật',
    'language.thai': 'Tiếng Thái',
    'language.vietnamese': 'Tiếng Việt',
    'privacy.settingsTitle': 'Quyền riêng tư & Tuân thủ',
    'privacy.settingsSubtitle':
        'Xem ParkPie công bố dữ liệu cho App Store và Google Play như thế nào.',
    'privacy.settingsAction': 'Xem thông tin quyền riêng tư',
  };

  @override
  String getString(String key) {
    return _localizedValues[key] ?? AppLocalizationsEn.lookupDefault(key);
  }
}
