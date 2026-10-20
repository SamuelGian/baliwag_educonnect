import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BaliwagEduConnectApp());
}

class BaliwagEduConnectApp extends StatelessWidget {
  const BaliwagEduConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        Provider(create: (_) => AuthService()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          AppColors.setDark(theme.isDarkMode);
          return MaterialApp(
            title: 'Baliwag EduConnect',
            debugShowCheckedModeBanner: false,
            theme: theme.isDarkMode ? AppTheme.dark : AppTheme.light,
            // No key here on purpose — forcing a remount on every toggle
            // (via a ValueKey on isDarkMode) used to tear down and recreate
            // this entire subtree, wiping whatever screen/tab the user was
            // on. Widgets read colors through context.scheme/context.
            // appColors (Theme-dependent) or alongside one in the same
            // build, so the normal Theme change already repaints them
            // in place without losing navigation state.
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
