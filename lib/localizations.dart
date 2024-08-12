import 'package:flutter/material.dart';

String myLanguageCode = '';
String defaultLanguageCode = 'en';

class SampleLocalizationsDelegate extends LocalizationsDelegate<Localized> {
  const SampleLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'ja'].contains(locale.languageCode);

  @override
  Future<Localized> load(Locale locale) async {
    defaultLanguageCode = locale.languageCode;
    return Localized();
  }

  @override
  bool shouldReload(SampleLocalizationsDelegate old) => false;
}

class Localized {
  //Localized(this.locale);
  //final Locale locale;

  //static Localized of(BuildContext context) {
  //  return Localizations.of(context, Localized)!;
  //}

  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Imasugu Keep Me',
      'language_code': 'Language',
      'settings_title': 'Settings',
      'photolist_title': 'In-app data',
      'take_mode': 'Mode',
      'take_mode_desc':
          'Photo: Take pictures regularly. \nVideo: Divide every 10 minutes. \nStop when the app goes to background',
      'image_interval_sec': 'Photo interval',
      'image_interval_sec_desc': 'Photo interval',
      'in_save_mb': 'In-App max size',
      'in_save_mb_desc': 'Old data will be deleted when in-app data exceeds the max size.',
      'timer_autostop_sec': 'Autostop sec',
      'timer_autostop_sec_desc':
          'Automatically stop shooting. It will stop when the remaining battery level is 10% or less. Stop when the app goes to background.',
      'image_camera_height': 'Photo camera size',
      'image_camera_height_desc': 'Select the camera size for the photo.',
      'video_camera_height': 'Video camera size',
      'video_camera_height_desc': 'Select the camera size for the video.',
      'screensaver_mode': 'Screen Saver',
      'screensaver_mode_desc':
          'Stop button: Stop button is displayed. \nBlack screen: It becomes a black screen after 8 seconds and can be canceled by tapping.',
      'stop_button': 'Stop button',
      'black_screen': 'Black screen',
      'precautions': 'precautions\nStop when the app goes to the background. Requires 10% battery.',
      'delete_files': 'Are you sure you want to delete?',
      'save_photo_app': 'Copy to Photos app',
      'delete': 'Delete',
      'cancel': 'Cancel',
      'mode_image': 'Photo',
      'mode_video': 'Video',
      'auto': 'Auto',
    },
    'ja': {
      'app_name': '今すぐ Keep Me',
      'language_code': '言語',
      'settings_title': '設定',
      'photolist_title': 'アプリ内データ',
      'take_mode': '撮影モード',
      'take_mode_desc': '写真：定期的に撮影します。\nビデオ：10分毎に分割します。\nアプリがバックグラウンドになると停止します。最大容量を超えると古いものから削除します。',
      'image_interval_sec': '写真間隔',
      'image_interval_sec_desc': '写真の撮影間隔を選んでください。',
      'in_save_mb': 'アプリ内データ最大容量',
      'in_save_mb_desc': 'アプリ内データが最大容量を超えると古いものから削除します。',
      'timer_autostop_sec': '自動停止時間',
      'timer_autostop_sec_desc': '自動的に停止します。バッテリー残量10%以下で停止します。アプリがバックグラウンドになると停止します。',
      'image_camera_height': '写真のカメラサイズ',
      'image_camera_height_desc': '写真のカメラのサイズを選んでください。',
      'video_camera_height': 'ビデオのカメラサイズ',
      'video_camera_height_desc': 'ビデオのカメラのサイズを選んでください。',
      'screensaver_mode': 'スクリーンセーバー',
      'screensaver_mode_desc': '停止ボタン：停止ボタンが表示されます。\n黒画面：8秒後に黒画面になります。タップで解除できます。',
      'stop_button': '停止ボタン',
      'black_screen': '黒画面',
      'precautions': '注意事項\nアプリがバックグラウンドになると停止します。バッテリー残量10%以下で停止します。',
      'delete_files': '削除します。よろしいですか？',
      'save_photo_app': '本体の写真アプリにコピーします。',
      'delete': '削除',
      'cancel': 'キャンセル',
      'mode_image': '写真',
      'mode_video': 'ビデオ',
      'auto': '自動',
    },
  };

  static String text(String text) {
    String? s;
    try {
      if (myLanguageCode == 'ja')
        s = _localizedValues["ja"]?[text];
      else if (myLanguageCode == 'en')
        s = _localizedValues["en"]?[text];
      else if (myLanguageCode == '' && defaultLanguageCode == "ja")
        s = _localizedValues["ja"]?[text];
      else
        s = _localizedValues["en"]?[text];
    } on Exception catch (e) {
      print('Localized.text() ${e.toString()}');
    }
    if (s == null && text.contains('_desc') == false)
      s = text;
    else if (s == null && text.contains('_desc') == true) s = '';
    return s != null ? s : text;
  }
}
