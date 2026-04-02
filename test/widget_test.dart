// This is a basic Flutter widget test.

import 'package:educational_app/core/config/theme_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:educational_app/main.dart';
import 'package:educational_app/core/config/app_config_provider.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Create a config provider for testing
    final configProvider = AppConfigProvider();
    await configProvider.initialize();

    // Initialize theme provider (singleton) and load preferences
    final themeProvider = ThemeProvider.instance;
    await themeProvider.ensureInitialized();
    // Build our app and trigger a frame.
    await tester.pumpWidget(EducationalApp(
      configProvider: configProvider,
      themeProvider: themeProvider,
    ));

    // Verify app launches without errors
    await tester.pumpAndSettle();
  });
}
