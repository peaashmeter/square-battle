import 'dart:math';

import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/team.dart';
import 'package:nyxx/nyxx.dart';

import 'main.dart';

///Синглтон, отвечает за действия игроков
class PlayerManager {
  List<Player> players = [];

  void addPlayer(IUser user, Team team) {
    if (players.where((p) => p.user == user).isNotEmpty) {
      players.removeWhere((p) => p.user == user);
    }
    players
        .add(Player(startPositions[team]!, team, startRotations[team]!, user));
  }

  bool checkIfPlayersReady() {
    if (players.where((p) => !p.isTurnMade).isNotEmpty) {
      return false;
    }
    return true;
  }

  void checkIfPlayersDead() {
    for (var player in players) {
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
  }

  void removePlayer(IUser user) {
    players.removeWhere((player) => player.user == user);
  }

  static Map<Team, Point<int>> startPositions = {
    Team.red: const Point(2, 0),
    Team.orange: const Point(6, 0),
    Team.yellow: const Point(8, 2),
    Team.green: const Point(8, 6),
    Team.blue: const Point(2, 8),
    Team.indigo: const Point(6, 8),
    Team.brown: const Point(0, 2),
    Team.white: const Point(0, 6),
  };
  static Map<Team, Rotation> startRotations = {
    Team.red: Rotation.down,
    Team.orange: Rotation.down,
    Team.yellow: Rotation.left,
    Team.green: Rotation.left,
    Team.blue: Rotation.up,
    Team.indigo: Rotation.up,
    Team.brown: Rotation.right,
    Team.white: Rotation.right,
  };

  static List<int> get nearestPoints {
    List<int> points = [];

    //восемь точек вокруг клетки самым очевидным способом
    for (var p in startPositions.values) {
      points.add(p.x + p.y * 9);
      points.add(p.x - 1 + p.y * 9);
      points.add(p.x + 1 + p.y * 9);
      points.add(p.x + (p.y + 1) * 9);
      points.add(p.x + (p.y - 1) * 9);
      points.add(p.x + 1 + (p.y + 1) * 9);
      points.add(p.x + 1 + (p.y - 1) * 9);
      points.add(p.x - 1 + (p.y + 1) * 9);
      points.add(p.x - 1 + (p.y - 1) * 9);
    }

    return points;
  }

  ///Перемещает мертвых в конец списка, перемешивает живых
  void switchPlayers() {
    List<Player> playersSwitched = [];
    var alivePlayers = players.where((player) => player.isAlive).toList();
    if (alivePlayers.length > 1) {
      playersSwitched.addAll(alivePlayers.getRange(1, alivePlayers.length));
      playersSwitched.add(alivePlayers.first);
    } else if (alivePlayers.isNotEmpty) {
      playersSwitched.add(alivePlayers.first);
    }

    var deadPlayers = players.where((player) => !player.isAlive).toList();
    playersSwitched.addAll(List.from(deadPlayers));

    players = List.from(playersSwitched);
  }
}
