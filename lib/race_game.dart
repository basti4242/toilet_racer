import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toilet_racer/app/constants.dart';
import 'package:toilet_racer/app/locator.dart';
import 'package:toilet_racer/components/background.dart';
import 'package:toilet_racer/components/boundary.dart';
import 'package:toilet_racer/components/controller.dart';
import 'package:toilet_racer/components/help_text.dart';
import 'package:toilet_racer/components/player.dart';
import 'package:toilet_racer/services/audio_service.dart';
import 'package:vector_math/vector_math_64.dart';

import 'game/level.dart';

typedef AsyncCallback = Future<void> Function();

class RaceGame extends Forge2DGame with HasTapableComponents {
  static const double defaultScale = 4.0;

  final SharedPreferences _prefService = locator<SharedPreferences>();
  final AudioService _audioService = locator<AudioService>();

  @override
  bool debugMode = true;

  bool _musicEnabled = true;
  bool _showHelp = true;
  bool _collisionDetected = false;

  AsyncCallback roundEndCallback;

  Player player;
  Controller controller;
  HelpText controlHelpText;

  Image playerImage;

  Boundary innerBoundary;
  Boundary outerBoundary;

  Background background;
  Level level;

  BoundaryContactCallback contactCallback;

  RaceGame({this.roundEndCallback})
      : super(scale: defaultScale, gravity: Vector2(0, 0)) {
    _init();

    _showMenu();
  }

  @override
  Future<void> onLoad() async {
    playerImage = await Flame.images.load('players/rat.png');

    level = Level.toilet3;
    await level.onLoad();
    await add(background = Background(level));
  }

  @override
  void onResize(Vector2 size) {
    super.onResize(size);

    if (background != null) {
      viewport.scale = defaultScale * background.scale;
    }
  }

  void _init() {
    _musicEnabled = _prefService.getBool(prefKeyMusicEnabled) ?? _musicEnabled;
    _showHelp = _prefService.getBool(prefKeyShowHelp) ?? _showHelp;

    if (_musicEnabled) {
      _audioService.playBgMusic();
    }
  }

  void _showMenu() {
    overlays.add(startMenu);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_collisionDetected) {
      pauseGame();
      _collisionDetected = false;
    }
  }

  void startGame() {
    add(player = Player(
        image: playerImage,
        startPosition: background.getImageToScreen(level.startPosition)));
    add(outerBoundary = Boundary(level.track.outerBoundary
        .map((vertex) => background.getImageToScreen(vertex))
        .toList()));
    add(innerBoundary = Boundary(level.track.innerBoundary
        .map((vertex) => background.getImageToScreen(vertex))
        .toList()));

    addContactCallback(
        contactCallback = BoundaryContactCallback(collisionDetected));
    add(controller = Controller(player));

    if (_showHelp) {
      add(controlHelpText = HelpText());
      _showHelp = false;
      _prefService.setBool(prefKeyShowHelp, _showHelp);
    }

    overlays.remove(startMenu);
    overlays.add(overlayUi);
  }

  void pauseGame() async {
    remove(player);
    remove(innerBoundary);
    remove(outerBoundary);
    remove(controller);
    removeContactCallback(contactCallback);

    if (_showHelp) {
      remove(controlHelpText);
    }
    overlays.remove(overlayUi);

    await roundEndCallback();
    _showMenu();
  }

  void collisionDetected() {
    _collisionDetected = true;

    // Bug in audioplayers https://github.com/luanpotter/audioplayers/issues/738
    _audioService.playDropSound(audioToiletDropSound);
  }

  void quitGame() =>
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
}
