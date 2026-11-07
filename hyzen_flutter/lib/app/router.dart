import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/common.dart';
import '../features/academics/domain/models.dart';
import '../features/academics/presentation/library_screens.dart';
import '../features/admin/admin_screen.dart';
import '../features/admin/presentation/admin_management.dart';
import '../features/admin/presentation/admin_content_screen.dart';
import '../features/admin/presentation/bulk_import_screen.dart';
import '../features/admin/presentation/section_settings_screen.dart';
import '../features/auth/presentation/auth_controllers.dart';
import '../features/auth/presentation/login_screens.dart';
import '../features/auth/presentation/register_screens.dart';
import '../features/auth/presentation/splash_welcome_screens.dart';
import '../features/content/presentation/info_screens.dart';
import '../features/downloads/domain/download_record.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/study_progress/study_progress_screen.dart';
import '../features/study_progress/study_goals_screen.dart';
import '../features/study_progress/study_streak_screen.dart';
import '../features/study_progress/campus_rank_screen.dart';
import '../features/notifications/notice_host.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/presentation/profile_screens.dart';
import '../features/profile/presentation/widgets/account_widgets.dart';
import '../features/pdf_studio/presentation/pdf_studio_screen.dart';
import '../features/pdf_studio/presentation/scan_pdf_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shop/presentation/shop_screens.dart';
import '../features/viewer/viewer_screen.dart';
import '../features/viewer/external_files.dart';
import 'providers.dart';

const _publicPrefixes = [
  '/welcome',
  '/login',
  '/forgot-password',
  '/register',
  '/legal',
  '/study-progress',
];

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

