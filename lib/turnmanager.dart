import 'package:flutter_battle/ai/ai.dart';
import 'package:flutter_battle/bot/bot.dart';
import 'package:flutter_battle/cell.dart';
import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/global.dart';

import 'main.dart';

///Синглтон, отвечает за механики, основанные на номере хода
class TurnManager {
  int turn;
  bool isPlaying;

  static const roundLength = 10;
  static const gameLength = 50;

  TurnManager(this.turn, [this.isPlaying = false]);

  ///Ширина (да и высота) поля
  int getSize() {
    //return 9 - (turn ~/ 10) * 2;
    return 9;
  }

  int getIteration() {
    return (turn ~/ roundLength) > 3 ? 3 : (turn ~/ roundLength);
  }

  ///Deprecated
  void checkIfDead(Player player) {
    //проверка на смэрть

    if (state.cellsNotifier.value
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
          state.playerManager.players
              .where((p) => p.isAlive)
              .where((p2) => !p2.isTurnMade)
              .isNotEmpty) {
        return;
      }
    }

    if (isPlaying) {
      turn++;
      doGameCycle();
    }
  }

  void doGameCycle() {
    checkIfGameEnded();
    var size = getSize();

    var cells = List<Cell>.from(state.cellsNotifier.value);

    handlePlayers(size, cells);

    handleBoardSize(cells);

    //проверка на смерть после того, как просчитали ход последнего игрока и мертвые клетки
    state.entityManager.removeDead();
    state.playerManager.checkIfPlayersDead();

    //отрисовка сущностей и игроков
    handleCells(cells);

    //перерисовка поля здесь
    state.cellsNotifier.value = cells;

    for (var player in state.playerManager.players) {
      player.isTurnMade = false;
    }

    state.playerManager.switchPlayers();

    //в этот момент надо удалить старое сообщение с информацией и прислать новое, чтобы оно всегда было внизу истории сообщений
    resendGameMessage();

    scheduleBotsActions();
  }

  void checkIfGameEnded() {
    if (turn == gameLength) {
      isPlaying = false;
      Future.delayed(const Duration(seconds: 10), (() => state.resetGame()));
    }
    if (state.playerManager.players.where((p) => p.isAlive).length == 1) {
      isPlaying = false;
      Future.delayed(const Duration(seconds: 10), (() => state.resetGame()));
    }
  }

  void handleCells(List<Cell> cells) {
    for (var cell in cells) {
      if (!cell.isAlive) {
        continue;
      }

      if (state.playerManager.players
          .where((p) => p.position == cell.position && p.isAlive)
          .isNotEmpty) {
        cell.entity = state.playerManager.players
            .where((p) => p.position == cell.position && p.isAlive)
            .first;
      } else if (state.entityManager.entities
          .where((e) => e.position == cell.position)
          .isNotEmpty) {
        cell.entity = state.entityManager.entities
            .where((e) => e.position == cell.position)
            .first;
      } else {
        cell.entity = null;
      }
    }
  }

  void handleBoardSize(List<Cell> cells) {
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
  }

  void handlePlayers(int size, List<Cell> cells) {
    for (var player in state.playerManager.players) {
      //Убираем мертвых
      state.entityManager.removeDead();
      state.playerManager.checkIfPlayersDead();

      if (!player.isAlive) {
        continue;
      }
      //считаем деньги

      player.money += player.countIncome();
      player.totalScore += player.countIncome();
      player.action?.call();
      player.rotationAction?.call();

      player.action = null;
      player.rotationAction = null;

      var linearPos = player.position.y * size + player.position.x;
      if (isPlaying) {
        cells[linearPos].team = player.team;
      }
    }
  }

  void initGame() {
    // var size = getSize();
    // var cells = List<Cell>.from(state.cellsNotifier.value);

    // for (var player in state.playerManager.players) {
    //   var linearPos = player.position.y * size + player.position.x;
    //   cells[linearPos].entity = player;

    //   cells[linearPos].team = player.team;
    // }
    // state.cellsNotifier.value = cells;
    // scheduleBotsActions();

    doGameCycle();
  }
}
