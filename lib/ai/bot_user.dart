// Настоящие имена ботов как в CS:GO

import 'dart:async';
import 'dart:math';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx/src/core/user/presence.dart';

const List<String> names = [
  'Бот Александр',
  'Бот Дмитрий',
  'Бот Максим',
  'Бот Сергей',
  'Бот Андрей',
  'Бот Алексей',
  'Бот Артём',
  'Бот Илья',
  'Бот Кирилл',
  'Бот Михаил',
  'Бот Никита',
  'Бот Матвей',
  'Бот Роман',
  'Бот Егор',
  'Бот Арсений',
  'Бот Иван',
  'Бот Денис',
  'Бот Евгений',
  'Бот Даниил',
  'Бот Тимофей',
  'Бот Владислав',
  'Бот Игорь',
  'Бот Владимир',
  'Бот Павел',
  'Бот Руслан',
  'Бот Марк',
  'Бот Константин',
  'Бот Тимур',
  'Бот Олег',
  'Бот Ярослав',
  'Бот Антон',
  'Бот Николай',
  'Бот Глеб',
  'Бот Данил'
];

class BotUser extends IUser {
  @override
  late String username;

  @override
  late Snowflake id;

  BotUser() {
    username = names[Random().nextInt(names.length)];
    id = Snowflake(Random().nextInt(1 << 31));
  }

  @override
  bool operator ==(dynamic other) {
    if (other is SnowflakeEntity) return id == other.id;
    if (other is Snowflake) return id == other;
    if (other is String) return id.id.toString() == other;
    if (other is int) return id.id == other;

    return false;
  }

  @override
  int get hashCode => id.hashCode;

  // TODO: implement accentColor
  DiscordColor? get accentColor => throw UnimplementedError();

  @override
  // TODO: implement avatar
  String? get avatar => throw UnimplementedError();

  @override
  // TODO: implement bannerHash
  String? get bannerHash => throw UnimplementedError();

  @override
  // TODO: implement bot
  bool get bot => true;

  @override
  // TODO: implement client
  INyxx get client => throw UnimplementedError();

  @override
  // TODO: implement createdAt
  DateTime get createdAt => throw UnimplementedError();

  @override
  // TODO: implement discriminator
  int get discriminator => throw UnimplementedError();

  @override
  // TODO: implement dmChannel
  FutureOr<IDMChannel> get dmChannel => throw UnimplementedError();

  @override
  // TODO: implement formattedDiscriminator
  String get formattedDiscriminator => throw UnimplementedError();

  @override
  // TODO: implement mention
  String get mention => throw UnimplementedError();

  @override
  // TODO: implement nitroType
  NitroType? get nitroType => throw UnimplementedError();

  @override
  // TODO: implement presence
  Activity? get presence => throw UnimplementedError();

  @override
  Future<IMessage> sendMessage(MessageBuilder builder) {
    // TODO: implement sendMessage
    throw UnimplementedError();
  }

  @override
  // TODO: implement status
  IClientStatus? get status => throw UnimplementedError();

  @override
  // TODO: implement system
  bool get system => throw UnimplementedError();

  @override
  // TODO: implement tag
  String get tag => throw UnimplementedError();

  @override
  // TODO: implement userFlags
  IUserFlags? get userFlags => throw UnimplementedError();

  @override
  // TODO: implement avatarDecorationHash
  String? get avatarDecorationHash => throw UnimplementedError();

  @override
  String avatarUrl({String format = 'webp', int? size, bool animated = false}) {
    // TODO: implement avatarUrl
    throw UnimplementedError();
  }

  @override
  // TODO: implement globalName
  String? get globalName => throw UnimplementedError();

  @override
  // TODO: implement isInteractionWebhook
  bool get isInteractionWebhook => throw UnimplementedError();

  @override
  String? bannerUrl(
      {String format = 'webp', int? size, bool animated = false}) {
    // TODO: implement bannerUrl
    throw UnimplementedError();
  }

  @override
  String? avatarDecorationUrl({int? size}) {
    // TODO: implement avatarDecorationUrl
    throw UnimplementedError();
  }
}
