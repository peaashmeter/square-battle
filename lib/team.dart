enum Team { red, orange, yellow, green, blue, indigo, brown, white }

Team getTeamByEmoji(String emoji) {
  switch (emoji) {
    case '🟥':
      return Team.red;
    case '🟧':
      return Team.orange;
    case '🟨':
      return Team.yellow;
    case '🟩':
      return Team.green;
    case '🟦':
      return Team.blue;
    case '🟪':
      return Team.indigo;
    case '🟫':
      return Team.brown;
    case '⬜':
      return Team.white;
    default:
      throw Exception('Нет такого эмоджи $emoji');
  }
}

String getEmojiByTeam(Team team) {
  switch (team) {
    case Team.red:
      return '🟥';
    case Team.orange:
      return '🟧';
    case Team.yellow:
      return '🟨';
    case Team.green:
      return '🟩';
    case Team.blue:
      return '🟦';
    case Team.indigo:
      return '🟪';
    case Team.brown:
      return '🟫';
    case Team.white:
      return '⬜';
    default:
      throw Exception('Нет такого эмоджи $team');
  }
}
