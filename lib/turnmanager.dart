import 'dart:math';

import 'package:flutter_battle/bot.dart';
import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/global.dart';
import 'package:nyxx/nyxx.dart';

import 'team.dart';

///Синглтон, отвечает за механики, основанные на номере хода
class TurnManager {
  int turn;
  bool isPlaying;

  TurnManager(this.turn, [this.isPlaying = false]);

  ///Ширина (да и высота) поля
  int getSize() {
    //return 9 - (turn ~/ 10) * 2;
    return 9;
  }

  int getIteration() {
    return turn ~/ 10;
  }

  ///Deprecated
  void checkIfDead(Player player) {
    //проверка на смэрть

    if (cellsNotifier.value
            .where((cell) => cell.position == player.position)
            .first
            .isAlive ==
        false) {
      player.isAlive = false;
    }

    if (player.hp < 1) {
      player.isAlive = false;
    }
  }

  void updateCells([bool isSkip = false]) {
    if (!isSkip) {
      if (isPlaying &&
          playerManager.players
              .where((p) => p.isAlive)
              .where((p2) => !p2.isTurnMade)
              .isNotEmpty) {
        return;
      }
    }

    if (isPlaying) {
      turn++;
    }

    var size = getSize();

    var cells = List<Cell>.from(cellsNotifier.value);

    for (var player in playerManager.players) {
      //Убираем мертвых
      entityManager.removeDead();
      playerManager.checkIfPlayersDead();

      if (!player.isAlive) {
        continue;
      }
      //считаем деньги

      player.money += player.countIncome();
      player.action?.call();
      player.rotationAction?.call();

      player.action = null;
      player.rotationAction = null;

      var linearPos = player.position.y * size + player.position.x;
      if (isPlaying) {
        cells[linearPos].team = player.team;
      }
    }

    //проверка на смерть после того, как просчитали ход последнего игрока
    entityManager.removeDead();
    playerManager.checkIfPlayersDead();

    for (var cell in cells) {
      if (cell.position.x >= getIteration() &&
          cell.position.x < 9 - getIteration() &&
          cell.position.y >= getIteration() &&
          cell.position.y < 9 - getIteration()) {
      } else {
        cell.isAlive = false;
      }

      //фикс кринжа с отображением
      if (cell.entity is Player) {
        cell.entity = null;
      }
    }

    //отрисовка сущностей и игроков

    for (var cell in cells) {
      if (!cell.isAlive) {
        continue;
      }

      if (playerManager.players
          .where((p) => p.position == cell.position && p.isAlive)
          .isNotEmpty) {
        cell.entity = playerManager.players
            .where((p) => p.position == cell.position && p.isAlive)
            .first;
      } else if (entityManager.entities
          .where((e) => e.position == cell.position)
          .isNotEmpty) {
        cell.entity = entityManager.entities
            .where((e) => e.position == cell.position)
            .first;
      } else {
        cell.entity = null;
      }

      // //отрисовка игроков
      // for (var player in playerManager.players) {
      //   var linearPos = player.position.y * size + player.position.x;

      //   if (player.isAlive) {
      //     cells[linearPos].entity = player;
      //   }
      // }
    }

    /*
    игрок 3
    игрок 4
    игрок 1
    игрок 2 (умер)
    */

    //перерисовка поля здесь
    cellsNotifier.value = cells;

    for (var player in playerManager.players) {
      player.isTurnMade = false;
    }

    playerManager.switchPlayers();

    //в этот момент надо удалить старое сообщение с информацией и прислать новое, чтобы оно всегда было внизу истории сообщений
    resendGameMessage();
  }

  void initGame() {
    var size = getSize();
    var cells = List<Cell>.from(cellsNotifier.value);

    for (var player in playerManager.players) {
      var linearPos = player.position.y * size + player.position.x;
      cells[linearPos].entity = player;

      cells[linearPos].team = player.team;
    }
    cellsNotifier.value = cells;
  }
}
