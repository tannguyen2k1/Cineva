import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_client.dart';

class AuthState extends ChangeNotifier {
  AuthState(this._api);

  final ApiClient _api;

  UserSession? user;
  bool booting = true;
  bool busy = false;
  String? error;

  bool get isLoggedIn => user != null;

  /// Matches web admin entry: dashboard readers (typically Admin role).
  bool get isAdmin => hasPermission('read:dashboard');

  bool hasPermission(String code) =>
      user?.permissions.contains(code) ?? false;

  Future<void> bootstrap() async {
    booting = true;
    error = null;
    notifyListeners();
    try {
      await _api.loadTokens();
      user = await _api.me();
    } catch (_) {
      user = null;
      await _api.clearTokens();
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _api.login(username: username.trim(), password: password);
      user = await _api.me();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      user = null;
      return false;
    } catch (e) {
      error = e.toString();
      user = null;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    String? fullName,
    String? email,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _api.register(
        username: username,
        password: password,
        fullName: fullName,
        email: email,
      );
      await _api.login(username: username.trim(), password: password);
      user = await _api.me();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      user = null;
      return false;
    } catch (e) {
      error = e.toString();
      user = null;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    user = null;
    await _api.clearTokens();
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      user = await _api.me();
      notifyListeners();
    } catch (_) {}
  }

  void patchUser({String? fullName, String? email, String? avatar}) {
    if (user == null) return;
    user = user!.copyWith(
      fullName: fullName,
      email: email,
      avatar: avatar,
    );
    notifyListeners();
  }
}
