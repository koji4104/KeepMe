import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:io';
import '/constants.dart';

class EnvData {
  int val;
  String key = '';
  List<int> vals = [];
  List<String> keys = [];
  String name = '';

  EnvData(
      {required int this.val,
      required List<int> this.vals,
      required List<String> this.keys,
      required String this.name}) {
    set(val);
  }

  void set(int? v) {
    if (v == null || vals.length == 0 || keys.length == 0) return;
    val = vals[vals.length - 1];
    key = keys[keys.length - 1];
    for (var i = 0; i < vals.length; i++) {
      if (v <= vals[i]) {
        val = vals[i];
        key = keys[i];
        break;
      }
    }
  }
}

/// Environment
class Environment {
  /// 1=image 2=video
  EnvData take_mode = EnvData(
    val: 2,
    vals: [1, 2],
    keys: ['mode_image', 'mode_video'],
    name: 'take_mode',
  );

  EnvData language_code = EnvData(
    val: 0,
    vals: [0, 1, 2],
    keys: ['auto', 'en', 'ja'],
    name: 'language_code',
  );

  /// Image interval seconds
  EnvData image_interval_sec = EnvData(
    val: 300,
    vals: IS_TEST ? [15, 300] : [60, 300, 1800],
    keys: IS_TEST ? ['15 sec', '5 min'] : ['1 min', '5 min', '30 min'],
    name: 'image_interval_sec',
  );

  /// Video interval seconds
  EnvData video_interval_sec = EnvData(
    val: 600,
    vals: IS_TEST ? [30, 60] : [300, 600],
    keys: IS_TEST ? ['30 sec', '60 sec'] : ['5 min', '10 min'],
    name: 'video_interval_sec',
  );

  /// Screensaver 0=No 1=Yes 2=8 seconds
  EnvData screensaver_mode = EnvData(
    val: 1,
    vals: [1, 2],
    keys: ['stop_button', 'black_screen'],
    name: 'screensaver_mode',
  );

  /// Automatic stop
  EnvData timer_autostop_sec = EnvData(
    val: 3600,
    vals: IS_TEST ? [120, 3600] : [3600, 7200, 14400, 43200, 86400],
    keys: IS_TEST ? ['2 min', '60 min'] : ['1 hour', '2 hour', '4 hour', '12 hour', '24 hour'],
    name: 'timer_autostop_sec',
  );

  EnvData image_camera_height = EnvData(
    val: 720,
    vals: [240, 480, 720, 1080, 2160],
    keys: kIsWeb == false && Platform.isAndroid
        ? ['320X240', '720x480', '1280x720', '1920x1080', '3840x2160']
        : ['352x288', '640x480', '1280x720', '1920x1080', '3840x2160'],
    name: 'image_camera_height',
  );

  EnvData video_camera_height = EnvData(
    val: 480,
    vals: [240, 480],
    keys: kIsWeb == false && Platform.isAndroid ? ['320X240', '720x480'] : ['352x288', '640x480'],
    name: 'video_camera_height',
  );

  /// Zoom (x10)
  EnvData camera_zoom = EnvData(
    val: 10,
    vals: [10, 15, 20, 25, 30, 35, 40],
    keys: ['1.0', '1.5', '2.0', '2.5', '3.0', '3.5', '4.0'],
    name: 'camera_zoom',
  );

  /// 0=back, 1=Front(Face)
  EnvData camera_pos = EnvData(
    val: 0,
    vals: [0, 1],
    keys: ['back', 'front'],
    name: 'camera_pos',
  );

  EnvData in_save_mb = EnvData(
    val: 1000,
    vals: IS_TEST ? [100, 1000] : [500, 1000, 2000, 4000],
    keys: IS_TEST ? ['100 MB', '1000 MB'] : ['500 MB', '1 GB', '2 GB', '4 GB'],
    name: 'in_save_mb',
  );

  Future save(EnvData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(data.name, data.val);
  }
}

final environmentProvider = ChangeNotifierProvider((ref) => environmentNotifier(ref));

class environmentNotifier extends ChangeNotifier {
  Environment env = Environment();

  environmentNotifier(ref) {
    load().then((_) {
      this.notifyListeners();
    });
  }

  Future load() async {
    if (kIsWeb) return;
    print('-- env load()');
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _loadSub(prefs, env.take_mode);
      _loadSub(prefs, env.language_code);
      _loadSub(prefs, env.image_interval_sec);
      _loadSub(prefs, env.video_interval_sec);
      _loadSub(prefs, env.screensaver_mode);
      _loadSub(prefs, env.timer_autostop_sec);
      _loadSub(prefs, env.image_camera_height);
      _loadSub(prefs, env.video_camera_height);
      _loadSub(prefs, env.camera_zoom);
      _loadSub(prefs, env.camera_pos);
      _loadSub(prefs, env.in_save_mb);
    } on Exception catch (e) {
      print('-- err load() e=' + e.toString());
    }
  }

  _loadSub(SharedPreferences prefs, EnvData data) {
    data.set(prefs.getInt(data.name) ?? data.val);
  }

  Future saveData(String name, int newVal) async {
    EnvData data = getData(name);
    if (data.val == newVal) return;
    data.set(newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(data.name, data.val);
    this.notifyListeners();
  }

  EnvData getData(String name) {
    EnvData ret = env.take_mode;
    switch (name) {
      case 'take_mode':
        ret = env.take_mode;
        break;
      case 'language_code':
        ret = env.language_code;
        break;
      case 'image_interval_sec':
        ret = env.image_interval_sec;
        break;
      case 'video_interval_sec':
        ret = env.video_interval_sec;
        break;
      case 'timer_autostop_sec':
        ret = env.timer_autostop_sec;
        break;
      case 'screensaver_mode':
        ret = env.screensaver_mode;
        break;
      case 'image_camera_height':
        ret = env.image_camera_height;
        break;
      case 'video_camera_height':
        ret = env.video_camera_height;
        break;
      case 'camera_zoom':
        ret = env.camera_zoom;
        break;
      case 'camera_pos':
        ret = env.camera_pos;
        break;
      case 'in_save_mb':
        ret = env.in_save_mb;
        break;
    }
    return ret;
  }
}
