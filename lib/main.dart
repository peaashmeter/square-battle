import 'dart:io';
import 'dart:math';

import 'dart:ui' as ui;

import 'package:desktop_window/desktop_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_battle/bot.dart';
import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/global.dart';
import 'package:flutter_battle/playermanager.dart';
import 'package:flutter_battle/turnmanager.dart';

import 'entitymanager.dart';

///ключ для скриншотов
late GlobalKey key;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    DesktopWindow.setWindowSize(const Size(512, 512 + 30));
    DesktopWindow.setMinWindowSize(const Size(512, 512 + 30));
    DesktopWindow.setMaxWindowSize(const Size(512, 512 + 30));
  }

  runBot();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    cellsNotifier = ValueNotifier(
        List.generate(81, (i) => Cell(Point(i % 9, i ~/ 9), true)));
    turnManager = TurnManager(
      1,
    );
    playerManager = PlayerManager();
    entityManager = EntityManager();

    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const GameGrid(),
    );
  }
}

class GameGrid extends StatefulWidget {
  const GameGrid({Key? key}) : super(key: key);

  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid> {
  late List<Cell> cells;
  late Stream turnStream;
  late Player player;

  @override
  void initState() {
    key = GlobalKey();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: key,
      child: Container(
        color: Colors.black,
        child: ValueListenableBuilder(
            valueListenable: cellsNotifier,
            builder: (context, List<Cell> cells, child) {
              return GridView.count(
                  crossAxisCount: 9,
                  children: List.generate(
                    turnManager.getSize() * turnManager.getSize(),
                    (i) => Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: cells[i].getWidget(),
                      ),
                    ),
                  ));
            }),
      ),
    );
  }
}

Future<File> takeScreenshot() async {
  RenderRepaintBoundary boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary;

  ui.Image image = await boundary.toImage();
  var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  var file = await File('turns/turn${turnManager.turn}.png').create();
  return file.writeAsBytes(byteData!.buffer.asInt8List());
}
