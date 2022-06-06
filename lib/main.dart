import 'dart:io';
import 'dart:math';

import 'dart:ui' as ui;

import 'package:desktop_window/desktop_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_battle/bot.dart';
import 'package:flutter_battle/team.dart';
import 'package:nyxx/nyxx.dart';

///ключ для скриншотов
late GlobalKey key;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    DesktopWindow.setWindowSize(const Size(512, 512 + 30));
  }

  runBot();

  runApp(const MyApp());
}

late TurnManager turnManager;
late PlayerManager playerManager;
late EntityManager entityManager;

late ValueNotifier<List<Cell>> cellsNotifier;

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
      checkIfDead(player);

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

    //

    //отрисовка сущностей
    for (var entity in entityManager.entities) {
      var linearPos = entity.position.y * size + entity.position.x;
      if (cells[linearPos].isAlive) {
        cells[linearPos].entity = entity;
      }
    }

    //отрисовка игроков
    for (var player in playerManager.players) {
      var linearPos = player.position.y * size + player.position.x;

      if (player.isAlive) {
        cells[linearPos].entity = player;
      }
    }

    // for (var player in playerManager.players) {
    //   checkIfDead(player);
    // }

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

  ///Перемещает мертвых в конец списка, перемешивает живых
  void switchPlayers() {
    List<Player> playersSwitched = [];
    var alivePlayers = players.where((player) => player.isAlive).toList();
    if (alivePlayers.length > 1) {
      playersSwitched.addAll(alivePlayers.getRange(1, alivePlayers.length));
      playersSwitched.add(players.first);
    } else if (alivePlayers.isNotEmpty) {
      playersSwitched.add(alivePlayers.first);
    }

    var deadPlayers = players.where((player) => !player.isAlive).toList();
    playersSwitched.addAll(List.from(deadPlayers));

    players = List.from(playersSwitched);
  }
}

///Синглтон, отвечает за все взаимодействия с сущностями (кроме игроков)
class EntityManager {
  List<Entity> entities = [];

  void removeDead() {
    entities.whereType<Wall>().where((wall) => wall.hp < 1);
  }
}

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
      this.hp = 5]);

  int countIncome() {
    var income = cellsNotifier.value
        .where((cell) => cell.team == team && cell.isAlive)
        .length;
    return income;
  }

  void moveRight() {
    if (position.x + 1 < turnManager.getSize()) {
      var _position = Point(position.x + 1, position.y);
      List<Entity> entities = getEntities();
      if (entities.where((e) => e.position == _position).isNotEmpty) {
        return;
      }
      if (cellsNotifier.value
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
      if (cellsNotifier.value
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
      if (cellsNotifier.value
          .where((c) => !c.isAlive && c.position == _position)
          .isNotEmpty) {
        return;
      }
      position = _position;
    }
  }

  void moveDown() {
    if (position.y + 1 < turnManager.getSize()) {
      var _position = Point(position.x, position.y + 1);
      List<Entity> entities = getEntities();
      if (entities.where((e) => e.position == _position).isNotEmpty) {
        return;
      }
      if (cellsNotifier.value
          .where((c) => !c.isAlive && c.position == _position)
          .isNotEmpty) {
        return;
      }
      position = _position;
    }
  }

  List<Entity> getEntities() {
    var entities =
        List<Entity>.from(entityManager.entities + playerManager.players
          ..where((p) => (p as Player).isAlive));
    return entities;
  }

  void shoot() {
    const shootCost = 6;

    if (money - shootCost < 0) {
      return;
    }

    money -= shootCost;

    List<Point<int>> points = [];

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
          cellsNotifier.value
              .where((c) => c.isAlive)
              .where((cell) => cell.position == currentPoint)
              .isEmpty) {
        break;
      }
      var cell =
          cellsNotifier.value.where((c) => c.position == currentPoint).first;
      if (cell.entity is Player) {
        (cell.entity as Player).hp -= (bulletMaxDamage - i);
        break;
      } else if (cell.entity is Wall) {
        (cell.entity as Wall).hp -= (bulletMaxDamage - i);
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

  void makeTurn() {
    if (isTurnMade) {
      return;
    }

    isTurnMade = true;

    turnManager.updateCells();
  }

  void buildWall() {
    var targetCellPoint = _getPointedCell();
    if (targetCellPoint == null) return;
    if (money - Wall.cost < 0) return;

    Cell targetCell = cellsNotifier.value
        .where((cell) => cell.position == targetCellPoint)
        .first;

    if (targetCell.isAlive &&
        targetCell.entity == null &&
        targetCell.team == team) {
      entityManager.entities.add(Wall(targetCellPoint, team));
      money -= Wall.cost;
    }
  }

  Point<int>? _getPointedCell() {
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
    return Container(
        color: getColorByTeam(team),
        child: const Icon(
          Icons.close_rounded,
          size: 48,
        ));
  }
}

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

Future<File> takeScreenshot() async {
  RenderRepaintBoundary boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary;

  ui.Image image = await boundary.toImage();
  var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  var file = await File('turn${turnManager.turn}.png').create();
  return file.writeAsBytes(byteData!.buffer.asInt8List());
}
