import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/app/router/nav_utils.dart';

void main() {
  group('NavUtils.safePop', () {
    testWidgets('safePop on child route returns to parent', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(onPressed: () => NavUtils.safePop(context), child: const Text('pop'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pop'), findsOneWidget);

      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('safePop at root does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(onPressed: () => NavUtils.safePop(context), child: const Text('pop')),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();
      expect(find.text('pop'), findsOneWidget);
    });
  });

  group('NavUtils.goHome', () {
    testWidgets('goHome pops to root', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: Builder(
                            builder: (ctx2) {
                              return ElevatedButton(
                                onPressed: () => NavUtils.goHome(ctx2),
                                child: const Text('goHome'),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('push2'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('push2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('goHome'));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('goHome at root does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(onPressed: () => NavUtils.goHome(context), child: const Text('home')),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
