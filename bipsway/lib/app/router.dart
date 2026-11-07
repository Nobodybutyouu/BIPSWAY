import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';

final appRouter = GoRouter(
  initialLocation: '/launch',
  redirect: (context, state) {
    const publicPaths = {
      '/launch', '/login-as', '/navigator-login', '/sign-up', '/admin-login'
    };
    if (publicPaths.contains(state.uri.path)) return null;
    try {
      return FirebaseAuth.instance.currentUser == null ? '/login-as' : null;
    } catch (_) {
      return '/login-as';
    }
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
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => NavigatorShell(shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/navigator/home', builder: (context, state) => const EmptyPage(title: 'Home'))]),
        StatefulShellBranch(routes: [GoRoute(path: '/navigator/directory', builder: (context, state) => const EmptyPage(title: 'Directory'))]),
        StatefulShellBranch(routes: [GoRoute(path: '/navigator/profile', builder: (context, state) => const EmptyPage(title: 'Profile'))]),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AdminShell(shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/admin/dashboard', builder: (context, state) => const EmptyPage(title: 'Dashboard'))]),
        StatefulShellBranch(routes: [GoRoute(path: '/admin/manage', builder: (context, state) => const EmptyPage(title: 'Manage'))]),
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
        drawerItems: const ['Home', 'Directory', 'Profile', 'Settings'],
      );
}

class AdminShell extends StatelessWidget {
  const AdminShell(this.shell, {super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => RoleShell(
        title: 'Admin', shell: shell,
        tabs: const ['Dashboard', 'Manage', 'Reports', 'Users'],
        drawerItems: const ['Dashboard', 'Manage', 'Announcements', 'Reports', 'Users', 'Settings'],
      );
}

class RoleShell extends StatelessWidget {
  const RoleShell({required this.title, required this.shell, required this.tabs, required this.drawerItems, super.key});
  final String title;
  final StatefulNavigationShell shell;
  final List<String> tabs;
  final List<String> drawerItems;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(children: [
              const DrawerHeader(child: Text('Bipsway')),
              ...drawerItems.map((item) => ListTile(
                    title: Text(item),
                    onTap: () {
                      Navigator.pop(context);
                      final index = tabs.indexOf(item);
                      if (index >= 0) shell.goBranch(index);
                    },
                  )),
              ListTile(
                title: const Text('Log Out'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) context.go('/login-as');
                },
              ),
            ]),
          ),
        ),
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

class EmptyPage extends StatelessWidget {
  const EmptyPage({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Center(child: Text('$title placeholder'));
}
