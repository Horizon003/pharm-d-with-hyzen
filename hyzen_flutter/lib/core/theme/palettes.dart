import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

/// One general product palette keeps the study utility visually consistent.
const brandPalettes = <String, (String, Color)>{
  'graphite': ('Graphite', Color(0xFF1C1C1E)),
  // Kept for admin-managed legacy content; end users no longer select these.
  'teal': ('Hyzen Teal', Color(0xFF087F76)),
  'ocean': ('Clinical Blue', Color(0xFF2B6F9E)),
  'green': ('Pharmacy Green', Color(0xFF15724A)),
  'sage': ('Apothecary Sage', Color(0xFF5B6E4A)),
  'slate': ('Graphite Slate', Color(0xFF3B5664)),
  'amber': ('Calendula Gold', Color(0xFF9A6516)),
  'rose': ('Rose Wellness', Color(0xFFA34E6E)),
  'purple': ('Classic Purple', Color(0xFF6D3FD4)),
};

class PaletteController extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPrefsProvider);
    // One-time migration: earlier releases defaulted to purple.
    if (prefs.getBool('brand_palette_v15') != true) {
      final old = prefs.getString('brand_palette');
      if (old == null ||
          old == 'default' ||
          old == 'purple' ||
          old == 'mint' ||
          old == 'lavender') {
        prefs.setString('brand_palette', 'graphite');
      }
      prefs.setBool('brand_palette_v15', true);
    }
    return prefs.getString('brand_palette') ?? 'graphite';
  }

  void set(String id) {
    final chosen = brandPalettes.containsKey(id) ? id : 'graphite';
    state = chosen;
    ref.read(sharedPrefsProvider).setString('brand_palette', chosen);
  }
}

final paletteProvider = NotifierProvider<PaletteController, String>(
  PaletteController.new,
);
final effectivePaletteProvider = Provider<String>((ref) {
  final chosen = ref.watch(paletteProvider);
  return brandPalettes.containsKey(chosen) ? chosen : 'graphite';
});
final paletteColorProvider = Provider<Color>((ref) => const Color(0xFF111111));
