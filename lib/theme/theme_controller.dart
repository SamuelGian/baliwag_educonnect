import 'package:flutter/material.dart';

/// App-wide dark mode toggle. Lives above the login gate (not inside
/// [AppState]) since it must be usable from the Login/Register screens too,
/// before any user is signed in.
class ThemeController extends ChangeNotifier {
  bool isDarkMode = false;

  void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }
}
