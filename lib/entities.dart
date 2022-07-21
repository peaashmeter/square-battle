import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

import 'ai/ai.dart';
import 'cell.dart';
import 'main.dart';
import 'team.dart';

enum Rotation { left, up, right, down }

///Базовый класс сущности: игроки, стены и прочее
///Блокирует передвижение
abstract class Entity {
  ///Местоположение
  Point<int> position;

  ///Команда, которой принадлежит сущность
  final Team team;

  Entity(this.position, this.team);

  Widget getWidget();

  Color getColorByTeam(Team team) {
    switch (team) {
      case Team.red:
        return Colors.red;
      case Team.orange:
        return Colors.orange;
      case Team.yellow:
        return Colors.yellow;
      case Team.green:
        return Colors.green;
      case Team.blue:
        return Colors.blue;
      case Team.indigo:
        return Colors.indigo;
      case Team.brown:
        return Colors.brown;
      case Team.white:
        return Colors.white;
      default:
        throw Exception('Чел, че это за цвет, а? $team');
    }
  }
}

///Игрок
class Player extends Entity {
  Rotation rotation;
  final IUser user;
  int hp;

  int totalScore;

  bool isTurnMade;

  ///Если false, то игрок проиграл
  bool isAlive;

  void Function()? action;
  void Function()? rotationAction;

  int money = 0;

  Player(super.position, super.team, this.rotation, this.user,
      [this.isTurnMade = false,
      this.isAlive = true,
      this.money = 0,
      this.hp = 5,
      this.totalScore = 0]);

  int countIncome() {
    var income = state.cellsNotifier.value
        .where((cell) => cell.team == team && cell.isAlive)
        .length;
    return income;
  }

  void moveRight() {
    if (position.x + 1 < state.turnManager.getSize()) {
      var _position = Point(position.x + 1, position.y);
      List<Entity> entities = getEntities();
      if (entities.where((e) => e.position == _position).isNotEmpty) {
        return;
      }
      if (state.cellsNotifier.value
          .where((c) => !c.isAlive && c.position == _position)
          .isNotEmpty) {
        return;
      }
      position = _position;
    }
  }

  void moveLeft() {
    if (position.x != 0) {
      var _position = Point(position.x - 1, position.y);
      List<Entity> entities = getEntities();
      if (entities.where((e) => e.position == _position).isNotEmpty) {
        return;
      }
      if (state.cellsNotifier.value
          .where((c) => !c.isAlive && c.position == _position)
          .isNotEmpty) {
        return;
      }
      position = _position;
    }
  }

  void moveUp() {
    if (position.y != 0) {
      var _position = Point(position.x, position.y - 1);
      List<Entity> entities = getEntities();
      if (entities.where((e) => e.position == _position).isNotEmpty) {
        return;
      }
      if (state.cellsNotifier.value
          .where((c) => !c.isAlive && c.position == _position)
          .isNotEmpty) {
        return;
      }
      position = _position;
    }
  }

  void moveDown() {
    if (position.y + 1 < state.turnManager.getSize()) {
      var _position = Point(position.x, position.y + 1);
      List<Entity> entities = getEntities();
      if (entities.where((e) => e.position == _position).isNotEmpty) {
        return;
      }
      if (state.cellsNotifier.value
          .where((c) => !c.isAlive && c.position == _position)
          .isNotEmpty) {
        return;
      }
      position = _position;
    }
  }

  //Список сущностей, мешающих проходу
  List<Entity> getEntities() {
    var entities = List<Entity>.from(state.entityManager.entities +
        state.playerManager.players.where((p) => p.isAlive).toList());
    return entities;
  }

