import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';
import '../features/admin/buildings/building_detail_screens.dart';
import '../features/admin/buildings/manage_screens.dart';
import '../features/admin/buildings/room_form_screen.dart';
import '../features/admin/content/admin_content_screens.dart';
import '../features/navigator/navigator_screens.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/providers.dart';
import 'package:latlong2/latlong.dart';

final appRouter = GoRouter(
  initialLocation: '/launch',
  redirect: (context, state) async {
    const publicPaths = {
      '/launch', '/login-as', '/navigator-login', '/sign-up', '/admin-login'
    };
    if (publicPaths.contains(state.uri.path)) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '/login-as';
    if (state.uri.path.startsWith('/admin')) {
      try {
        final profile = await AuthService().readAppUser(user.uid);
        if (profile.role != AppRole.admin) {
          return '/login-as?message=${Uri.encodeComponent('Admin access is required.')}';
        }
      } catch (_) {
        return '/login-as?message=${Uri.encodeComponent('Admin access is required.')}';
      }
    }
    return null;
  },
  routes: [
    GoRoute(path: '/launch', builder: (context, state) => const LaunchScreen()),
    GoRoute(
      path: '/login-as',
      builder: (context, state) => LoginAsScreen(
        message: state.uri.queryParameters['message'],
      ),
    ),
    GoRoute(path: '/navigator-login', builder: (context, state) => const NavigatorLoginScreen()),
    GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/admin-login', builder: (context, state) => const AdminLoginScreen()),
    GoRoute(path: '/admin/coming-soon/:section', builder: (context, state) => ComingSoonScreen(title: state.pathParameters['section'] ?? 'Coming soon')),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => NavigatorShell(shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/navigator/home',
            builder: (context, state) => const NavigatorMapHomeScreen(),
            routes: [
              GoRoute(path: 'settings', builder: (context, state) => const EmptyPage(title: 'Settings placeholder')),
              GoRoute(
                path: 'building/:buildingId',
                builder: (context, state) => NavigatorBuildingRouteScreen(buildingId: state.pathParameters['buildingId']!),
                routes: [
                  GoRoute(path: 'search', builder: (context, state) => NavigatorSearchScreen(buildingId: state.pathParameters['buildingId']!)),
                  GoRoute(path: 'map', builder: (context, state) => NavigatorBuildingMapScreen(buildingId: state.pathParameters['buildingId']!)),
                  GoRoute(path: 'room/:roomId', builder: (context, state) => NavigatorRoomLocationRouteScreen(buildingId: state.pathParameters['buildingId']!, roomId: state.pathParameters['roomId']!)),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/navigator/directory', builder: (context, state) => const EmptyPage(title: 'Directory'))]),
        StatefulShellBranch(routes: [GoRoute(path: '/navigator/profile', builder: (context, state) => const EmptyPage(title: 'Profile'))]),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AdminShell(shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/admin/dashboard', builder: (context, state) => const DashboardScreen())]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/admin/manage',
            builder: (context, state) => const ManageHubScreen(),
            routes: [
              GoRoute(
                path: 'buildings',
                builder: (context, state) => BuildingsListScreen(message: state.uri.queryParameters['message']),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const BuildingFormScreen()),
                  GoRoute(
                    path: ':buildingId',
                    builder: (context, state) => BuildingDetailScreen(buildingId: state.pathParameters['buildingId']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => BuildingEditRouteScreen(
                          buildingId: state.pathParameters['buildingId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'floors/:floorId',
                        builder: (context, state) => FloorDetailScreen(
                          buildingId: state.pathParameters['buildingId']!,
                          floorId: state.pathParameters['floorId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'rooms/new',
                            builder: (context, state) => RoomFormRouteScreen(
                              buildingId: state.pathParameters['buildingId']!,
                              floorId: state.pathParameters['floorId']!,
                            ),
                          ),
                          GoRoute(
                            path: 'rooms/:roomId/edit',
                            builder: (context, state) => RoomFormRouteScreen(
                              buildingId: state.pathParameters['buildingId']!,
                              floorId: state.pathParameters['floorId']!,
                              roomId: state.pathParameters['roomId']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'pick-location',
                builder: (context, state) => PickLocationScreen(
                  initial: state.extra is LatLng ? state.extra as LatLng : null,
                ),
              ),
              GoRoute(
                path: 'events',
                builder: (context, state) => const EventsListScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const EventFormRouteScreen()),
                  GoRoute(path: ':eventId/edit', builder: (context, state) => EventFormRouteScreen(eventId: state.pathParameters['eventId'])),
                  GoRoute(path: ':eventId/speakers', builder: (context, state) => EventSpeakersRouteScreen(eventId: state.pathParameters['eventId']), routes: [
                    GoRoute(path: 'new', builder: (context, state) => const SpeakerFormScreen()),
                    GoRoute(path: ':index/edit', builder: (context, state) => SpeakerFormScreen(index: int.tryParse(state.pathParameters['index'] ?? ''))),
                  ]),
                  GoRoute(path: 'speakers', builder: (context, state) => const EventSpeakersScreen(), routes: [
                    GoRoute(path: 'new', builder: (context, state) => const SpeakerFormScreen()),
                    GoRoute(path: ':index/edit', builder: (context, state) => SpeakerFormScreen(index: int.tryParse(state.pathParameters['index'] ?? ''))),
                  ]),
                ],
              ),
              GoRoute(
                path: 'org-chart',
                builder: (context, state) => const OrgChartScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const PositionFormRouteScreen()),
                  GoRoute(path: ':positionId/edit', builder: (context, state) => PositionFormRouteScreen(positionId: state.pathParameters['positionId'])),
                ],
              ),
              GoRoute(
                path: 'personnel',
                builder: (context, state) => const PersonnelListScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const PersonFormRouteScreen()),
                  GoRoute(path: ':personId/edit', builder: (context, state) => PersonFormRouteScreen(personId: state.pathParameters['personId'])),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/admin/reports', builder: (context, state) => const EmptyPage(title: 'Reports'))]),
        StatefulShellBranch(routes: [GoRoute(path: '/admin/users', builder: (context, state) => const EmptyPage(title: 'Users'))]),
      ],
    ),
  ],
);

class NavigatorShell extends StatelessWidget {
  const NavigatorShell(this.shell, {super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => RoleShell(
        title: 'Bipsway', shell: shell,
        tabs: const ['Home', 'Directory', 'Profile'],
        drawer: BipswayDrawer(isAdmin: false, shell: shell),
      );
}

class AdminShell extends StatelessWidget {
  const AdminShell(this.shell, {super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => RoleShell(
        title: 'Admin', shell: shell,
        tabs: const ['Dashboard', 'Manage', 'Reports', 'Users'],
        drawer: BipswayDrawer(isAdmin: true, shell: shell),
      );
}

class RoleShell extends StatelessWidget {
  const RoleShell({required this.title, required this.shell, required this.tabs, required this.drawer, super.key});
  final String title;
  final StatefulNavigationShell shell;
  final List<String> tabs;
  final Widget drawer;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        drawer: drawer,
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          destinations: [
            for (final tab in tabs)
              NavigationDestination(icon: const Icon(Icons.circle_outlined), label: tab),
          ],
          onDestinationSelected: shell.goBranch,
        ),
      );
}

class BipswayDrawer extends ConsumerWidget {
  const BipswayDrawer({required this.isAdmin, this.shell, super.key});
  final bool isAdmin;
  final StatefulNavigationShell? shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAppUserProvider);
    final name = profile.asData?.value?.fullName;
    final items = isAdmin
        ? const ['Dashboard', 'Manage', 'Announcements', 'Reports', 'Users', 'Settings']
        : const ['Home', 'Directory', 'Profile', 'Settings'];
    return Drawer(
      child: SafeArea(
        child: ListView(children: [
          UserAccountsDrawerHeader(
            accountName: Text(name == null || name.isEmpty ? 'Bipsway user' : name),
            accountEmail: Text(isAdmin ? 'Admin' : 'Navigator'),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
          ),
          for (final item in items)
            ListTile(
              title: Text(item),
              onTap: () {
                Navigator.pop(context);
                final index = isAdmin
                    ? {'Dashboard': 0, 'Manage': 1, 'Reports': 2, 'Users': 3}[item]
                    : {'Home': 0, 'Directory': 1, 'Profile': 2}[item];
                if (!isAdmin && item == 'Settings') {
                  context.go('/navigator/home/settings');
                } else if (index != null && shell != null) {
                  shell!.goBranch(index);
                }
              },
            ),
          ListTile(
            title: const Text('Log Out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login-as');
            },
          ),
        ]),
      ),
    );
  }
}

class EmptyPage extends StatelessWidget {
  const EmptyPage({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Center(child: Text('$title placeholder'));
}
