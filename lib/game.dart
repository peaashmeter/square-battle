import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_battle/bot.dart';
import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/global.dart';
import 'package:flutter_battle/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

import 'cell.dart';

class Game extends StatefulWidget {
  const Game(
    this.token, {
    Key? key,
  }) : super(key: key);
  final String token;

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> {
  @override
  void initState() {
    runBot(widget.token);
    super.initState();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    xSize = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: Platform.isAndroid
          ? AppBar(
              backgroundColor: Colors.blueGrey[900],
              title: const Text(
                'SquareBattle',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: const GameGrid(),
    );
  }
}

class GameGrid extends StatefulWidget {
  const GameGrid({Key? key}) : super(key: key);

  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid> {
  late Stream turnStream;
  late Player player;

  @override
  void initState() {
    state = GameState();
    screenshotController = ScreenshotController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ValueListenableBuilder(
          valueListenable: state.cellsNotifier,
          builder: (context, List<Cell> cells, child) {
            return Screenshot(
              controller: screenshotController,
              child: SizedBox(
                child: Stack(
                  children: [
                    Container(
                      height: xSize,
                      color: Colors.black,
                    ),
                    GridView.count(
                        key: GlobalKey(),
                        crossAxisCount: 9,
                        children: List.generate(
                          state.turnManager.getSize() *
                              state.turnManager.getSize(),
                          (i) => Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: cells[i].getWidget(),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
    );
  }
}

Future<File> takeScreenshot() async {
  // RenderRepaintBoundary boundary =
  //     key.currentContext?.findRenderObject() as RenderRepaintBoundary;

  // ui.Image image = await boundary.toImage();
  // var byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  var directory = await getApplicationDocumentsDirectory();
  var file = await File('${directory.path}/turn${state.turnManager.turn}.png')
      .create();

  var bytes = await screenshotController.capture();

  return file.writeAsBytes(bytes!);
}
