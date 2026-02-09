import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sip_configuration.dart';

class ConfigurationRepository {
  static const _key = 'sip_configuration';

  Future<SipConfiguration?> getConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null) return null;

    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return SipConfiguration.fromJson(json);
  }

  Future<void> saveConfiguration(SipConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  Future<void> deleteConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
