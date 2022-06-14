import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/playermanager.dart';
import 'package:flutter_battle/turnmanager.dart';
import 'package:flutter_battle/team.dart';

import 'entitymanager.dart';

late TurnManager turnManager;
late PlayerManager playerManager;
late EntityManager entityManager;

late ValueNotifier<List<Cell>> cellsNotifier;

class Cell {
  ///Что находится внутри клетки
  Entity? entity;

  ///Команда, которой принадлежит (или не принадлежит) клетка
  Team? team;

  bool isAlive;

  final Point<int> position;

  Cell(this.position, this.isAlive);

  Widget getWidget() {
    if (entity is Player) {
      return (entity as Player).getWidget();
    } else if (entity is Wall) {
      return (entity as Wall).getWidget();
    }

    return Container(
      color: getColorByTeam(team),
    );
  }

  Color getColorByTeam(Team? team) {
    if (isAlive) {
      switch (team) {
        case Team.red:
          return Colors.red[900]!;
        case Team.orange:
          return Colors.orange[900]!;
        case Team.yellow:
          return Colors.yellow[700]!;
        case Team.green:
          return Colors.green[900]!;
        case Team.blue:
          return Colors.blue[700]!;
        case Team.indigo:
          return Colors.purple[900]!;
        case Team.brown:
          return Colors.brown[900]!;
        case Team.white:
          return Colors.grey[200]!;
        default:
          return Colors.blueGrey[900]!;
      }
    } else {
      return Colors.black;
    }
  }
}
