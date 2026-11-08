import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScanFilterChoice {
  const ScanFilterChoice(
    this.filter,
    this.all, {
    this.strength = 100,
    this.brightness = 0,
    this.contrast = 0,
  });
  final String filter;
  final bool all;
  final int strength;
  final int brightness;
  final int contrast;
}

class ScanFilterSheet extends StatefulWidget {
  const ScanFilterSheet({
    super.key,
    required this.path,
    required this.multiple,
  });
  final String path;
  final bool multiple;
  @override
  State<ScanFilterSheet> createState() => _ScanFilterSheetState();
}

class _ScanFilterSheetState extends State<ScanFilterSheet> {
  static const _camera = MethodChannel('com.hyzen.pharmd/camera_pages');
  bool _allowPop = false;
  Future<void> _close([ScanFilterChoice? choice]) async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, choice);
  }

  String _filter = 'original', _committed = 'original';
  int _strength = 100, _brightness = 0, _contrast = 0;
  int _committedStrength = 100, _committedBrightness = 0, _committedContrast = 0;
  bool _all = false, _loading = true, _processing = false;
  Uint8List? _bytes;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await _camera.invokeMapMethod<String, dynamic>('pageInfo', {
        'path': widget.path,
      });
      _committed = info?['filter'] as String? ?? 'original';
      _filter = _committed;
      _committedStrength = (info?['strength'] as num?)?.round() ?? 100;
      _committedBrightness = (info?['brightness'] as num?)?.round() ?? 0;
      _committedContrast = (info?['contrast'] as num?)?.round() ?? 0;
      _brightness = _committedBrightness;
      _strength = _committedStrength;
      _contrast = _committedContrast;
    } catch (_) {}
    if (mounted) _preview();
  }

  Future<void> _preview() async {
    if (_processing) return;
    _processing = true;
    while (mounted) {
      final requested = _filter;
      final requestedBrightness = _brightness;
      final requestedContrast = _contrast;
      final requestedStrength = _strength;
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final bytes = await _camera.invokeMethod<Uint8List>('preview', {
          'path': widget.path,
          'filter': requested,
          'strength': requestedStrength,
          'brightness': _brightness,
          'contrast': _contrast,
        });
        if (!mounted) break;
        if (requested == _filter &&
            requestedBrightness == _brightness &&
            requestedContrast == _contrast &&
            requestedStrength == _strength) {
          setState(() {
            _bytes = bytes;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted &&
            requested == _filter &&
            requestedBrightness == _brightness &&
            requestedContrast == _contrast &&
            requestedStrength == _strength) {
          setState(() {
            _error = 'Preview could not load. Select a filter to retry.';
            _loading = false;
          });
        }
      }
      if (requested == _filter &&
          requestedBrightness == _brightness &&
          requestedContrast == _contrast &&
          requestedStrength == _strength) {
        break;
      }
    }
    _processing = false;
  }

  Future<void> _back() async {
    if (_filter == _committed &&
        _strength == _committedStrength &&
        _brightness == _committedBrightness &&
        _contrast == _committedContrast &&
        !_all) {
      if (mounted) await _close();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apply filter changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: _loading ? null : () => Navigator.pop(c, 'apply'),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'discard') await _close();
    if (action == 'apply') {
      _close(
        ScanFilterChoice(
          _filter,
          _all,
          strength: _strength,
          brightness: _brightness,
          contrast: _contrast,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _close,
                tooltip: 'Cancel filters',
                icon: const Icon(Icons.close),
              ),
              const Expanded(
                child: Text(
                  'Filters',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              IconButton(
                tooltip: 'Confirm filter',
                onPressed: _loading || _error != null
                    ? null
                    : () =>
                        _close(
                          ScanFilterChoice(
                            _filter,
                            _all,
                            strength: _strength,
                            brightness: _brightness,
                            contrast: _contrast,
                          ),
                        ),
                icon: const Icon(Icons.check),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _bytes == null
                ? Center(child: Text(_error ?? 'Preparing preview…'))
                : Image.memory(
                    _bytes!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
          ),
          if (_error != null) Text(_error!),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in [
                  ('original', 'Original'),
                  ('magic', 'Magic colour'),
                  ('gray', 'Grayscale'),
                  ('bw', 'Black & white'),
                ])
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(item.$2),
                      selected: _filter == item.$1,
                      onSelected: (_) {
                        setState(() => _filter = item.$1);
                        _preview();
                      },
                    ),
                  ),
              ],
            ),
          ),
          _AdjustmentSlider(
            label: 'Filter strength',
            value: _strength,
            min: 0,
            max: 100,
            icon: Icons.tune_rounded,
            onChanged: (v) => setState(() => _strength = v.round()),
            onChangeEnd: (_) => _preview(),
          ),
          _AdjustmentSlider(
            label: 'Brightness',
            value: _brightness,
            icon: Icons.brightness_6_outlined,
            onChanged: (v) => setState(() => _brightness = v.round()),
            onChangeEnd: (_) => _preview(),
          ),
          _AdjustmentSlider(
            label: 'Contrast',
            value: _contrast,
            icon: Icons.contrast_rounded,
            onChanged: (v) => setState(() => _contrast = v.round()),
            onChangeEnd: (_) => _preview(),
          ),
          if (widget.multiple)
            SwitchListTile(
              title: const Text('Apply to all pages'),
              value: _all,
              onChanged: (v) => setState(() => _all = v),
            ),
        ],
      ),
    ),
  );
}

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.label,
    required this.value,
    this.min = -100,
    this.max = 100,
    required this.icon,
    required this.onChanged,
    required this.onChangeEnd,
  });
  final String label;
  final int value;
  final double min, max;
  final IconData icon;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
    child: Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        SizedBox(width: 76, child: Text(label)),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            value: value.toDouble().clamp(min, max).toDouble(),
            label: '$value',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(width: 34, child: Text('$value', textAlign: TextAlign.end)),
      ],
    ),
  );
}
