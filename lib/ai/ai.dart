import 'dart:math';

import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/entitymanager.dart';
import 'package:flutter_battle/global.dart';

void Function()? getAction(GameState state, Player self) {
  var shootEfficiency = computeShootEfficiency(self, state) +
      efficiencyOfBeingInPoint(self, state);

  var buildEfficiency = computeBuildEfficiency(self, state) +
      efficiencyOfBeingInPoint(self, state);

  var healEfficiency = computeHealEfficiency(self, state) +
      efficiencyOfBeingInPoint(self, state);

  //Эффективность конкретного действия выше эффективности потенциального действия
  const futureCoeff = 2 / 3;

  var moveLeftEfficiency = computeMoveLeftEfficiency(self, state) * futureCoeff;

  var moveUpEfficiency = computeMoveUpEfficiency(self, state) * futureCoeff;

  var moveRightEfficiency =
      computeMoveRightEfficiency(self, state) * futureCoeff;

  var moveDownEfficiency = computeMoveDownEfficiency(self, state) * futureCoeff;

  var stayEfficiency = efficiencyOfBeingInPoint(self, state) * futureCoeff;

  var actions = {
    self.shoot: shootEfficiency,
    self.buildWall: buildEfficiency,
    self.heal: healEfficiency,
    self.moveLeft: moveLeftEfficiency,
    self.moveUp: moveUpEfficiency,
    self.moveRight: moveRightEfficiency,
    self.moveDown: moveDownEfficiency,
    null: stayEfficiency
  };

  var sorted = actions.entries.toList()
    ..sort(((a, b) => b.value.compareTo(a.value)));
  var max = sorted.first.value;

  print('sorted : $sorted');

  var sortedmax = sorted.where((e) => e.value == max).toList();

  //print(sortedmax);

  return sortedmax[Random().nextInt(sortedmax.length)].key;
}

void Function()? getRotationAction(GameState state, Player self) {
  var rotateLeftEfficiency = computeLeftRotationEfficiency(state, self);
  var rotateRightEfficiency = computeRightRotationEfficiency(state, self);
  var noRotateEfficiency = computeNoRotationEfficiency(state, self);

  var actions = {
    self.rotateLeft: rotateLeftEfficiency,
    self.rotateRight: rotateRightEfficiency,
    null: noRotateEfficiency
  };
  var sorted = actions.entries.toList()
    ..sort(((a, b) => b.value.compareTo(a.value)));

  var max = sorted.first.value;

  //print(sorted);

  var sortedmax = sorted.where((e) => e.value == max).toList();

  return sortedmax[Random().nextInt(sortedmax.length)].key;
}

double computeLeftRotationEfficiency(GameState state, Player self) {
  var index = self.rotation.index;
  index -= 1;
  index %= 4;
  var rotation = Rotation.values[index];

  return efficiencyOfBeingInPoint(
      Player(self.position, self.team, rotation, self.user)..money = self.money,
      state);
}

double computeRightRotationEfficiency(GameState state, Player self) {
  var index = self.rotation.index;
  index += 1;
  index %= 4;
  var rotation = Rotation.values[index];

  return efficiencyOfBeingInPoint(
      Player(self.position, self.team, rotation, self.user)..money = self.money,
      state);
}

double computeNoRotationEfficiency(GameState state, Player self) {
  return efficiencyOfBeingInPoint(self, state, true);
}

double computeShootEfficiency(Player self, GameState state) {
  late Point<int> vec;
  if (self.money < 6 + state.turnManager.getIteration()) {
    return 0;
  }

  switch (self.rotation) {
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

  int cellsPrediction = 0;
  int damagePrediction = 0;

  Point<int> currentPoint = self.position + vec;

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
    if (cell.team != self.team) {
      cellsPrediction++;
    }
    if (state.playerManager.players
        .where((p) => p.position == currentPoint && p.isAlive)
        .isNotEmpty) {
      damagePrediction += (bulletMaxDamage - i);
      break;
    } else if (state.entityManager.entities
        .whereType<Wall>()
        .where((p) => p.position == currentPoint)
        .isNotEmpty) {
      var wall = state.entityManager.entities
          .whereType<Wall>()
          .where((p) => p.position == currentPoint)
          .first;

      if (wall.team == self.team) {
      } else {
        damagePrediction += (bulletMaxDamage - i);
      }

      break;
    } else {
      currentPoint += vec;
    }
  }

  var efficiency = damagePrediction / 3 + cellsPrediction / 3;

  return efficiency;
}

