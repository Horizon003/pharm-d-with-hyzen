import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../academics/domain/models.dart';
import '../../../app/providers.dart';
import '../domain/site_models.dart';
import 'content_source.dart';

/// Typed view over a content key with cache/offline metadata.
class Loaded<T> {
  const Loaded(this.data, {required this.fromCache, this.fetchedAt});
  final T data;
  final bool fromCache;
  final DateTime? fetchedAt;
}

AsyncValue<Loaded<T>> _map<T>(
  AsyncValue<ContentSnapshot> a,
  T Function(Object? v) f,
) => a.whenData(
  (s) => Loaded(f(s.value), fromCache: s.fromCache, fetchedAt: s.fetchedAt),
);

final settingsProvider = Provider<AsyncValue<Loaded<SiteSettings>>>(
  (ref) => _map(
    ref.watch(contentProvider('pw_settings')),
    (v) => SiteSettings(asMap(v)),
  ),
);

/// Settings value or safe defaults (never blocks UI).
final siteSettingsProvider = Provider<SiteSettings>(
  (ref) =>
      ref.watch(settingsProvider).valueOrNull?.data ?? SiteSettings(const {}),
);

final sectionEnabledProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(siteSettingsProvider).sectionEnabled(id),
);

Library _parseLibrary(Map<String, dynamic> input) =>
    Library.parse(LibraryKind.values.byName(input['kind']), input['value']);
final parsedLibraryProvider =
    FutureProvider.family<Loaded<Library>, LibraryKind>((ref, kind) async {
      final snapshot = await ref.watch(contentProvider(kind.storageKey).future);
      final lib = await compute(_parseLibrary, {
        'kind': kind.name,
        'value': snapshot.value,
      });
      return Loaded(
        lib,
        fromCache: snapshot.fromCache,
        fetchedAt: snapshot.fetchedAt,
      );
    });
final libraryProvider =
    Provider.family<AsyncValue<Loaded<Library>>, LibraryKind>((ref, kind) {
      final year = ref.watch(professionalYearProvider);
      final admin = ref.watch(isAdminProvider);
      return ref.watch(parsedLibraryProvider(kind)).whenData((loaded) {
        final library = loaded.data;
        return Loaded(
          admin || year == null
              ? library
              : Library(
                  kind,
                  library.years.where((y) => y.yearNumber == year).toList(),
                ),
          fromCache: loaded.fromCache,
          fetchedAt: loaded.fetchedAt,
        );
      });
    });

final lecturesProvider = Provider<AsyncValue<Loaded<List<LectureYear>>>>((ref) {
  final year = ref.watch(professionalYearProvider);
  final admin = ref.watch(isAdminProvider);
  return _map(
    ref.watch(contentProvider('pw_lectures_tree')),
    (v) => LectureYear.parseAll(v)
        .where(
          (y) =>
              admin ||
              year == null ||
              (professionalNumber(y.label) ?? professionalNumber(y.id)) == year,
        )
        .toList(),
  );
});

final announcementSlidesProvider = Provider<List<Announcement>>((ref) {
  final raw = asMap(
    ref.watch(contentProvider('pw_announcement')).valueOrNull?.value,
  );
  if (raw['slides'] is List) {
    return asMapList(
      raw['slides'],
    ).map(Announcement.new).where((slide) => slide.visible).toList();
  }
  final legacy = Announcement(raw);
  return legacy.visible ? [legacy] : [];
});

final announcementProvider = Provider<Announcement?>((ref) {
  final v = ref.watch(contentProvider('pw_announcement')).valueOrNull?.value;
  final a = Announcement(asMap(v));
  return a.visible ? a : null;
});

final aboutProvider = Provider<AsyncValue<Loaded<AboutContent>>>(
  (ref) => _map(
    ref.watch(contentProvider('pw_about')),
    (v) => AboutContent(asMap(v)),
  ),
);

final creditsProvider = Provider<List<CreditCard>>((ref) {
  final v = asMap(ref.watch(contentProvider('pw_credits')).valueOrNull?.value);
  final l = asMapList(v['cards']).map(CreditCard.new).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return l;
});

final socialProvider = Provider<List<SocialLink>>((ref) {
  final l =
      asMapList(ref.watch(contentProvider('pw_social')).valueOrNull?.value)
          .map(SocialLink.new)
          .where((s) => s.enabled && s.url.isNotEmpty)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
  return l;
});

final blogsProvider = Provider<AsyncValue<Loaded<List<BlogPost>>>>(
  (ref) => _map(ref.watch(contentProvider('pw_blogs')), (v) {
    final l = asMapList(v).map(BlogPost.new).where((b) => b.published).toList()
      ..sort(
        (a, b) => (b.publishedAt ?? DateTime(0)).compareTo(
          a.publishedAt ?? DateTime(0),
        ),
      );
    return l;
  }),
);

final productsProvider = Provider<AsyncValue<Loaded<List<Product>>>>(
  (ref) => _map(
    ref.watch(contentProvider('pw_products')),
    (v) => asMapList(
      v,
    ).map(Product.new).where((p) => !p.hidden && p.id.isNotEmpty).toList(),
  ),
);

final deliveryProvider = Provider<DeliverySettings>(
  (ref) => DeliverySettings.fromRaw(
    ref.watch(contentProvider('pw_delivery')).valueOrNull?.value,
  ),
);

/// Force-refresh a set of keys (pull-to-refresh).
Future<void> refreshContent(WidgetRef ref, Iterable<String> keys) async {
  for (final k in keys) {
    forcedRefresh.add(k);
    ref.invalidate(contentProvider(k));
  }
  await Future.wait(
    keys.map(
      (k) => ref.read(contentProvider(k).future).catchError((_) {
        return const ContentSnapshot(value: null, fromCache: true);
      }),
    ),
  );
}
