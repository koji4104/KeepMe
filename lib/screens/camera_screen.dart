import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'photolist_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:record/record.dart';

import 'package:intl/intl.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '/controllers/camera_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'log_screen.dart';
import '/controllers/mystorage.dart';
import 'camera_adapter.dart';
import '/controllers/environment.dart';
import '/constants.dart';
import '/commons/widgets.dart';
import '/commons/base_screen.dart';
import '/models/camera_model.dart';

bool disableCamera = IS_TEST || (Platform.isAndroid == false && Platform.isIOS == false); // true=test

const Color COL_TEXT = Color(0xFFA0A0A0);

const POS_TOP = 50.0;
const POS_BOTTOM = 40.0;
const POS_LEFTRIGHT = 50.0;

class CameraScreen extends BaseScreen with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Record _record = Record();
  StateData _state = StateData();

  int _takeCount = 0;
  int _deletedCount = 0;

  DateTime? _imageTime;
  DateTime? _videoTime;

  bool get isImageRecording {
    return _imageTime != null;
  }

  bool get isVideoRecording {
    return _videoTime != null;
  }

  int get imageSec {
    return _imageTime != null ? DateTime.now().difference(_imageTime!).inSeconds : -1;
  }

  int get videoSec {
    return _videoTime != null ? DateTime.now().difference(_videoTime!).inSeconds : -1;
  }

  bool _bLogExstrageFull = true;

  Timer? _timer;
  ResolutionPreset _preset = ResolutionPreset.high; // 1280x720
  ImageFormatGroup _imageFormat = ImageFormatGroup.bgra8888;
  int _zoom = 10;

  final Battery _battery = Battery();
  int _batteryLevel = -1;
  int _batteryLevelStart = -1;
  late MyStorageNotifier mystorage;
  bool enabledSystemUIMode = false;

  @override
  Future init() async {
    print('-- CameraScreen.init()');
    _timer = Timer.periodic(Duration(seconds: 1), _onTimer);
    _initCameraSync(ref);
    if (Platform.isAndroid || Platform.isIOS) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (_controller != null) _controller!.dispose();
    if (_timer != null) _timer!.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isAndroid || Platform.isIOS) {
      if(state == AppLifecycleState.inactive) {
        print('-- inactive');
      } else if(state == AppLifecycleState.paused) {
        print('-- paused');
      } else if(state == AppLifecycleState.resumed) {
        print('-- resumed');
      } else if(state == AppLifecycleState.detached) {
        print('-- detached');
      }
      if (_state.isRunning == true) {
        if (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) {
          MyLog.warn("App is inactive.");
          onStop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this._state = ref.watch(stateProvider).state;
    this.mystorage = ref.watch(myStorageProvider);
    super.build(context, ref);

    if (kIsWeb == false) {
      if (_state.isScreensaver) {
        if (enabledSystemUIMode == false) {
          print('-- setEnabledSystemUIMode');
          enabledSystemUIMode = true;
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
          WakelockPlus.enable();
        }
      } else {
        if (enabledSystemUIMode == true) {
          enabledSystemUIMode = false;
        }
      }
    }

    if (_zoom != env.camera_zoom.val) {
      print('-- zoom ${env.camera_zoom.val}');
      zoomCamera(env.camera_zoom.val);
    }

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      body: Container(
        margin: edge.homebarEdge,
        child: Stack(
          children: <Widget>[
            // Screen Saver
            if (_state.isScreensaver == true)
              blackScreen(
                onPressed: () {
                  ref.read(stateProvider).showWaitingScreen();
                },
              ),

            // STOP
            if (_state.isScreensaver == true)
              if (env.screensaver_mode.val == 1 || (env.screensaver_mode.val == 2 && _state.waitTime != null))
                stopButton(
                  onPressed: () {
                    ref.read(stateProvider).hideWaitingScreen();
                    ref.read(stateProvider).stop();
                  },
                ),

            if ((_state.isScreensaver == false && env.screensaver_mode.val != 0)) cameraWidget(context),

            // START
            if (_state.isScreensaver == false)
              recordButton(
                onPressed: () {
                  ref.read(stateProvider).showWaitingScreen();
                  onStart();
                },
              ),

            // Camera Switch button
            if (_state.isScreensaver == false)
              MyIconButton(
                bottom: POS_BOTTOM,
                right: POS_LEFTRIGHT,
                icon: Icon(Icons.autorenew, color: Colors.white),
                onPressed: () => _onCameraSwitch(ref),
              ),

            // PhotoList button
            if (_state.isScreensaver == false)
              MyIconButton(
                top: POS_TOP,
                right: POS_LEFTRIGHT,
                icon: Icon(Icons.folder, color: Colors.white),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PhotoListScreen(),
                    ),
                  );
                },
              ),

            // Option (Zoom) button
            if (_state.isScreensaver == false) optionButton(context),

            // Settings button
            if (_state.isScreensaver == false)
              MyIconButton(
                top: POS_TOP,
                left: POS_LEFTRIGHT,
                icon: Icon(Icons.settings, color: Colors.white),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SettingsScreen(),
                  ));
                  if (_preset != getPreset()) {
                    print('-- change camera ${env.image_camera_height.val}');
                    _preset = getPreset();
                    _initCameraSync(ref);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget optionButton(BuildContext context) {
    int z = env.camera_zoom.val;
    String s = (z / 10.0).toStringAsFixed(1);
    double b = 48.0;
    double w = 50.0;
    double x0 = POS_LEFTRIGHT + w * 0;
    double x1 = POS_LEFTRIGHT + w * 1;
    double x2 = POS_LEFTRIGHT + w * 2;

    return Stack(
      children: <Widget>[
        MyIconButton(
          bottom: POS_BOTTOM,
          left: x0,
          icon: Icon(Icons.remove),
          iconSize: 30.0,
          onPressed: () async {
            zoomCamera(z - 5);
          },
        ),
        Positioned(
          bottom: POS_BOTTOM,
          left: x1,
          child: Container(
            width: b,
            height: b,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
                child: Text(s, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white))),
          ),
        ),
        MyIconButton(
          bottom: POS_BOTTOM,
          left: x2,
          icon: Icon(Icons.add),
          iconSize: 30.0,
          onPressed: () async {
            zoomCamera(z + 5);
          },
        ),
      ],
    );
  }

  /// Zoom
  Future<void> zoomCamera(int zoom) async {
    if (this._zoom == zoom) return;

    if (disableCamera) {
      print('-- zoom=${zoom}');
      if (zoom > 40) zoom = 40;
      if (zoom < 10) zoom = 10;
      ref.read(environmentProvider).saveData(env.camera_zoom.name, zoom);
      this._zoom = zoom;
      return;
    }
    if (_controller == null) return;
    if (zoom > 40) zoom = 40;
    if (zoom < 10) zoom = 10;
    try {
      _controller!.setZoomLevel(zoom / 10.0);
    } catch (e) {
      await MyLog.err('${e.toString()} zoomCamera()');
    }
    this._zoom = zoom;
    ref.read(environmentProvider).saveData(env.camera_zoom.name, zoom);
  }

  /// camera Widget
  Widget cameraWidget(BuildContext context) {
    try {
    if (disableCamera) {
      if (IS_SAMPLE) {
        return Center(
          child: Transform.scale(
            //scale: 4.0,
            scale: 4.0,
            //origin: Offset(22, -6),
            origin: Offset(56, -16),
            child: kIsWeb
                ? Image.network('/lib/assets/sample.jpg', fit: BoxFit.cover)
                : Image(image: AssetImage('lib/assets/sample.jpg')),
          ),
        );
      } else {
        return Positioned(left: 0, top: 0, right: 0, bottom: 0, child: Container(color: Color(0xFF222222)));
      }
    }

    if (_controller == null || _controller!.value.previewSize == null) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(),
        ),
      );
    }

    Size _screenSize = MediaQuery.of(context).size;
    Size _cameraSize = _controller!.value.previewSize!;
    double sw = _screenSize.width;
    double sh = _screenSize.height;
    double dw = sw > sh ? sw : sh;
    double dh = sw > sh ? sh : sw;
    double _aspect = sw > sh ? _controller!.value.aspectRatio : 1 / _controller!.value.aspectRatio;

    // 16:10 (Up-down black) or 17:9 (Left-right black)
    // e.g. double _scale = dw/dh < 16.0/9.0 ? dh/dw * 16.0/9.0 : dw/dh * 9.0/16.0;
    double _scale = dw / dh < _cameraSize.width / _cameraSize.height
        ? dh / dw * _cameraSize.width / _cameraSize.height
        : dw / dh * _cameraSize.height / _cameraSize.width;

    print('-- screen=${sw.toInt()}x${sh.toInt()}'
        ' camera=${_cameraSize.width.toInt()}x${_cameraSize.height.toInt()}'
        ' aspect=${_aspect.toStringAsFixed(2)}'
        ' scale=${_scale.toStringAsFixed(2)}');

    return Center(
      child: Transform.scale(
        scale: _scale,
        child: AspectRatio(
          aspectRatio: _aspect,
          child: CameraPreview(_controller!),
        ),
      ),
    );
    } catch (e) {
      print('-- cameraWidget=${e}');
      return Positioned(left: 0, top: 0, right: 0, bottom: 0, child: Container(color: Color(0xFF442222)));
    }
  }

  /// カメラ初期化
  Future<void> _initCameraSync(WidgetRef ref) async {
    if (disableCamera || IS_SAMPLE) return;
    print('-- _initCameraSync()');
    _cameras = await availableCameras();
    int pos = env.camera_pos.val;
    if (_cameras.length <= 0) {
      MyLog.err("Camera not found");
      return;
    }
    if (_cameras.length == 1) {
      pos = 0;
    }
    _controller = CameraController(
      _cameras[pos],
      _preset,
      imageFormatGroup: _imageFormat,
      enableAudio: false,
    );
    _controller!.initialize().then((_) {
      redraw();
    });
  }

  /// スイッチ
  Future<void> _onCameraSwitch(WidgetRef ref) async {
    if (disableCamera || _cameras.length < 2) return;

    int pos = env.camera_pos.val == 0 ? 1 : 0;
    env.camera_pos.set(pos);
    env.save(env.camera_pos);

    await _controller!.dispose();
    _controller = CameraController(
      _cameras[pos],
      _preset,
      imageFormatGroup: _imageFormat,
      enableAudio: false,
    );
    try {
      _controller!.initialize().then((_) {
        redraw();
      });
    } catch (e) {
      await MyLog.err('${e.toString()} onCameraSwitch()');
    }
    _zoom = 10;
  }

  /// START
  Future<bool> onStart() async {
    if (disableCamera) {
      ref.read(stateProvider).start();
    } else {
      if (_controller == null || _controller!.value.isInitialized == false) {
        print('-- err _controller!.value.isInitialized==false');
        return false;
      }
    }

    if (await deleteOldFiles() == false) {
      print('-- err deleteOldFiles');
      return false;
    }

    _imageTime = null;
    _batteryLevelStart = await _battery.batteryLevel;
    _bLogExstrageFull = true;

    // 先にセーバーを起動
    ref.read(stateProvider).start();

    _takeCount = 0;
    _deletedCount = 0;
    if (env.take_mode.val == 1) takeImage();
    if (env.take_mode.val == 2) startVideo();

    await MyLog.info("Start");
    return true;
  }

  /// STOP
  Future<void> onStop() async {
    print('-- onStop');
    try {
      String s = 'Stop';
      if (_state.startTime != null) {
        Duration dur = DateTime.now().difference(_state.startTime!);
        if (dur.inMinutes > 0) s += ' ${dur.inMinutes}min';
      }
      _state.startTime = null;

      if (_batteryLevel > 0 && _batteryLevelStart - _batteryLevel > 0) {
        s += ' batt ${_batteryLevelStart}->${_batteryLevel}%';
      }
      await MyLog.info(s);

      if (_deletedCount > 0) {
        MyLog.info('Deleted old files ${_deletedCount}');
        _deletedCount = 0;
      }

      ref.read(stopButtonProvider.notifier).state = '';
      if (disableCamera == false) {
        if (env.take_mode.val == 1) if (_controller!.value.isStreamingImages) await _controller!.stopImageStream();
        if (env.take_mode.val == 2) await stopVideo();

        await Future.delayed(Duration(milliseconds: 100));
        await _deleteCacheDir();
      }
    } on Exception catch (e) {
      print('-- onStop() Exception ' + e.toString());
    }
  }

  /// Take image
  Future<void> takeImage() async {
    print("-- takeImage()");
    if (kIsWeb) return;
    _imageTime = null;
    DateTime dt = DateTime.now();
    try {
      String path = "";
      bool isImage = false;
      if (Platform.isIOS) {
        imglib.Image? img = await CameraAdapter.takeImage(_controller);
        if (img != null) {
          path = await getSavePath('.jpg');
          final File file = File(path);
          await file.writeAsBytes(imglib.encodeJpg(img));
          isImage = true;
        } else {
          print('-- iOS takeImage img=null');
        }
      } else {
        // android
        try {
          XFile xfile = await _controller!.takePicture();
          path = await getSavePath('.jpg');
          await moveFile(src: xfile.path, dst: path);
          isImage = true;
        } catch (e) {
          await MyLog.err('${e.toString()} takePhoto()');
        }
      }
      if (isImage) {
        _takeCount++;
        print("-- takeImage() _takeCount=${_takeCount}");
      } else {
        print("-- err takeImage() isImage=false");
      }
      _imageTime = dt;
    } catch (e) {
      await MyLog.err('${e.toString()} takePhoto()');
    }
  }

  Future<void> startVideo() async {
    print("-- startVideo");
    if (kIsWeb) return;
    try {
      await _controller!.startVideoRecording();
      _videoTime = DateTime.now();
    } on CameraException catch (e) {
      MyLog.err('${e.code} ${e.description} startVideo()');
    } catch (e) {
      MyLog.err('${e.toString()} startVideo()');
    }
  }

  Future<void> stopVideo() async {
    print("-- stopVideo");
    if (kIsWeb) return;
    try {
      _videoTime = null;
      XFile xfile = await _controller!.stopVideoRecording();
      String path = await getSavePath('.mp4');
      moveFile(src: xfile.path, dst: path); // not await
      _takeCount++;
    } catch (e) {
      await MyLog.err('${e.toString()} stopVideo()');
    }
  }

  Future<File> moveFile({required String src, required String dst}) async {
    File srcfile = File(src);
    try {
      for (var i = 0; i < 10; i++) {
        if (await srcfile.exists()) {
          return await srcfile.rename(dst);
        } else {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
      MyLog.warn('move file not exists src=${src}');
      return srcfile;
    } on FileSystemException catch (e) {
      MyLog.err('move file e=${e.message} path=${e.path}');
      final newfile = await srcfile.copy(dst);
      await srcfile.delete();
      return newfile;
    }
  }

  /// Timer
  void _onTimer(Timer timer) async {
    if (this._batteryLevel < 0) {
      this._batteryLevel = 0;
      this._batteryLevel = await _battery.batteryLevel;
    }
    // 停止ボタンを押したとき
    if (_state.isRunning == false && _state.startTime != null) {
      onStop();
      return;
    }

    // スクリーンセーバー中
    if (_state.isScreensaver == true) {
      if (env.screensaver_mode.val == 1) {
        ref.read(stopButtonProvider.notifier).state = takingString();
      } else if (env.screensaver_mode.val == 2 && _state.waitTime != null) {
        if (DateTime.now().difference(_state.waitTime!).inSeconds >= 8) {
          ref.read(stateProvider).hideWaitingScreen();
        }
        ref.read(stopButtonProvider.notifier).state = takingString();
      }
    }

    // 自動停止
    if (_state.isRunning == true && _state.startTime != null && env.timer_autostop_sec.val >= 1) {
      Duration dur = DateTime.now().difference(_state.startTime!);
      if (dur.inSeconds > env.timer_autostop_sec.val) {
        await MyLog.info("Autostop");
        onStop();
        ref.read(stateProvider).autostop();
        return;
      }
    }

    // バッテリーチェック（1分毎）
    if (_state.isRunning == true && DateTime.now().second == 0) {
      this._batteryLevel = await _battery.batteryLevel;
      if (this._batteryLevel < 10) {
        await MyLog.warn("Low battery");
        onStop();
        return;
      }
    }

    // インターバル
    if (_state.isRunning == true) {
      if (_imageTime != null && imageSec > env.image_interval_sec.val) {
        if (await deleteOldFiles()) {
          takeImage();
        } else {
          onStop();
        }
      }
      if (_videoTime != null && videoSec > env.video_interval_sec.val) {
        if (await deleteOldFiles()) {
          await stopVideo();
          await startVideo();
        } else {
          onStop();
        }
      }
    }
  } // _onTimer

  // kf-2023-1201-181000.mp4
  // a-keepme-2023-1201-181000.mp4
  Future<String> getSavePath(String ext) async {
    final Directory appdir = await getApplicationDocumentsDirectory();
    final String dirPath = '${appdir.path}/files';
    await Directory(dirPath).create(recursive: true);
    String dt = DateFormat("yyyy-MMdd-HHmmss").format(DateTime.now());
    return '${dirPath}/${dt}${ext}';
  }

  /// 古いファイルを消す
  Future<bool> deleteOldFiles() async {
    if (disableCamera) return true;
    try {
      // アプリ内で上限を超えた古いものを削除（消す前に呼ばれる）
      await mystorage.getInApp(false);
      int totalMb = mystorage.inappTotalMb;
      for (int i = 0; i < 500; i++) {
        if (env.in_save_mb.val > totalMb) break;
        print('-- removeLast totalMb=${totalMb} delCount=${_deletedCount}');
        int byte = mystorage.inappFiles.last.byte;
        await File(mystorage.inappFiles.last.path).delete();
        mystorage.inappFiles.removeLast();
        totalMb -= (byte / 1024 / 1024).toInt();
        _deletedCount++;
      }
    } on Exception catch (e) {
      await MyLog.err('${e.toString()} deleteOldFiles()');
      return false;
    }
    return true;
  }

  /// キャッシュ削除
  Future<void> _deleteCacheDir() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        List<FileSystemEntity> files = cacheDir.listSync(recursive: true, followLinks: false);
        if (files.length > 0) {
          for (FileSystemEntity e in files) {
            try {
              await File(e.path).delete();
              //print('-- del ok ${basename(e.path)}');
            } on Exception catch (err) {
              //print('-- del err ${basename(e.path)}');
            }
          }
        }
      }
    } on Exception catch (e) {
      print('-- Exception _deleteCacheDir() e=' + e.toString());
    }
  }

  @override
  bool get wantKeepAlive => true;

  Widget recordButton({required void Function()? onPressed}) {
    Icon icon = (env.take_mode.val == 1)
        ? Icon(Icons.camera_alt, color: Colors.white)
        : Icon(Icons.videocam, color: Colors.white);
    return Center(
      child: Container(
        width: 160,
        height: 160,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          child: IconButton(
            icon: icon,
            iconSize: 48,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  Widget stopButton({required void Function()? onPressed}) {
    String text = ref.watch(stopButtonProvider);

    EdgeInsetsGeometry ed = EdgeInsets.only(left: 0.0);
    int sd = ((DateTime.now().second / 10) % 3).toInt();
    if (sd == 0) ed = EdgeInsets.only(right: 4.0);
    if (sd == 2) ed = EdgeInsets.only(left: 4.0);

    return Center(
      child: Container(
        margin: ed,
        width: 160,
        height: 160,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.black26,
            shape: const CircleBorder(
              side: BorderSide(
                color: COL_TEXT,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
          ),
          child: Text(text, style: TextStyle(fontSize: 16, color: COL_TEXT), textAlign: TextAlign.center),
          onPressed: onPressed,
        ),
      ),
    );
  }

  String takingString() {
    String s = '';
    if (_timer == null) {
      s = '--';
    } else if (_state.isRunning == false) {
      s = 'STOPPED';
    } else if (_state.startTime != null && _state.isRunning) {
      Duration dur = DateTime.now().difference(_state.startTime!);
      s = dur2str(dur);
    }
    return s;
  }

  /// 01:00:00
  String dur2str(Duration dur) {
    String s = "";
    if (dur.inHours > 0) s += dur.inHours.toString() + ':';
    s += dur.inMinutes.remainder(60).toString().padLeft(2, '0') + ':';
    s += dur.inSeconds.remainder(60).toString().padLeft(2, '0');
    return s;
  }

  Widget blackScreen({required void Function()? onPressed}) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: TextButton(
        child: Text(''),
        style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.black)),
        onPressed: onPressed,
      ),
    );
  }

  // low 320x240 (4:3)
  // medium 640x480 (4:3)
  // high 1280x720
  // veryHigh 1920x1080
  // ultraHigh 3840x2160
  ResolutionPreset getPreset() {
    ResolutionPreset p = ResolutionPreset.high;
    int h = env.take_mode.val == 1 ? env.image_camera_height.val : env.video_camera_height.val;
    if (h >= 2160)
      p = ResolutionPreset.ultraHigh;
    else if (h >= 1080)
      p = ResolutionPreset.veryHigh;
    else if (h >= 720)
      p = ResolutionPreset.high;
    else if (h >= 480)
      p = ResolutionPreset.medium;
    else if (h >= 240) p = ResolutionPreset.low;
    return p;
  }
}
