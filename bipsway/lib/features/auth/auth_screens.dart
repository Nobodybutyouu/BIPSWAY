import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});
  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), _resolveSession);
  }

  Future<void> _resolveSession() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final profile = await AuthService().readAppUser(firebaseUser.uid);
        if (profile.status == AccountStatus.disabled) {
          await AuthService().signOut();
          if (mounted) {
            context.go('/login-as?message=${Uri.encodeComponent('Your account has been disabled.')}');
          }
          return;
        }
        if (mounted) {
          context.go(profile.role == AppRole.admin ? '/admin/dashboard' : '/navigator/home');
        }
        return;
      }
    } catch (_) {
      // The login page remains available when Firebase is not reachable.
    }
    if (mounted) context.go('/login-as');
  }

  @override
  Widget build(BuildContext context) => const AuthFrame(child: Text('Bipsway'));
}

class LoginAsScreen extends StatelessWidget {
  const LoginAsScreen({this.message, super.key});

  final String? message;
  @override
  Widget build(BuildContext context) => AuthFrame(
        title: 'Login As',
        child: Column(children: [
          if (message != null) ...[
            Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(onPressed: () => context.go('/admin-login'), child: const Text('Admin')),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/navigator-login'), child: const Text('Navigator')),
        ]),
      );
}

class NavigatorLoginScreen extends StatelessWidget {
  const NavigatorLoginScreen({super.key});
  @override
  Widget build(BuildContext context) => CredentialScreen(
        title: "Navigator's Credential validation",
        expectedRole: AppRole.navigator,
        alternateLabel: "Don't have account? Sign Up",
        onAlternate: () => context.go('/sign-up'),
      );
}

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const CredentialScreen(
        title: "Admin's Credential validation",
        expectedRole: AppRole.admin,
      );
}

class CredentialScreen extends StatefulWidget {
  const CredentialScreen({required this.title, required this.expectedRole, this.alternateLabel, this.onAlternate, super.key});
  final String title;
  final AppRole expectedRole;
  final String? alternateLabel;
  final VoidCallback? onAlternate;
  @override
  State<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends State<CredentialScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      await AuthService().signIn(email: email.text, password: password.text, expectedRole: widget.expectedRole);
      if (!mounted) return;
      context.go(widget.expectedRole == AppRole.admin ? '/admin/dashboard' : '/navigator/home');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
        title: widget.title,
        child: Column(children: [
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          if (widget.expectedRole == AppRole.navigator)
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?'))),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Signing in...' : 'Login')),
          if (widget.onAlternate != null) TextButton(onPressed: widget.onAlternate, child: Text(widget.alternateLabel!)),
        ]),
      );

  Future<void> _forgotPassword() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Enter your Email Address first.');
      return;
    }
    try {
      await AuthService().sendPasswordResetEmail(email.text);
      if (mounted) setState(() => error = 'Password-reset email sent.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController();
  final email = TextEditingController();
  String affiliation = 'student';
  String purpose = 'enrollment_inquiry';
  String? error;
  bool busy = false;

  @override
  void dispose() {
    for (final controller in [username, password, fullName, email]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
        title: 'Create account',
        child: SingleChildScrollView(child: Column(children: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 10),
          TextField(controller: fullName, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 10),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 10),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: affiliation, decoration: const InputDecoration(labelText: 'Affiliation'), items: const [DropdownMenuItem(value: 'student', child: Text('Student')), DropdownMenuItem(value: 'faculty', child: Text('Faculty')), DropdownMenuItem(value: 'staff', child: Text('Staff')), DropdownMenuItem(value: 'visitor', child: Text('Visitor')), DropdownMenuItem(value: 'others', child: Text('Others'))], onChanged: (value) => setState(() => affiliation = value!)),
          if (affiliation == 'visitor' || affiliation == 'others') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: purpose, decoration: const InputDecoration(labelText: 'Purpose'), items: const [DropdownMenuItem(value: 'enrollment_inquiry', child: Text('Enrollment Inquiry')), DropdownMenuItem(value: 'visiting_department', child: Text('Visiting Department')), DropdownMenuItem(value: 'campus_event', child: Text('Campus Event')), DropdownMenuItem(value: 'others', child: Text('Others'))], onChanged: (value) => setState(() => purpose = value!)),
          ],
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 14),
          FilledButton(onPressed: busy ? null : _submit, child: Text(busy ? 'Creating...' : 'Create account')),
        ])),
      );

  Future<void> _submit() async {
    setState(() { busy = true; error = null; });
    try {
      await AuthService().signUp(username: username.text, password: password.text, fullName: fullName.text, email: email.text, affiliation: affiliation, purpose: affiliation == 'visitor' || affiliation == 'others' ? purpose : null);
      if (mounted) context.go('/navigator-login');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.child, this.title, super.key});
  final Widget child;
  final String? title;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.map_outlined, size: 64),
            const SizedBox(height: 16),
            if (title != null) ...[Text(title!, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 24)],
            child,
          ])),
        ))),
      );
}
