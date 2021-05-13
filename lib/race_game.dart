import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart' hide Timer;
import 'package:flame/gestures.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Timer;
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toilet_racer/app/constants.dart';
import 'package:toilet_racer/app/locator.dart';
import 'package:toilet_racer/components/background.dart';
import 'package:toilet_racer/components/boundary.dart';
import 'package:toilet_racer/components/game_help.dart';
import 'package:toilet_racer/components/player_body.dart';
import 'package:toilet_racer/services/audio_service.dart';
import 'package:toilet_racer/services/game_service.dart';
import 'package:toilet_racer/services/timer_service.dart';
import 'package:vector_math/vector_math_64.dart';

import 'app/utils.dart';
import 'components/player.dart';
import 'game/level.dart';

typedef AsyncCallback = Future<void> Function();

class RaceGame extends Forge2DGame with TapDetector {
  static const double defaultScale = 4.0;

  final AudioService _audioService = locator<AudioService>();
  final SharedPreferences _prefService = locator<SharedPreferences>();
  final TimerService _timerService = locator<TimerService>();

  final AsyncCallback gameOverCallback;

  final Random random = Random();

  @override
  bool debugMode = kDebugMode;

  bool _musicEnabled = true;
  bool _gameHelpShown = false;
  bool _collisionDetected = false;

  Background background;
  Level level;
  BoundaryContactCallback contactCallback;

  Set<Component> gameComponents;
  PlayerBody _playerBody;
  Iterator<GameHelp> gameHelper;

  int get score => _timerService?.seconds?.value ?? 0;

  double get _currentHighscore =>
      _prefService.getDouble(kPrefKeyHighscore) ?? 0;

  RaceGame({this.gameOverCallback})
      : super(scale: defaultScale, gravity: Vector2(0, 0)) {
    _init();
  }

  @override
  Future<void> onLoad() async {
    level = Level.toilet1;
    await level.onLoad();
    await add(background = Background(level));
  }

  @override
  void onResize(Vector2 size) {
    super.onResize(size);

    if (background != null) {
      viewport.scale = defaultScale * background.worldScale;
    }
  }

  void _init() {
    _musicEnabled = _prefService.getBool(kPrefKeyMusicEnabled) ?? _musicEnabled;

    if (_musicEnabled) {
      _audioService.playBgMusic();
    }
  }

// Init and show game help
  void startGameWithHelp() async {
    _removeOverlays();

    if (_currentHighscore < 5) {
      await _initGameHelp();
      await add(gameHelper.current);
      _gameHelpShown = true;
    } else {
      startGame();
    }
  }

  void startGame() async {
    await _addGameComponents();
    _swapMenuOverlay(kOverlayUi);
    _timerService.start();
  }

  Future<void> _initGameHelp() async {
    final middleBoundary = getMiddleVertices(
      level.track.outerBoundary
          .map((e) => background.getImageToScreen(e))
          .toList(),
      level.track.innerBoundary
          .map((e) => background.getImageToScreen(e))
          .toList(),
    );

    final player = await Fly().onLoad();
    final _playerBody = PlayerBody(
        player, background.getImageToScreen(level.startPosition),
        preview: true);

    gameHelper = [
      GameHelp(
          boundary: middleBoundary,
          rightArrow: true,
          helpText: 'Tap to turn',
          imagePath: 'icons/ic_gesture_tap.png',
          player: _playerBody),
      GameHelp(
        boundary: middleBoundary,
        bottomArrow: true,
        topArrow: true,
        helpText: 'Stay on the\ntoilet',
      ),
      GameHelp(
        helpText: 'Tap to begin',
        textPosition: GamePosition.CENTER,
      ),
    ].iterator
      ..moveNext();
  }

  Future<void> _addGameComponents() async {
    Boundary innerBoundary, outerBoundary;

    final player = await Fly().onLoad();
    // 10% chance to move clockwise (ghost mode) if the user has some experience (score > 20)
    final clockwise = _currentHighscore > 20.0 && random.nextInt(10) == 0;
    await add(_playerBody = PlayerBody(
        player, background.getImageToScreen(level.startPosition),
        counterclockwise: !clockwise));

    await add(outerBoundary = Boundary(level.track.outerBoundary
        .map((vertex) => background.getImageToScreen(vertex))
        .toList()));
    await add(innerBoundary = Boundary(level.track.innerBoundary
        .map((vertex) => background.getImageToScreen(vertex))
        .toList()));

    addContactCallback(
        contactCallback = BoundaryContactCallback(_onCollisionDetected));

    gameComponents = {_playerBody, outerBoundary, innerBoundary};
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_collisionDetected) {
      _onGameOver();
      _collisionDetected = false;
    }
  }

  @override
  void onTapDown(TapDownDetails details) {
    // Iterate over GameHelpers on firstLaunch
    if (_gameHelpShown) {
      remove(gameHelper.current);
      if (gameHelper.moveNext()) {
        add(gameHelper.current);
        return;
      }
      _swapMenuOverlay(kCountDownOverlay);
      _gameHelpShown = false;
      return;
    }

    _playerBody?.spin();
    return super.onTapDown(details);
  }

  void _onCollisionDetected() {
    _collisionDetected = true;
    _timerService.cancel();

    _audioService.playDropSound(kAudioToiletDropSound);

    _updateScoreAndAchievements();
  }

  void _onGameOver() async {
    gameComponents.forEach((c) => remove(c));
    removeContactCallback(contactCallback);

    await gameOverCallback();

    _swapMenuOverlay(kGameOverMenu);
  }

  /// Updates score and achievement status async in background.
  void _updateScoreAndAchievements() async {
    _updateLocalScore();

    final _gameService = locator<GameService>();

    if (_gameService.signedIn) {
      // submit score
      await _gameService.submitScore(
          kAndroidLeaderBoard, _timerService.seconds.value);

      // update duration achievement
      kDurationAchievements.forEach((duration, id) {
        if (_timerService.seconds.value > duration) {
          _gameService.unlockAchievement(id);
        }
      });

      // update play count
      kPlayCountAchievements
          .forEach((id) => _gameService.incrementAchievement(id));
    }
  }

  /// Saves highscore in shared preferences to enable some features based on the user experience.
  void _updateLocalScore() {
    final score = _timerService.seconds.value.toDouble();
    if (score > _currentHighscore) {
      _prefService.setDouble(kPrefKeyHighscore, score);
    }
  }

  void showStartMenu() => _swapMenuOverlay(kStartMenu);
  void showCreditsMenu() => _swapMenuOverlay(kCreditsMenu);

  /// Removes all active overlays
  void _removeOverlays() {
    final activeOverlays = overlays.value.toSet();
    activeOverlays.forEach((overlay) {
      overlays.remove(overlay);
    });
  }

  /// Removes all active overlays in favor of [overlayName]
  void _swapMenuOverlay(String overlayName) {
    _removeOverlays();
    overlays.add(overlayName);
  }
}