/// All levels use the same reader while preserving the bottom navigation stack.
List<RouteBase> _libraryRoutes([int level = 0]) => [
  GoRoute(
    path: level == 0 ? ':kind' : ':level$level',
    builder: (_, s) {
      final kind = LibraryKindX.parse(s.pathParameters['kind']);
      if (kind == null) return const _RouteError();
      return LibraryLevelScreen(
        kind: kind,
        path: [for (var i = 1; i <= level; i++) s.pathParameters['level$i']!],
      );
    },
    routes: level < 5 ? _libraryRoutes(level + 1) : const [],
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      // Device documents are local, read-only imports, not protected academic
      // content. Opening one must not wait for Firebase or lose its route.
      if (loc == '/imported-viewer' ||
          loc == '/create-pdf' ||
          loc.startsWith('/pdf-studio/viewer/')) {
        return null;
      }
      // Local-only study preview is safe to open before Firebase resolves.
      if (const ['/study-progress', '/study-goals', '/study-streak', '/campus-rank'].contains(loc)) return null;
      if (auth.isLoading && !auth.hasValue) {
        return loc == '/splash' ? null : '/splash';
      }
      final signedIn = auth.valueOrNull != null;
      final isPublic = _publicPrefixes.any(
        (p) => loc == p || loc.startsWith('$p/'),
      );
      if (!signedIn) return isPublic ? null : '/welcome';
      if (loc == '/register/success' || loc.startsWith('/legal/')) return null;
      if (registrationInFlight && loc.startsWith('/register/')) return null;
      if (loc.startsWith('/register/') &&
          ref.read(lastCreatedProfileProvider)?.uid == auth.valueOrNull?.uid) {
        return '/register/success';
      }
      if (loc == '/splash' || isPublic) return '/home';
      if (loc.startsWith('/admin') && !ref.read(isAdminProvider)) {
        return '/home';
      }
      return null;
    },
    errorBuilder: (_, __) => const _RouteError(),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, s) => ForgotPasswordScreen(
          initialEmail: s.extra is String ? s.extra as String : null,
        ),
      ),
      GoRoute(
        path: '/register/personal',
        builder: (_, __) => const RegisterPersonalScreen(),
      ),
      GoRoute(
        path: '/register/academic',
        builder: (_, __) => const RegisterAcademicScreen(),
      ),
      GoRoute(
        path: '/register/credentials',
        builder: (_, __) => const RegisterCredentialsScreen(),
      ),
      GoRoute(
        path: '/register/success',
        builder: (_, __) => const RegisterSuccessScreen(),
      ),
      GoRoute(
        path: '/legal/:doc',
        builder: (_, s) => LegalScreen(doc: s.pathParameters['doc']!),
      ),
      GoRoute(path: '/study-progress', builder: (_, __) => const StudyProgressScreen()),
      GoRoute(path: '/study-goals', builder: (_, __) => const StudyGoalsScreen()),
      GoRoute(path: '/study-streak', builder: (_, __) => const StudyStreakScreen()),
      GoRoute(path: '/campus-rank', builder: (_, __) => const CampusRankScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, nav) =>
            NoticeHost(child: AppShell(navigationShell: nav)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                builder: (_, __) => const StudyHubScreen(),
                routes: _libraryRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, state) =>
                    SearchScreen(focusSearch: state.extra == true),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pdf-studio',
                builder: (_, __) => const PdfStudioScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                builder: (_, __) => const DownloadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const AccountTheme(child: ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'info',
                    builder: (_, __) =>
                        const AccountTheme(child: AccountInfoScreen()),
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (_, __) =>
                        const AccountTheme(child: EditProfileScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                builder: (_, __) => const ShopScreen(),
                routes: [
                  GoRoute(
                    path: 'p/:id',
                    builder: (_, s) =>
                        ProductScreen(id: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const AccountTheme(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/viewer',
        builder: (_, s) => ViewerScreen(
          file: s.extra is FileRef
              ? s.extra as FileRef
              : FileRef.fromMap(s.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/imported-viewer',
        builder: (_, s) => ImportedViewerScreen(
          document: s.extra is ExternalDocument
              ? s.extra as ExternalDocument
              : ref
                    .read(externalHistoryProvider)
                    .where((d) => d.id == s.uri.queryParameters['id'])
                    .firstOrNull,
        ),
      ),
      // The Studio reader is a full-screen root route, NOT a shell branch
      // child. It is opened from root routes (/create-pdf, /viewer,
      // /imported-viewer, tool screens); pushing a shell child from there made
      // go_router build a second StatefulShellRoute with the same navigator
      // GlobalKeys, which crashed release builds with the framework.dart
      // `_dependents.isEmpty` / notifyClients descendant assertions.
      GoRoute(
        path: '/pdf-studio/viewer/:fileId',
        builder: (_, state) => PdfStudioFileViewerScreen(
          fileId: state.pathParameters['fileId']!,
          initialPage:
              int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 1,
        ),
      ),
      GoRoute(
        path: '/create-pdf',
        builder: (_, s) =>
            ScanPdfScreen(initialAction: s.uri.queryParameters['source']),
      ),
      GoRoute(path: '/lectures', builder: (_, __) => const LecturesScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(
        path: '/order-success',
        builder: (_, s) => s.extra is Map<String, dynamic>
            ? OrderSuccessScreen(order: s.extra as Map<String, dynamic>)
            : const MyOrdersScreen(),
      ),
      GoRoute(path: '/orders', builder: (_, __) => const MyOrdersScreen()),
      GoRoute(
        path: '/blog',
        builder: (_, __) => const BlogScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) => BlogPostScreen(id: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminScreen(),
        routes: [
          GoRoute(
            path: 'sections',
            builder: (_, __) => const SectionSettingsScreen(),
          ),
          GoRoute(path: 'import', builder: (_, __) => const BulkImportScreen()),
          GoRoute(path: 'stats', builder: (_, __) => const AdminStatsScreen()),
          GoRoute(
            path: 'manage/:section',
            builder: (_, s) {
              final section = s.pathParameters['section']!;
              return switch (section) {
                'products' ||
                'blogs' ||
                'credits' ||
                'social' => AdminListScreen(section: section),
                'orders' => const AdminOrdersScreen(),
                'messages' => const AdminMessagesScreen(),
                'lectures' => const AdminLecturesScreen(),
                'connection' => const AdminConnectionScreen(),
                'data' => const AdminDataScreen(),
                'history' => const AdminHistoryScreen(),
                'theme' => const AdminThemeScreen(),
                'catalog' ||
                'delivery' ||
                'announcement' ||
                'notice' ||
                'about' ||
                'settings' => AdminDocumentScreen(section: section),
                _ => const _RouteError(),
              };
            },
          ),
          GoRoute(
            path: 'content/:kind',
            builder: (_, s) {
              final kind = LibraryKindX.parse(s.pathParameters['kind']);
              return kind == null
                  ? const _RouteError()
                  : AdminContentScreen(kind: kind);
            },
          ),
        ],
      ),
    ],
  );
  var lastPath = router.routeInformationProvider.value.uri.path;
  void resetSearchOnEntry() {
    final path = router.routeInformationProvider.value.uri.path;
    if (path == '/search' && lastPath != path) {
      ref.read(searchRevisionProvider.notifier).state++;
    }
    lastPath = path;
  }

  router.routeInformationProvider.addListener(resetSearchOnEntry);
  ref.onDispose(
    () => router.routeInformationProvider.removeListener(resetSearchOnEntry),
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RouteError extends StatelessWidget {
  const _RouteError();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const HTopBar(title: 'Page unavailable'),
    body: EmptyState(
      icon: Icons.search_off_rounded,
      title: 'This page could not be found',
      action: HButton(label: 'Go home', onPressed: () => context.go('/home')),
    ),
  );
}
