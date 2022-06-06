import 'dart:io';
import 'dart:math';

import 'package:flutter_battle/main.dart';
import 'package:flutter_battle/team.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

const token =
    'OTc1MjA3NjAwNjcxMDMxMzM2.GzoyHL.rJOQfNaHFLe6E9k8VkWdD76GXGYu1dVwJ-4YGQ';
bool isStartingGame = false;
IMessage? gameMessage;

void runBot() {
  final bot =
      NyxxFactory.createNyxxWebsocket(token, GatewayIntents.allUnprivileged)
        ..registerPlugin(Logging()) // Default logging plugin
        ..registerPlugin(
            CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
        ..registerPlugin(
            IgnoreExceptions()) // Plugin that handles uncaught exceptions that may occur
        ..connect();

  Map<IUser, IEmoji> participants = {};

  IMessage? startMessage;

  int? gameInitiatorId;

  IInteractions.create(WebsocketInteractionBackend(bot))
    ..registerButtonHandler("rotate_left", buttonHandler)
    ..registerButtonHandler("up", buttonHandler)
    ..registerButtonHandler("rotate_right", buttonHandler)
    ..registerButtonHandler("left", buttonHandler)
    ..registerButtonHandler("shoot", buttonHandler)
    ..registerButtonHandler("right", buttonHandler)
    ..registerButtonHandler("build", buttonHandler)
    ..registerButtonHandler("down", buttonHandler)
    ..registerButtonHandler("action", buttonHandler)
    ..registerButtonHandler("make_turn", buttonHandler)
    ..syncOnReady();
  // Listen for message events
  bot.eventsWs.onMessageReceived.listen((e) async {
    if (e.message.content == "!squarebattle") {
      if (isStartingGame) {
        await e.message.channel
            .sendMessage(MessageBuilder.content('Игра уже начинается!'));
        return;
      }
      if (turnManager.isPlaying) {
        await e.message.channel
            .sendMessage(MessageBuilder.content('Игра уже идет!'));
        return;
      }
      final msg = await e.message.channel.sendMessage(MessageBuilder.content(
          '${e.message.author.username} начал игру! Выберите цвет, чтобы присоединиться.'));

      startMessage = msg;

      gameInitiatorId = e.message.author.id.id;

      isStartingGame = true;
      turnManager.isPlaying = false;

      await msg.createReaction(UnicodeEmoji('🟥'));
      await Future.delayed(const Duration(milliseconds: 500),
          () => msg.createReaction(UnicodeEmoji('🟧')));
      await Future.delayed(const Duration(milliseconds: 500),
          () => msg.createReaction(UnicodeEmoji('🟨')));
      await Future.delayed(const Duration(milliseconds: 500),
          () => msg.createReaction(UnicodeEmoji('🟩')));
      await Future.delayed(const Duration(milliseconds: 500),
          () => msg.createReaction(UnicodeEmoji('🟦')));
      await Future.delayed(const Duration(milliseconds: 500),
          () => msg.createReaction(UnicodeEmoji('🟪')));
      await Future.delayed(const Duration(milliseconds: 500),
          () => msg.createReaction(UnicodeEmoji('🟫')));
      await Future.delayed(const Duration(milliseconds: 500),
          () => msg.createReaction(UnicodeEmoji('⬜')));
    } else if (e.message.content == "!start") {
      if (e.message.author.id.id != gameInitiatorId) {
        e.message.channel.sendMessage(
            MessageBuilder.content('Начать игру может только ее создатель!'));
        return;
      }
      if (!isStartingGame) {
        e.message.channel.sendMessage(MessageBuilder.content(
            'Напишите !squarebattle, чтобы запустить регистрацию на участие в игре!'));
        return;
      }
      if (participants.isEmpty) {
        e.message.channel.sendMessage(
            MessageBuilder.content('Для игры нужен хотя бы один участник!'));
        return;
      }

      //создаем элементы управления игрой
      MessageBuilder msg = await createKeyboard();

      //удаляем сообщение о регистраци
      startMessage?.delete();

      //текущее сообщение, в котором содержится информация и элементы управления
      gameMessage = await e.message.channel.sendMessage(msg);
      participants = {};

      isStartingGame = false;

      turnManager.isPlaying = true;
      turnManager.initGame();

      return;
    } else if (e.message.content == "!skip") {
      if (e.message.author.id.id != gameInitiatorId) {
        e.message.channel.sendMessage(MessageBuilder.content(
            'Пропустить ход может только создатель игры!'));
        return;
      }
      turnManager.updateCells(true);
    } else if (e.message.content == "!stop") {
      if (e.message.author.id.id != gameInitiatorId) {
        e.message.channel.sendMessage(MessageBuilder.content(
            'Закончить игру может только ее создатель!'));
        return;
      }

      cellsNotifier.value =
          List.generate(81, (i) => Cell(Point(i % 9, i ~/ 9), true));

      turnManager = TurnManager(
        1,
      );
      entityManager = EntityManager();
      playerManager = PlayerManager();
      turnManager.isPlaying = false;
    } else if (e.message.content == "!keyboard") {
      createKeyboard();
    }
  });

  bot.eventsWs.onMessageReactionRemove.listen((event) async {
    var msg = event.message;
    var user = await event.user.download();
    if (user.bot) {
      return;
    }
    if (msg != startMessage) {
      return;
    }
    try {
      var sender = user;
      var emoji = event.emoji;

      if (participants[sender]?.formatForMessage() ==
          emoji.formatForMessage()) {
        participants.remove(sender);

        playerManager.removePlayer(user);
        turnManager.updateCells();
      }

      var string = 'Тестирование системы регистрации на игру\n\n';

      for (var p in participants.entries) {
        string += '${p.value.formatForMessage()} ${p.key.username}\n';
      }

      string += 'Напишите !start, чтобы начать игру';

      msg?.edit(MessageBuilder.content(string));
    } catch (e) {
      print(e);
    }
  });

  bot.eventsWs.onMessageReactionAdded.listen((event) async {
    try {
      var msg = event.message;

      var user = await event.user.download();
      if (user.bot) {
        return;
      }
      if (msg != startMessage) {
        return;
      }

      var sender = user;
      var emoji = event.emoji;
      if (!isStartingGame || turnManager.isPlaying) {
        return;
      }
      if (!emojiWhiteList.contains(emoji.formatForMessage())) {
        return;
      }

      if (!participants.values.any((e) => e.toString() == emoji.toString())) {
        participants[sender] = emoji;

        var string = 'Тестирование системы регистрации на игру\n\n';

        for (var p in participants.entries) {
          string += '${p.value.formatForMessage()} ${p.key.username}\n';
        }

        string += 'Напишите !start, чтобы начать игру';

        playerManager.addPlayer(user, getTeamByEmoji(emoji.formatForMessage()));
        turnManager.updateCells();

        msg?.edit(MessageBuilder.content(string));
      }
    } catch (e) {
      print(e);
    }
  });
}

String formatGameMessage() {
  var gameMessageString = 'Идет игра: ход ${turnManager.turn}\n';

  for (var player in playerManager.players) {
    gameMessageString +=
        '${getEmojiByTeam(player.team)} ${player.user.username} | ';

    gameMessageString += '🪙 ${player.money}+${player.countIncome()} | ';

    gameMessageString += '❤ ${player.hp} | ';

    if (!player.isAlive) {
      gameMessageString += '💀';
    } else if (player.isTurnMade) {
      gameMessageString += '✅';
    } else {
      gameMessageString += '❌';
    }
    gameMessageString += '\n';
  }

  return gameMessageString;
}

Future<void> buttonHandler(IButtonInteractionEvent event) async {
  await event
      .acknowledge(); // ack the interaction so we can send response later

  var user = event.interaction.userAuthor;

  // Send followup to button click with id of button
  // await event.sendFollowup(MessageBuilder.content(
  //     "${event.interaction.userAuthor?.username} нажал на кнопку ${event.interaction.customId}"));

  if (playerManager.players.where((p) => p.user == user).isEmpty) {
    return;
  }
  if (!turnManager.isPlaying) {
    return;
  }
  var player = playerManager.players.where((p) => p.user == user).first;
  var action = event.interaction.customId;

  switch (action) {
    case 'up':
      player.action = player.moveUp;
      break;
    case 'left':
      player.action = player.moveLeft;
      break;
    case 'right':
      player.action = player.moveRight;
      break;
    case 'down':
      player.action = player.moveDown;
      break;
    case 'rotate_left':
      player.rotationAction = player.rotateLeft;
      break;
    case 'rotate_right':
      player.rotationAction = player.rotateRight;
      break;
    case 'make_turn':
      player.makeTurn();
      gameMessage?.edit(await createKeyboard(false));
      break;
    case 'build':
      player.action = player.buildWall;
      break;
    case 'shoot':
      player.action = player.shoot;
      break;
    default:
  }
}

const List<String> emojiWhiteList = [
  '🟥',
  '🟧',
  '🟨',
  '🟩',
  '🟦',
  '🟪',
  '🟫',
  '⬜'
];

Future<MessageBuilder> createKeyboard([bool appendScreenshot = true]) async {
  // Create embed with author and footer section.
  var rotateLeftButton = ButtonBuilder(
    '',
    'rotate_left',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('↪');
  var forwardButton = ButtonBuilder(
    '',
    'up',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('🔼');
  var rotateRightButton = ButtonBuilder(
    '',
    'rotate_right',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('↩');

  var row1 = ComponentRowBuilder()
    ..addComponent(rotateLeftButton)
    ..addComponent(forwardButton)
    ..addComponent(rotateRightButton);

  var leftButton = ButtonBuilder(
    '',
    'left',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('◀');
  var attackButton = ButtonBuilder(
    '',
    'shoot',
    ButtonStyle.danger,
  )..emoji = UnicodeEmoji('💥');
  var rightButton = ButtonBuilder(
    '',
    'right',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('▶');

  var row2 = ComponentRowBuilder()
    ..addComponent(leftButton)
    ..addComponent(attackButton)
    ..addComponent(rightButton);

  var buildButton = ButtonBuilder(
    '',
    'build',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('🧱');
  var backButton = ButtonBuilder(
    '',
    'down',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('🔽');
  var actionButton = ButtonBuilder(
    '',
    'action',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('❤');

  var row3 = ComponentRowBuilder()
    ..addComponent(buildButton)
    ..addComponent(backButton)
    ..addComponent(actionButton);

  var none1Button =
      ButtonBuilder(' ', 'none1', ButtonStyle.secondary, disabled: true);
  var none2Button =
      ButtonBuilder(' ', 'none2', ButtonStyle.secondary, disabled: true);

  var skipButton = ButtonBuilder(
    '',
    'make_turn',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('✅');

  var skipRow = ComponentRowBuilder()
    ..addComponent(none1Button)
    ..addComponent(skipButton)
    ..addComponent(none2Button);

  var msg = ComponentMessageBuilder()
    ..content = formatGameMessage()
    ..addComponentRow(row1)
    ..addComponentRow(row2)
    ..addComponentRow(row3)
    ..addComponentRow(skipRow);

  if (appendScreenshot) {
    msg.addFileAttachment(await takeScreenshot());
  }

  return msg;
}

///Переслать игровое сообщение вниз
void resendGameMessage() async {
  var channel = gameMessage?.channel;

  await gameMessage?.delete();
  gameMessage = await channel?.sendMessage(await createKeyboard());
}