  void shoot() {
    var shootCost = 6 + state.turnManager.getIteration();

    if (money - shootCost < 0) {
      return;
    }

    money -= shootCost;

    late Point<int> vec;

    switch (rotation) {
      case Rotation.left:
        vec = const Point(-1, 0);
        break;
      case Rotation.up:
        vec = const Point(0, -1);
        break;
      case Rotation.right:
        vec = const Point(1, 0);
        break;
      case Rotation.down:
        vec = const Point(0, 1);
        break;
    }

    const bulletPathLength = 3;
    const bulletMaxDamage = 3;

    Point<int> currentPoint = position + vec;

    for (var i = 0; i < bulletPathLength; i++) {
      if (currentPoint.x < 0 ||
          currentPoint.x > 8 ||
          currentPoint.y < 0 ||
          currentPoint.y > 8 ||
          state.cellsNotifier.value
              .where((c) => c.isAlive)
              .where((cell) => cell.position == currentPoint)
              .isEmpty) {
        break;
      }
      var cell = state.cellsNotifier.value
          .where((c) => c.position == currentPoint)
          .first;
      if (state.playerManager.players
          .where((p) => p.position == currentPoint && p.isAlive)
          .isNotEmpty) {
        state.playerManager.players
            .where((p) => p.position == currentPoint && p.isAlive)
            .first
            .hp -= (bulletMaxDamage - i);
        break;
      } else if (state.entityManager.entities
          .whereType<Wall>()
          .where((p) => p.position == currentPoint)
          .isNotEmpty) {
        var wall = state.entityManager.entities
            .whereType<Wall>()
            .where((p) => p.position == currentPoint)
            .first;

        if (wall.team == team) {
          wall.hp -= wall.hp;
        } else {
          wall.hp -= (bulletMaxDamage - i);
        }

        break;
      } else {
        cell.team = team;

        currentPoint += vec;
      }
    }
  }

  void rotateLeft() {
    var index = rotation.index;
    index -= 1;
    index %= 4;
    rotation = Rotation.values[index];
  }

  void rotateRight() {
    var index = rotation.index;
    index += 1;
    index %= 4;
    rotation = Rotation.values[index];
  }

  void heal() {
    var healBaseCost = 10 + state.turnManager.getIteration();

    if (hp < 5) {
      if (money - healBaseCost >= 0) {
        money -= healBaseCost;

        hp++;
      }
    } else {
      if (money - ((hp - 4) * 5 + healBaseCost) >= 0) {
        money -= ((hp - 4) * 5 + healBaseCost);
        hp++;
      }
    }
  }

  void makeTurn() {
    if (isTurnMade) {
      return;
    }

    isTurnMade = true;

    state.turnManager.updateCells();
  }

  void buildWall() {
    var cost = Wall.cost + state.turnManager.getIteration();
    var targetCellPoint = getPointedCell();
    if (targetCellPoint == null) return;
    if (money - cost < 0) return;

    Cell targetCell = state.cellsNotifier.value
        .where((cell) => cell.position == targetCellPoint)
        .first;

    if (targetCell.isAlive &&
        targetCell.entity == null &&
        targetCell.team == team) {
      state.entityManager.entities.add(Wall(targetCellPoint, team));
      money -= cost;
    }
  }

  Point<int>? getPointedCell() {
    switch (rotation) {
      case Rotation.left:
        if (position.x > 0) {
          return Point(position.x - 1, position.y);
        }
        return null;
      case Rotation.up:
        if (position.y > 0) {
          return Point(position.x, position.y - 1);
        }
        return null;
      case Rotation.right:
        if (position.x < 8) {
          return Point(position.x + 1, position.y);
        }
        return null;
      case Rotation.down:
        if (position.y < 8) {
          return Point(position.x, position.y + 1);
        }
        return null;
      default:
        return null;
    }
  }

  @override
  Widget getWidget() {
    return Container(
      color: getColorByTeam(team),
      child: getArrowByRotation(),
    );
  }

  Widget getArrowByRotation() {
    const arrow = Icons.chevron_left_rounded;
    switch (rotation) {
      case Rotation.left:
        return const Icon(
          arrow,
          size: 32,
        );
      case Rotation.up:
        return Transform.rotate(
            angle: pi / 2, child: const Icon(arrow, size: 32));
      case Rotation.right:
        return Transform.rotate(angle: pi, child: const Icon(arrow, size: 32));
      case Rotation.down:
        return Transform.rotate(
            angle: 3 * pi / 2, child: const Icon(arrow, size: 32));
      default:
        return const Icon(arrow, size: 32);
    }
  }
}

class Wall extends Entity {
  static const cost = 5;
  int hp;
  Wall(super.position, super.team, [this.hp = 3]);

  @override
  Widget getWidget() {
    xSize ??= 48;

    return Container(
        color: getColorByTeam(team),
        child: Icon(
          Icons.close_rounded,
          size: (4 - hp) * (48 * xSize! / (512 * 3)),
        ));

    //48 : 512 = x : size
    //48size = 512x
    //x = 48size/512
  }
}