double computeBuildEfficiency(Player self, GameState state) {
  late Point<int> vec;

  if (self.money < 5 + state.turnManager.getIteration()) {
    return 0;
  }

  switch (self.rotation) {
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
  //Клетка, в которой будем строить стену
  var targetCells = state.cellsNotifier.value
      .where((cell) => cell.position == self.position + vec);

  if (targetCells.isEmpty) {
    return 0;
  }
  var targetCell = targetCells.first;

  var baseLength = calculatePathLenghtToCenter(self, state);

  var state0 = GameState();
  state0.cellsNotifier = state.cellsNotifier;
  state0.entityManager = EntityManager()
    ..entities = List.from(state.entityManager.entities);
  state0.playerManager = state.playerManager;
  state0.turnManager = state.turnManager;

  if (targetCell.isAlive &&
      targetCell.entity == null &&
      targetCell.team == self.team) {
    state0.entityManager.entities.add(Wall(targetCell.position, self.team));
  } else {
    return 0;
  }

  if (baseLength < calculatePathLenghtToCenter(self, state0)) {
    return -1 / 3;
  }

  for (var player in state.playerManager.players.where((p) => p != self)) {
    var baseLength = calculatePathLenghtToCenter(player, state);

    var newLength = calculatePathLenghtToCenter(player, state0);

    if (baseLength < newLength) {
      return 2 / 3;
    }
  }

  return 0;
}

double computeHealEfficiency(Player self, GameState state) {
  var healBaseCost = 10 + state.turnManager.getIteration();

  //Чем меньше хп, тем больше мы хотим хилиться
  if (self.hp > 0 && self.money >= healBaseCost) {
    var weight = 1 / self.hp;
    return weight;
  } else {
    return 0;
  }
}

double computeMoveLeftEfficiency(Player self, GameState state) {
  if (self.position.x != 0) {
    var position = Point(self.position.x - 1, self.position.y);
    return _computeMoveEfficiency(self, position, state);
  }
  return efficiencyOfBeingInPoint(self, state);
}

double computeMoveUpEfficiency(Player self, GameState state) {
  if (self.position.y != 0) {
    var position = Point(self.position.x, self.position.y - 1);
    return _computeMoveEfficiency(self, position, state);
  }
  return efficiencyOfBeingInPoint(self, state);
}

double computeMoveRightEfficiency(Player self, GameState state) {
  if (self.position.x + 1 < state.turnManager.getSize()) {
    var position = Point(self.position.x + 1, self.position.y);
    return _computeMoveEfficiency(self, position, state);
  }
  return efficiencyOfBeingInPoint(self, state);
}

double computeMoveDownEfficiency(Player self, GameState state) {
  if (self.position.y + 1 < state.turnManager.getSize()) {
    var position = Point(self.position.x, self.position.y + 1);
    return _computeMoveEfficiency(self, position, state);
  }
  return efficiencyOfBeingInPoint(self, state);
}

double _computeMoveEfficiency(
    Player self, Point<int> position, GameState state) {
  List<Entity> entities = self.getEntities();
  if (entities.where((e) => e.position == position).isNotEmpty) {
    return efficiencyOfBeingInPoint(self, state);
  }
  if (state.cellsNotifier.value
      .where((c) => !c.isAlive && c.position == position)
      .isNotEmpty) {
    return efficiencyOfBeingInPoint(self, state);
  }
  var captured = 0;
  if (state.cellsNotifier.value
          .where((c) => c.position == position)
          .first
          .team !=
      self.team) {
    captured++;
  }
  final deltaDistance = calculatePathLenghtToCenter(self, state) -
      calculatePathLenghtToCenter(self, state);
  final centerCoeff = deltaDistance > 0 ? 1 / 6 : -1 / 6;
  //После перемещения учитываем порядок игроков
  return efficiencyOfBeingInPoint(
          Player(position, self.team, self.rotation, self.user), state, true) +
      captured / 3 +
      centerCoeff;
}

int calculatePathLenghtToCenter(Player self, GameState state) {
  var center = const Point<int>(4, 4);
  int getLength(Point<int> p) =>
      (p.x - center.x).abs() + (p.y - center.y).abs();

  var pos = self.position;

  var length = 0;

  List<Point<int>> visited = [];

  while (pos != center) {
    visited.add(pos);

    var nextPoss = <Point<int>>[];

    //MoveRight
    if (pos.x + 1 < state.turnManager.getSize()) {
      var position = Point(pos.x + 1, pos.y);
      pathTrace(state, self, position, center, nextPoss);
    }

    //MoveLeft
    if (pos.x != 0) {
      var position = Point(pos.x - 1, pos.y);
      pathTrace(state, self, position, center, nextPoss);
    }

    //MoveDown
    if (pos.y != 0) {
      var position = Point(pos.x, pos.y - 1);
      pathTrace(state, self, position, center, nextPoss);
    }

    //MoveUp
    if (pos.y + 1 < state.turnManager.getSize()) {
      var position = Point(pos.x, pos.y + 1);
      pathTrace(state, self, position, center, nextPoss);
    }

    nextPoss.sort((a, b) => getLength(a).compareTo(getLength(b)));
    nextPoss.removeWhere((p) => visited.contains(p));

    if (nextPoss.isEmpty) {
      break;
    }

    pos = nextPoss.first;

    length++;
  }

  return length;
}

void pathTrace(GameState state, Player self, Point<int> position,
    Point<int> center, List<Point<int>> nextPoss) {
  List<Entity> entities = self.getEntities();
  if (position == center) {
    nextPoss.add(position);
  } else if (entities.where((e) => e.position == position).isNotEmpty) {
  } else if (state.cellsNotifier.value
      .where((c) => !c.isAlive && c.position == position)
      .isNotEmpty) {
  } else {
    nextPoss.add(position);
  }
}

double calculateWeightOfRecievedDamage(Player self, Point p, GameState state,
    [bool order = false]) {
  late Iterable<Player> players;

  if (order) {
    players = state.playerManager.players.where((p) => p != self).where((p) =>
        state.playerManager.players.indexOf(p) >
        state.playerManager.players.indexOf(self));
  } else {
    players = state.playerManager.players.where((p) => p != self);
  }

  double shoot(Point p, Player player) {
    late Point<int> vec;

    switch (player.rotation) {
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

    Point<int> currentPoint = player.position + vec;

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
      if (state.playerManager.players
          .where((p) => p.position == currentPoint && p.isAlive)
          .isNotEmpty) {
        break;
      } else if (state.entityManager.entities
          .whereType<Wall>()
          .where((p) => p.position == currentPoint)
          .isNotEmpty) {
        break;
      } else {
        if (currentPoint == p) {
          if (bulletMaxDamage - i >= self.hp) {
            return -1e6 / 2;
          }
          return (-1 / 3) * (bulletMaxDamage - i);
        }

        currentPoint += vec;
      }
    }
    return 0;
  }

  double weigth = 0;

  //проверяем, может ли каждый игрок попасть в клетку p

  for (var player in players) {
    weigth += shoot(p, player);
  }
  return weigth;
}

double checkIfEdge(Point p, GameState state) {
  if (state.turnManager.turn < 30 && state.turnManager.turn % 10 == 8) {
    if (p.x == 0 + state.turnManager.getIteration() &&
            p.y == 0 + state.turnManager.getIteration() ||
        p.x == 0 + state.turnManager.getIteration() &&
            p.y == 8 - state.turnManager.getIteration() ||
        p.x == 8 - state.turnManager.getIteration() &&
            p.y == 0 + state.turnManager.getIteration() ||
        p.x == 8 - state.turnManager.getIteration() &&
            p.y == 8 - state.turnManager.getIteration()) {
      return -1e6;
    }
  }

  if (state.turnManager.turn < 30 && state.turnManager.turn % 10 == 9) {
    if (p.x == 0 + state.turnManager.getIteration() ||
        p.x == 8 - state.turnManager.getIteration() ||
        p.y == 0 + state.turnManager.getIteration() ||
        p.y == 8 - state.turnManager.getIteration()) {
      return -1e6;
    }
  }
  return 0;
}

double efficiencyOfBeingInPoint(Player self, GameState state,
    [bool order = false]) {
  return checkIfEdge(self.position, state) +
      calculateWeightOfRecievedDamage(self, self.position, state, order) +
      computeBuildEfficiency(self, state) +
      computeShootEfficiency(self, state);
}
