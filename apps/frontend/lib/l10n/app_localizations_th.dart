import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([super.locale = 'th']);

  static const Map<String, String> _localizedValues = {
    'appTitle': 'ParkPie',
    'contribute': 'มีส่วนร่วม',
    'scan': 'สแกน',
    'uploadSuccessful': 'อัปโหลดสำเร็จ!',
    'noPhotoCaptured': 'ยังไม่ได้ถ่ายภาพ',
    'takePhoto': 'ถ่ายภาพ',
    'retake': 'ถ่ายอีกครั้ง',
    'useThisPhoto': 'ใช้ภาพนี้',
    'nav.parking': 'ที่จอดรถ',
    'nav.scan': 'สแกน',
    'nav.timer': 'ตัวจับเวลา',
    'camera.takePhotoHeader': 'ถ่ายภาพป้ายที่จอดรถ',
    'camera.instructions':
        'โปรดเล็งกล้องไปที่ป้ายจอดรถและเก็บภาพให้ครบทั้งป้าย',
    'camera.analyzing': 'กำลังวิเคราะห์ป้ายที่จอดรถ...',
    'camera.analyzingDetail': 'กำลังดึงข้อความ สรุปกฎ และซิงก์เข้ากับ ParkPie.',
    'camera.analysisTitle': 'สรุปป้าย',
    'camera.zoneAdded': 'เพิ่มโซนแล้ว',
    'camera.restrictionsSynced': 'ซิงก์ข้อจำกัด {count} รายการ',
    'camera.restrictionsReplaced': 'แทนที่ข้อจำกัดเดิม {count} รายการ',
    'camera.aiExplanation': 'คำอธิบายจาก AI',
    'camera.aiExplanationFallback':
        'AI ไม่สามารถสรุปป้ายนี้ได้ โปรดตรวจสอบข้อจำกัดด้านล่าง.',
    'camera.locationLabel': 'ตำแหน่ง',
    'camera.buttonRetake': 'ถ่ายใหม่',
    'camera.buttonDone': 'เสร็จสิ้น',
    'camera.storeMessage': 'บันทึกโซน {zone} พร้อมช่วงเวลา {count} รายการแล้ว.',
    'camera.updateMessage': 'อัปเดตโซน {zone} (แทนที่ {count} ช่วงเวลา).',
    'camera.manualZoneSaved': 'บันทึกโซน {zone} แบบกำหนดเองใน ParkPie แล้ว.',
    'camera.errorTitle': 'ไม่สามารถอ่านป้ายนี้ได้',
    'camera.errorBack': 'กลับไปยังแผนที่',
    'camera.errorMessage':
        'ไม่พบป้ายจอดรถใกล้คุณ โปรดเลือกป้ายบนแผนที่หรือสแกนใหม่.',
    'camera.captureButton': 'ถ่าย',
    'camera.retake': 'ถ่ายอีกครั้ง',
    'language.settingsTitle': 'ภาษา',
    'language.settingsSubtitle': 'เปลี่ยนภาษาของแอป',
    'language.pageTitle': 'ภาษา',
    'language.description':
        'เลือกภาษาที่ใช้ใน ParkPie การเปลี่ยนแปลงจะมีผลทันที.',
    'language.settingsAction': 'เลือกภาษา',
    'language.english': 'ภาษาอังกฤษ',
    'language.chineseTraditional': 'ภาษาจีนตัวเต็ม',
    'language.chineseSimplified': 'ภาษาจีนตัวย่อ',
    'language.korean': 'ภาษาเกาหลี',
    'language.japanese': 'ภาษาญี่ปุ่น',
    'language.thai': 'ภาษาไทย',
    'language.vietnamese': 'ภาษาเวียดนาม',
    'privacy.settingsTitle': 'ความเป็นส่วนตัวและการปฏิบัติตาม',
    'privacy.settingsSubtitle':
        'ดูรายละเอียดการเปิดเผยข้อมูลของ ParkPie สำหรับ App Store และ Google Play',
    'privacy.settingsAction': 'ดูการเปิดเผยความเป็นส่วนตัว',
  };

  @override
  String getString(String key) {
    return _localizedValues[key] ?? AppLocalizationsEn.lookupDefault(key);
  }
}
