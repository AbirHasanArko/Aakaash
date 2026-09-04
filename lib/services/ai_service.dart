// lib/services/ai_service.dart
//
// Lightweight wrapper around Google Gemini Flash for generating
// weather briefings and activity suggestions.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../models/weather_models.dart';

/// The result returned by [AiService.generateBriefing].
class AiBriefing {
  /// 2–3 sentence natural-language weather summary.
  final String summary;

  /// 3–4 short suggestion chips (emoji + label).
  final List<AiSuggestion> suggestions;

  const AiBriefing({required this.summary, required this.suggestions});

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'suggestions': suggestions.map((e) => e.toJson()).toList(),
      };

  factory AiBriefing.fromJson(Map<String, dynamic> json) => AiBriefing(
        summary: json['summary'] as String? ?? '',
        suggestions: (json['suggestions'] as List?)
                ?.map((e) => AiSuggestion.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class AiSuggestion {
  final String emoji;
  final String label;
  /// Optional deep-link route inside the app.
  final String? route;

  const AiSuggestion({required this.emoji, required this.label, this.route});

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'label': label,
        'route': route,
      };

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
        emoji: json['emoji'] as String? ?? '',
        label: json['label'] as String? ?? '',
        route: json['route'] as String?,
      );
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  GenerativeModel? _model;
  // Cache: "CityName|hour" → AiBriefing
  final Map<String, AiBriefing> _cache = {};

  GenerativeModel? _getModel() {
    if (_model != null) return _model;
    final key = AppConstants.geminiApiKey;
    if (key == null) {
      if (kDebugMode) debugPrint('[AiService] No GEMINI_API_KEY provided');
      return null;
    }
    _model = GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: key,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        responseMimeType: 'application/json',
      ),
    );
    return _model;
  }

  /// Generate an AI weather briefing from current weather + forecast.
  /// Returns null on any error (no key, offline, quota, timeout).
  Future<AiBriefing?> generateBriefing(
    String cityName,
    CurrentWeather current,
    List<HourlyForecast> hourly,
  ) async {
    final model = _getModel();
    if (model == null) return null;

    // Cache key: city + current day + (hour ~/ 4)
    // This splits the day into six 4-hour blocks, drastically reducing quota usage.
    final now = DateTime.now();
    final cacheKey = '$cityName|${now.day}|${now.hour ~/ 4}';

    // 1. Check in-memory cache
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    // 2. Check persistent cache
    final prefs = await SharedPreferences.getInstance();
    final storedJson = prefs.getString('ai_cache_$cacheKey');
    if (storedJson != null) {
      try {
        final cachedBriefing = AiBriefing.fromJson(json.decode(storedJson));
        _cache[cacheKey] = cachedBriefing;
        return cachedBriefing;
      } catch (_) {}
    }

    // 3. Generate new briefing
    final context = _buildContext(cityName, current, hourly);

    try {
      final response = await model.generateContent([
        Content.text(_systemPrompt),
        Content.text(context),
      ]).timeout(const Duration(seconds: 45));

      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;

      final briefing = _parse(text);
      if (briefing != null) {
        _cache[cacheKey] = briefing;
        // Persist and clean up old keys if necessary (simple implementation ignores cleanup for now)
        prefs.setString('ai_cache_$cacheKey', json.encode(briefing.toJson()));
      }
      return briefing;
    } catch (e) {
      if (kDebugMode) debugPrint('[AiService] Error: $e');
      return null;
    }
  }

  /// Clear the in-memory cache (e.g. when the city changes).
  void clearCache() => _cache.clear();

  // ────────────────────── prompt ──────────────────────

  static const _systemPrompt = '''
You are a friendly Bangladeshi weather assistant for the app "Aakaash".
Given the current weather data and next-hours forecast, respond with JSON only:

{
  "summary": "2-3 short, conversational sentences about the weather. Mention temperature, conditions, and one practical tip. Be warm and helpful. No markdown.",
  "suggestions": [
    {"emoji": "☂️", "label": "Carry umbrella"},
    {"emoji": "🧴", "label": "Wear sunscreen"},
    {"emoji": "💧", "label": "Stay hydrated"}
  ]
}

Rules:
- summary: max 180 characters, plain text, no markdown
- suggestions: exactly 3-4 items, each label max 18 chars
- Be contextually relevant to Bangladesh (e.g. rickshaw, load-shedding, tea stall)
- If rain > 60% chance, always suggest umbrella
- If temp > 35°C, always suggest hydration
- If AQI is bad (4-5), suggest mask
- Output valid JSON only, nothing else
''';

  String _buildContext(String cityName, CurrentWeather c, List<HourlyForecast> hourly) {
    final next6 = hourly.take(6).map((h) => {
          'time': h.time.toIso8601String(),
          'temp': h.temp.round(),
          'desc': h.weatherDescription,
          'pop': (h.pop * 100).round(),
        }).toList();

    final data = {
      'city': cityName,
      'temp': c.temperature.round(),
      'feels': c.feelsLike.round(),
      'humidity': c.humidity,
      'wind_ms': c.windSpeed,
      'desc': c.weatherDescription,
      'rain_mm': c.rainLastHour ?? 0,
      'visibility_m': c.visibility,
      'next_hours': next6,
    };
    return json.encode(data);
  }

  AiBriefing? _parse(String text) {
    try {
      // Strip markdown code fences if present
      var clean = text;
      if (clean.startsWith('```')) {
        clean = clean.replaceFirst(RegExp(r'^```\w*\n?'), '');
        clean = clean.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final j = json.decode(clean.trim()) as Map<String, dynamic>;
      final summary = j['summary'] as String? ?? '';
      if (summary.isEmpty) return null;

      final rawSugg = (j['suggestions'] as List?) ?? [];
      final suggestions = rawSugg
          .take(4)
          .map((s) {
            final m = s as Map<String, dynamic>;
            return AiSuggestion(
              emoji: (m['emoji'] as String?) ?? '💡',
              label: (m['label'] as String?) ?? '',
            );
          })
          .where((s) => s.label.isNotEmpty)
          .toList();

      return AiBriefing(summary: summary, suggestions: suggestions);
    } catch (e) {
      if (kDebugMode) debugPrint('[AiService] Parse error: $e');
      return null;
    }
  }
}
