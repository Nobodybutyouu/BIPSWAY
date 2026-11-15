import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bipsway/app/theme.dart';
import 'package:bipsway/features/auth/auth_screens.dart';

void main() {
  testWidgets('launches the Login As foundation screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const LoginAsScreen(),
    ));

    expect(find.text('Login As'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Navigator'), findsOneWidget);
  });

  testWidgets('launch screen builds with the logo semantics fallback', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LaunchScreen()));

    expect(find.bySemanticsLabel('Bipsway logo'), findsOneWidget);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/images/'));
  });
}
