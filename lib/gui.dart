import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_battle/main.dart';
import 'package:url_launcher/url_launcher.dart';

class Menu extends StatelessWidget {
  const Menu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SquareBattle – игра для Дискорда',
      home: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            FloatingActionButton(
              backgroundColor: Colors.blueGrey,
              onPressed: () {
                _launchURL('https://discord.gg/9Sg3GDzmQg');
              },
              child: Image.asset(
                'assets/discord.png',
                width: 32,
              ),
            ),
            FloatingActionButton(
              backgroundColor: Colors.blueGrey,
              heroTag: 'hero2',
              onPressed: () {
                _launchURL(
                    'https://www.youtube.com/channel/UCvb-2jADopGlMKM96qrfKjw');
              },
              child: Image.asset(
                'assets/youtube.png',
                width: 32,
              ),
            )
          ],
        ),
        body: Container(
          color: Colors.blueGrey[900],
          child: Column(
            //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Expanded(
                flex: 1,
                child: Align(
                  child: Text(
                    'SquareBattle',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 48),
                  ),
                ),
              ),
              Expanded(flex: 3, child: MiddlePanel()),
            ],
          ),
        ),
      ),
    );
  }
}

class MiddlePanel extends StatefulWidget {
  const MiddlePanel({
    Key? key,
  }) : super(key: key);

  @override
  State<MiddlePanel> createState() => _MiddlePanelState();
}

class _MiddlePanelState extends State<MiddlePanel> {
  late TextEditingController controller;

  @override
  void initState() {
    controller = TextEditingController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                    child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Введите токен бота',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white))),
                )),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Game(controller.text),
                      ));
                },
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
              color: Colors.blueGrey,
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: const [
                    Text(
                      'Список команд:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('!squarebattle – начать регистрацию на игру'),
                    Text('!start – начать игру'),
                    Text('!stop – закончить игру'),
                    Text('!skip – пропускает ход'),
                    Text('!sbhelp – справка об игре'),
                    Text('Управление игрой доступно только создателю матча.'),
                  ],
                ),
              )),
        )
      ],
    );
  }
}

void _launchURL(String url) async {
  if (!await launchUrl(Uri.parse(url))) throw 'Could not launch $url';
}
