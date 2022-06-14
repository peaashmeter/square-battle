import 'entities.dart';

///Синглтон, отвечает за все взаимодействия с сущностями (кроме игроков)
class EntityManager {
  List<Entity> entities = [];

  void removeDead() {
    var deadWalls =
        entities.whereType<Wall>().where((wall) => wall.hp < 1).toList();

    for (var wall in deadWalls) {
      entities.remove(wall);
    }
  }
}
