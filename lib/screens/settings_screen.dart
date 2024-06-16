import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

import 'log_screen.dart';
import '/controllers/environment.dart';
import '/commons/base_screen.dart';
import '/constants.dart';
import '/commons/widgets.dart';
import '/controllers/mystorage.dart';

/// Settings
class SettingsScreen extends BaseSettingsScreen {
  //late GoogleDriveAdapter gdriveAd;
  late MyStorageNotifier mystorage;

  @override
  Future init() async {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    super.build(context, ref);
    //this.gdriveAd = ref.watch(gdriveProvider).gdrive;
    this.mystorage = ref.watch(myStorageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n("settings_title")),
        backgroundColor: Color(0xFF000000),
        actions: <Widget>[],
      ),
      body: (is2screen())
          ? SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: Stack(
                children: [
                  Container(
                    margin: leftMargin(),
                    child: getList(),
                  ),
                  Container(
                    margin: rightMargin(),
                    child: rightScreen != null ? rightScreen!.getList() : null,
                  )
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: Container(
                margin: edge.settingsEdge,
                child: getList(),
              ),
            ),
    );
  }

  @override
  Widget getList() {
    bool isImage = env.take_mode == 1;
    bool isAudio = env.take_mode == 2;
    bool isVideo = env.take_mode == 4;
    return Column(
      children: [
        MyValue(data: env.take_mode),
        MyValue(data: env.image_interval_sec),
        MyValue(data: env.image_camera_height),
        MyValue(data: env.video_camera_height),
        MyValue(data: env.in_save_mb),
        MyValue(data: env.screensaver_mode),
        MyValue(data: env.timer_mode),
        MyValue(data: env.timer_stop_sec),
        MyLabel(''),
        MyListTile(
          title: MyText('Logs'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LogScreen(),
              ),
            );
          },
        ),
        MyListTile(
          title: MyText('Licenses'),
          onPressed: () async {
            final info = await PackageInfo.fromPlatform();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) {
                return LicensePage(
                  applicationName: l10n('app_name'),
                  applicationVersion: info.version,
                  applicationIcon: Container(
                    padding: EdgeInsets.all(8),
                    child: kIsWeb
                        ? Image.network('/lib/assets/appicon.png',
                            width: 32, height: 32)
                        : Image(
                            image: AssetImage('lib/assets/appicon.png'),
                            width: 32,
                            height: 32),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
