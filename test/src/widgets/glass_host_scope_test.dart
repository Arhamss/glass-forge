import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

void main() {
  testWidgets('a child of Glass is on glass', (tester) async {
    late bool onGlass;
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            child: Builder(
              builder: (context) {
                onGlass = GlassHostScope.isOnGlass(context);
                return const SizedBox(width: 100, height: 40);
              },
            ),
          ),
        ),
      ),
    );
    expect(onGlass, isTrue);
  });

  testWidgets('a child of a plain layer is not on glass', (tester) async {
    late bool onGlass;
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Builder(
            builder: (context) {
              onGlass = GlassHostScope.isOnGlass(context);
              return const SizedBox(width: 100, height: 40);
            },
          ),
        ),
      ),
    );
    expect(onGlass, isFalse);
  });

  testWidgets('a Glass directly inside a Glass asserts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            child: Glass(
              shape: GlassRoundedRectangle(radius: BorderRadius.circular(28)),
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('a Glass nested a few widgets deep inside another Glass '
      'still asserts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Glass(
                  shape: GlassRoundedRectangle(
                    radius: BorderRadius.circular(12),
                  ),
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}
