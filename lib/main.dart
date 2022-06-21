import 'dart:io';

import 'package:desktop_window/desktop_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_battle/global.dart';
import 'package:flutter_battle/gui.dart';

import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

///ключ для скриншотов
// late GlobalKey key;

late ScreenshotController screenshotController;

///состояние игры
late GameState state;

//горизонтальное разрешение экрана для вычисления размера крестика на стене
late double? xSize;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    DesktopWindow.setWindowSize(const Size(512, 512 + 30));
    DesktopWindow.setMinWindowSize(const Size(512, 512 + 30));
    DesktopWindow.setMaxWindowSize(const Size(512, 512 + 30));
  }

  //

  var prefs = await SharedPreferences.getInstance();

  runApp(Menu(prefs));
}
