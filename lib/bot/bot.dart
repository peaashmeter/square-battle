import 'dart:math';

import 'package:flutter_battle/ai/ai.dart';
import 'package:flutter_battle/ai/bot_user.dart';
import 'package:flutter_battle/entities.dart';
import 'package:flutter_battle/game.dart';

import 'package:flutter_battle/main.dart';
import 'package:flutter_battle/patchnote.dart';

import 'package:flutter_battle/team.dart';
import 'package:flutter_battle/turnmanager.dart';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

void runBot(String token) {
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
    ..registerButtonHandler("heal", buttonHandler)
    ..registerButtonHandler("make_turn", buttonHandler)
    ..registerButtonHandler("cancel", buttonHandler)
    ..syncOnReady();
  // Listen for message events
  bot.eventsWs.onMessageReceived.listen((e) async {
    try {
      if (e.message.content.startsWith('!squarebattle')) {
        if (state.isStartingGame) {
          await e.message.channel
              .sendMessage(MessageBuilder.content('Игра уже начинается!'));
          return;
        }
        if (state.turnManager.isPlaying) {
          await e.message.channel
              .sendMessage(MessageBuilder.content('Игра уже идет!'));
          return;
        }
        participants = {};

        //парсим количество ботов
        var regex = RegExp(r'-b (\d*)');
        var bots = 0;
        var botsparam = regex.allMatches(e.message.content);
        if (botsparam.isNotEmpty) {
          bots = int.tryParse(botsparam.first.group(1) ?? '') ?? 0;
          if (bots >= 8) {
            bots = 8;
          }
        }

        final msg = await e.message.channel.sendMessage(MessageBuilder.content(
            '${e.message.author.username} начал игру! Выберите цвет, чтобы присоединиться.'));

        startMessage = msg;

        gameInitiatorId = e.message.author.id.id;

        state.isStartingGame = true;

        // ---- Боты

        for (var i = 0; i < bots; i++) {
          Future.delayed(const Duration(milliseconds: 666), () {
            addBot(participants, msg);
          });
          await Future.delayed(const Duration(milliseconds: 666));
        }

        // ----

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
        if (!state.isStartingGame) {
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
        participants = await startGame(startMessage, e, participants);

        return;
      } else if (e.message.content == "!skip") {
        if (e.message.author.id.id != gameInitiatorId) {
          e.message.channel.sendMessage(MessageBuilder.content(
              'Пропустить ход может только создатель игры!'));
          return;
        }
        state.turnManager.updateCells(true);
      } else if (e.message.content == "!stop") {
        if (e.message.author.id.id != gameInitiatorId) {
          e.message.channel.sendMessage(MessageBuilder.content(
              'Закончить игру может только ее создатель!'));
          return;
        }

        state.resetGame();
        participants = {};

        e.message.channel
            .sendMessage(MessageBuilder.content('Игра остановлена!'));
      } else if (e.message.content == "!sbhelp") {
        getHelp(e);
      } else if (e.message.content == "!sbversion") {
        e.message.channel.sendMessage(MessageBuilder.content(patchnote));
      }
    } catch (e) {
      print(e);
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
      onReactionRemove(user, event, participants, msg);
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
      if (!state.isStartingGame || state.turnManager.isPlaying) {
        return;
      }
      if (!emojiWhiteList.contains(emoji.formatForMessage())) {
        return;
      }

      if (!participants.values.any((e) => e.toString() == emoji.toString())) {
        participants[sender] = emoji;

        updateRegistrationMessage(participants, user, emoji, msg);
      }
    } catch (e) {
      print(e);
    }
  });
}

void addBot(Map<IUser, IEmoji> participants, IMessage msg) {
  var emojis = emojiWhiteList.toSet();
  var usedEmojis = participants.values.map((e) => e.formatForMessage()).toSet();
  var remainingColors = emojis.difference(usedEmojis);
  if (remainingColors.isNotEmpty) {
    var color =
        remainingColors.elementAt(Random().nextInt(remainingColors.length));
    var user = BotUser();
    participants.addAll({user: UnicodeEmoji(color)});
    updateRegistrationMessage(participants, user, UnicodeEmoji(color), msg);
  }
}

void updateRegistrationMessage(
    Map<IUser, IEmoji> participants, IUser user, IEmoji emoji, IMessage? msg) {
  var string = 'Началась регистрация на участие в игре SquareBattle!\n\n';

  for (var p in participants.entries) {
    string += '${p.value.formatForMessage()} ${p.key.username}\n';
  }

  string += 'Напишите !start, чтобы начать игру';

  state.playerManager.addPlayer(user, getTeamByEmoji(emoji.formatForMessage()));
  state.turnManager.updateCells();

  msg?.edit(MessageBuilder.content(string));
}

void onReactionRemove(IUser user, IMessageReactionEvent event,
    Map<IUser, IEmoji> participants, IMessage? msg) {
  var sender = user;
  var emoji = event.emoji;

  if (participants[sender]?.formatForMessage() == emoji.formatForMessage()) {
    participants.remove(sender);

    state.playerManager.removePlayer(user);
    state.turnManager.updateCells();
  }

  var string = 'Тестирование системы регистрации на игру\n\n';

  for (var p in participants.entries) {
    string += '${p.value.formatForMessage()} ${p.key.username}\n';
  }

  string += 'Напишите !start, чтобы начать игру';

  msg?.edit(MessageBuilder.content(string));
}

void getHelp(IMessageReceivedEvent e) {
  e.message.channel.sendMessage(MessageBuilder.content('''
Приветствую тебя в SquareBattle! Это пошаговая стратегия, в которой нужно захватывать территории и сражаться с противниками на уменьшающейся карте.

В игре есть 2 способа победить: 
1) остаться последним выжившим;
2) набрать больше всех очков к 50 ходу.

Каждый ход игрок получает одну монету за каждую клетку его цвета. Итоговый счет – это сумма всех монет, накопленных игроком за игру.

Действия:
Каждый ход игрок может сделать одно действие и повернуться. Поворот всегда срабатывает после действия и влияет только на направление игрока (не на перемещение).
💥 – выстрелить на 3 клетки в направлении игрока (6 монет). Урон зависит от расстояния.
🧱 – построить стену в направлении игрока (5 монет). У стены 3 единицы здоровья.
❤ – восстановить 1 единицу здоровья (10 + 5 за каждую дополнительную единицу здоровья).
🚫 – отменить выбранные действия и готовность завершить ход.

Чтобы изменить количество ботов, участвующих в игре, начинайте игру командой !squarebattle -b [количество ботов]

Подписывайтесь на дискорд https://discord.gg/9Sg3GDzmQg и ютуб https://www.youtube.com/channel/UCvb-2jADopGlMKM96qrfKjw создателя!
'''));
}

Future<Map<IUser, IEmoji>> startGame(IMessage? startMessage,
    IMessageReceivedEvent e, Map<IUser, IEmoji> participants) async {
  //создаем элементы управления игрой
  MessageBuilder msg = await createKeyboard();

  //удаляем сообщение о регистраци
  startMessage?.delete();

  //текущее сообщение, в котором содержится информация и элементы управления
  state.gameMessage = await e.message.channel.sendMessage(msg);
  participants = {};

  state.isStartingGame = false;

  state.turnManager.isPlaying = true;
  state.turnManager.initGame();
  return participants;
}

String formatGameMessage() {
  if (state.turnManager.turn >= 50 ||
      state.playerManager.players.where((p) => p.isAlive).isEmpty) {
    var scoreTable = 'Игра закончена! Результаты: \n';
    var players = List<Player>.from(state.playerManager.players
      ..sort((p1, p2) {
        return p1.totalScore.compareTo(p2.totalScore);
      }));
    for (var player in players) {
      scoreTable += '${player.user.username}: ${player.totalScore} очков \n';
    }

    return scoreTable;
  }
  if (state.playerManager.players.where((p) => p.isAlive).length == 1) {
    var scoreTable =
        'Игра закончена! Победитель: ${state.playerManager.players.where((p) => p.isAlive).first.user.username}\nРезультаты: \n';
    var players = List<Player>.from(state.playerManager.players
      ..sort((p1, p2) {
        return p1.totalScore.compareTo(p2.totalScore);
      }));
    for (var player in players) {
      scoreTable += '${player.user.username}: ${player.totalScore} очков \n';
    }

    return scoreTable;
  }

  var gameMessageString = 'Идет игра: ход ${state.turnManager.turn}. ';
  if (state.turnManager.getIteration() < 3) {
    gameMessageString +=
        'До уменьшения поля осталось ${TurnManager.roundLength - state.turnManager.turn % TurnManager.roundLength} ходов';
  } else {
    gameMessageString +=
        'Игра закончится через ${50 - state.turnManager.turn} ходов';
  }
  if (TurnManager.roundLength -
          state.turnManager.turn % TurnManager.roundLength <=
      5) {
    gameMessageString += '⚠';
  }

  gameMessageString += '\n';

  if (state.turnManager.getIteration() > 0) {
    gameMessageString +=
        'Все цены увеличены на ${state.turnManager.getIteration()}!';
  }
  gameMessageString += '\n';

  for (var player in state.playerManager.players) {
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

  if (state.playerManager.players.where((p) => p.user == user).isEmpty) {
    return;
  }
  if (!state.turnManager.isPlaying) {
    return;
  }
  var player = state.playerManager.players.where((p) => p.user == user).first;
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
      state.gameMessage?.edit(await createKeyboard(false));
      break;
    case 'build':
      player.action = player.buildWall;
      break;
    case 'shoot':
      player.action = player.shoot;
      break;
    case 'heal':
      player.action = player.heal;
      break;
    case 'cancel':
      player.action = null;
      player.rotationAction = null;
      player.isTurnMade = false;
      state.gameMessage?.edit(await createKeyboard(false));
      break;
    default:
  }
}

void scheduleBotsActions() {
  for (var bot in state.playerManager.players) {
    if (bot.user.bot) {
      if (!bot.isTurnMade) {
        Future.delayed(Duration(milliseconds: Random().nextInt(5000) + 2000),
            () async {
          bot.action = getAction(state, bot);
          bot.rotationAction = getRotationAction(state, bot);

          bot.makeTurn();
          state.gameMessage?.edit(await createKeyboard(false));
        });
      }
    }
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

///Создает сообщение с информацией об игре и элементами управлнения
Future<MessageBuilder> createKeyboard([bool appendScreenshot = true]) async {
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
    'heal',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('❤');

  var row3 = ComponentRowBuilder()
    ..addComponent(buildButton)
    ..addComponent(backButton)
    ..addComponent(actionButton);

  var cancelButton = ButtonBuilder('', 'cancel', ButtonStyle.secondary)
    ..emoji = UnicodeEmoji('🚫');
  var none2Button =
      ButtonBuilder(' ', 'none2', ButtonStyle.secondary, disabled: true);

  var skipButton = ButtonBuilder(
    '',
    'make_turn',
    ButtonStyle.secondary,
  )..emoji = UnicodeEmoji('✅');

  var skipRow = ComponentRowBuilder()
    ..addComponent(cancelButton)
    ..addComponent(skipButton)
    ..addComponent(none2Button);

  var msg = ComponentMessageBuilder()..content = formatGameMessage();

  if (appendScreenshot) {
    msg.addFileAttachment(await takeScreenshot());
  }

  if (state.turnManager.turn == 50 ||
      state.playerManager.players.where((p) => p.isAlive).isEmpty ||
      state.playerManager.players.where((p) => p.isAlive).length == 1) {
    return msg;
  }

  msg
    ..addComponentRow(row1)
    ..addComponentRow(row2)
    ..addComponentRow(row3)
    ..addComponentRow(skipRow);

  return msg;
}

///Переслать игровое сообщение вниз
void resendGameMessage() async {
  var channel = state.gameMessage?.channel;

  await state.gameMessage?.delete();
  state.gameMessage = await channel?.sendMessage(await createKeyboard());
}
