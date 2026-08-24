import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/generation_progress.dart';

abstract interface class GenerationProgressRepository {
  Future<GenerationProgress?> load(String requestId);

  Future<void> save(GenerationProgress progress);

  Future<void> updateStep(String requestId, int stepIndex);

  Future<void> remove(String requestId);
}

class SharedPreferencesGenerationProgressRepository
    implements GenerationProgressRepository {
  const SharedPreferencesGenerationProgressRepository();

  static const _storageKey = 'i2v_generation_progress_v1';

  @override
  Future<GenerationProgress?> load(String requestId) async {
    final jobs = await _readJobs();
    final value = jobs[requestId];
    if (value is! Map) return null;
    return GenerationProgress.fromJson(Map<String, dynamic>.from(value));
  }

  @override
  Future<void> save(GenerationProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    final jobs = await _readJobs(preferences);
    jobs[progress.requestId] = progress.toJson();
    await preferences.setString(_storageKey, jsonEncode(jobs));
  }

  @override
  Future<void> updateStep(String requestId, int stepIndex) async {
    final progress = await load(requestId);
    if (progress == null || progress.savedStepIndex == stepIndex) return;
    await save(progress.copyWith(savedStepIndex: stepIndex));
  }

  @override
  Future<void> remove(String requestId) async {
    final preferences = await SharedPreferences.getInstance();
    final jobs = await _readJobs(preferences);
    if (jobs.remove(requestId) == null) return;
    if (jobs.isEmpty) {
      await preferences.remove(_storageKey);
      return;
    }
    await preferences.setString(_storageKey, jsonEncode(jobs));
  }

  Future<Map<String, dynamic>> _readJobs([
    SharedPreferences? preferences,
  ]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
