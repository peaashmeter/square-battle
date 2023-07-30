import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_battle/cell.dart';
import 'package:flutter_battle/playermanager.dart';
import 'package:flutter_battle/turnmanager.dart';
import 'package:nyxx/nyxx.dart';

import 'entitymanager.dart';

class GameState {
  late TurnManager turnManager;
  late PlayerManager playerManager;
  late EntityManager entityManager;

  late bool isStartingGame;

  late IMessage? gameMessage;

  late ValueNotifier<List<Cell>> cellsNotifier;

  GameState() {
    const numberOfHoles = 4;

    List<int> holes = [];

    //генерируем выбитую точку, пока не сгенерируем допустимую
    for (var i = 0; i < numberOfHoles; i++) {
      while (true) {
        var hole = Random().nextInt(81);

        if (!PlayerManager.nearestPoints.contains(hole)) {
          holes.add(hole);
          break;
        }
      }
    }

    cellsNotifier = ValueNotifier(
        List.generate(81, (i) => Cell(Point(i % 9, i ~/ 9), true)));

    for (var hole in holes) {
      cellsNotifier.value[hole] = Cell(Point(hole % 9, hole ~/ 9), false);
    }

    turnManager = TurnManager(
      1,
    );
    entityManager = EntityManager();
    playerManager = PlayerManager();
    gameMessage = null;

    isStartingGame = false;
  }

  void resetGame() {
    const numberOfHoles = 4;

    List<int> holes = [];

    //генерируем выбитую точку, пока не сгенерируем допустимую
    for (var i = 0; i < numberOfHoles; i++) {
      while (true) {
        var hole = Random().nextInt(81);

        if (!PlayerManager.nearestPoints.contains(hole)) {
          holes.add(hole);
          break;
        }
      }
    }

    cellsNotifier.value =
        (List.generate(81, (i) => Cell(Point(i % 9, i ~/ 9), true)));

    for (var hole in holes) {
      cellsNotifier.value[hole] = Cell(Point(hole % 9, hole ~/ 9), false);
    }

    turnManager = TurnManager(
      1,
    );
    entityManager = EntityManager();
    playerManager = PlayerManager();
    gameMessage = null;

    isStartingGame = false;
  }
}
