import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import 'mascot_motion.dart';

/// The contract for the approved Hyzen Rive file.
///
/// The exported .riv must contain these state machines so the same character
/// can be driven by semantic app events rather than screen-specific animation
/// code. Until that export is supplied, the existing transparent pose pack is
/// used as a safe visual fallback.
enum HyzenRiveState {
  welcome('welcome'),
  loading('loading'),
  peeking('peeking'),
  studying('studying'),
  downloading('downloading'),
  success('success'),
  error('error');

  const HyzenRiveState(this.machineName);
  final String machineName;

  HyzenMascotState get fallback => switch (this) {
    HyzenRiveState.welcome => HyzenMascotState.welcome,
    HyzenRiveState.loading => HyzenMascotState.downloading,
    HyzenRiveState.peeking => HyzenMascotState.peeking,
    HyzenRiveState.studying => HyzenMascotState.studying,
    HyzenRiveState.downloading => HyzenMascotState.downloading,
    HyzenRiveState.success => HyzenMascotState.success,
    HyzenRiveState.error => HyzenMascotState.downloading,
  };
}

class HyzenRiveMascot extends StatelessWidget {
  const HyzenRiveMascot({
    super.key,
    required this.state,
    this.size = 220,
    this.semanticLabel = 'Hyzen panda mascot',
  });

  static const assetPath = 'assets/mascot/hyzen_mascot.riv';
  final HyzenRiveState state;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _riveAvailable,
      initialData: _riveKnown,
      builder: (context, snapshot) {
        if (snapshot.data != true ||
            MediaQuery.disableAnimationsOf(context) ||
            !TickerMode.of(context)) {
          return HyzenMascot(
            state: state.fallback,
            size: size,
            semanticLabel: semanticLabel,
          );
        }
        return Semantics(
          image: true,
          label: semanticLabel,
          child: SizedBox(
            width: size,
            height: size * 1.5,
            child: RiveAnimation.asset(
              assetPath,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              stateMachines: [state.machineName],
            ),
          ),
        );
      },
    );
  }

  // Checked once per process; previously every rebuild re-read the bundle.
  static bool? _riveKnown;
  static final Future<bool> _riveAvailable = _hasRiveAsset().then(
    (v) => _riveKnown = v,
  );

  static Future<bool> _hasRiveAsset() async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } on FlutterError {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
