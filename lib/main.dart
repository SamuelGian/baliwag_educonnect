import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const BaliwagEduConnectApp());
}

class BaliwagEduConnectApp extends StatelessWidget {
  const BaliwagEduConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, app, _) {
          AppColors.setDark(app.isDarkMode);
          return MaterialApp(
            title: 'Baliwag EduConnect',
            debugShowCheckedModeBanner: false,
            theme: app.isDarkMode ? AppTheme.dark : AppTheme.light,
            // Keyed on mode so every screen remounts and re-reads the
            // now-updated AppColors values (they're plain static getters,
            // not InheritedWidget-driven, so a fresh build is required).
            home: KeyedSubtree(
              key: ValueKey(app.isDarkMode),
              child: const AppShell(),
            ),
          );
        },
      ),
    );
  }
}
