import '../../../app/providers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/polish_ui.dart';
import '../../../core/utils/links.dart';
import '../../downloads/data/downloads_controller.dart';
import '../../downloads/domain/download_record.dart';
import '../data/search_index.dart';
import '../data/search_scope.dart';

void openSearchHit(BuildContext context, SearchHit hit) {
  if (hit.studioFileId != null) {
    context.push(
      '/pdf-studio/viewer/${hit.studioFileId}?page=${hit.page ?? 1}',
    );
  } else if (hit.type == HitType.file && hit.url != null && hit.kind != null) {
    context.push(
      '/viewer',
      extra: FileRef(
        kind: hit.kind!,
        title: hit.title,
        url: hit.url!,
        trail: hit.trail,
      ),
    );
  } else if (hit.type == HitType.lecture && hit.url != null) {
    openLink(context, hit.url!);
  } else {
    context.push(hit.route);
  }
}

class SearchScopePills extends StatelessWidget {
  const SearchScopePills({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final SearchScope value;
  final ValueChanged<SearchScope> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 2,
    children: [
      for (final scope in SearchScope.values)
        ChoiceChip(
          key: ValueKey('search-scope-${scope.name}'),
          label: Text(scope.label),
          selected: scope == value,
          onSelected: (_) => onChanged(scope),
          selectedColor: HColors.ink,
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scope == value ? Colors.white : HColors.ink,
          ),
          checkmarkColor: Colors.white,
        ),
    ],
  );
}

class HomeSearch extends ConsumerStatefulWidget {
  const HomeSearch({super.key});
  @override
  ConsumerState<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends ConsumerState<HomeSearch> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  SearchScope _scope = SearchScope.all;
  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _changed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionRevisionProvider, (_, __) {
      _debounce?.cancel();
      _controller.clear();
      setState(() {
        _query = '';
        _scope = SearchScope.all;
      });
    });
    final searching = _query.trim().isNotEmpty;
    final hits = searching
        ? runSearch(
            scopedIndex(
              ref.watch(searchIndexProvider),
              ref.watch(downloadsProvider).values,
              _scope,
            ),
            _query,
            limit: 5,
          )
        : <SearchHit>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: HMotion.duration(context, HMotion.medium),
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: _focus.hasFocus
                  ? const [
                      Color(0xFFB4A3E4),
                      Color(0xFFF1C8B1),
                      Color(0xFFB3D7D9),
                    ]
                  : const [
                      Color(0xFFDCD4EE),
                      Color(0xFFEEE0D5),
                      Color(0xFFCDDDE0),
                    ],
            ),
            boxShadow: _focus.hasFocus
                ? const [BoxShadow(color: Color(0x16B49AD9), blurRadius: 10)]
                : const [],
          ),
          child: TextField(
            key: const ValueKey('home-search-input'),
            controller: _controller,
            focusNode: _focus,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            scrollPadding: const EdgeInsets.fromLTRB(20, 120, 20, 24),
            onSubmitted: (value) => context.push(
              '/search?q=${Uri.encodeQueryComponent(value)}&scope=${_scope.name}',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search notes, books, lectures…',
              filled: true,
              fillColor: const Color(0xF2FFFFFF),
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: HAssetIcon('icon-search', size: 23),
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _debounce?.cancel();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(23),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(23),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(23),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_focus.hasFocus || searching) ...[
          const SizedBox(height: 6),
          SearchScopePills(
            value: _scope,
            onChanged: (scope) => setState(() => _scope = scope),
          ),
        ],
        if (searching) ...[
          if (hits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No matching resources loaded. Try another word or open full search.',
              ),
            ),
          for (final hit in hits)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                hit.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                hit.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.arrow_forward_rounded, size: 16),
              onTap: () => openSearchHit(context, hit),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(
                '/search?q=${Uri.encodeQueryComponent(_query)}&scope=${_scope.name}',
              ),
              child: const Text('View all results'),
            ),
          ),
        ],
      ],
    );
  }
}
