import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../services/api.dart';

class AuthState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  AppUser? user;
  bool ready = false;

  Future<void> init() async {
    api.onUnauthorized = () => logout(callApi: false);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('token');
    if (saved != null) {
      api.token = saved;
      try {
        user = AppUser.fromJson(Map<String, dynamic>.from(await api.get('/auth/me')));
      } catch (_) {
        api.token = null;
        await prefs.remove('token');
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final d = await api.post('/auth/login', {'email': email, 'password': password});
    await _store(d);
  }

  Future<void> register(String name, String email, String phone, String password) async {
    final d = await api.post('/auth/register', {
      'name': name,
      'email': email,
      if (phone.isNotEmpty) 'phone': phone,
      'password': password,
    });
    await _store(d);
  }

  Future<void> _store(dynamic d) async {
    api.token = d['token'].toString();
    user = AppUser.fromJson(Map<String, dynamic>.from(d['user']));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token!);
    notifyListeners();
  }

  Future<void> logout({bool callApi = true}) async {
    if (callApi && api.token != null) {
      try {
        await api.post('/auth/logout');
      } catch (_) {}
    }
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
