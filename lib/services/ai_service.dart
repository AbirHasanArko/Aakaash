// lib/services/ai_service.dart
//
// Lightweight wrapper around Google Gemini Flash for generating
// weather briefings, activity suggestions, and crop disease analysis.

import 'dart:convert';
import 'dart:typed_data';

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

/// Result of a crop disease image analysis.
class CropDiseaseResult {
  final String diseaseName;
  final String confidence;
  final String description;
  final String treatment;

  const CropDiseaseResult({
    required this.diseaseName,
    required this.confidence,
    required this.description,
    required this.treatment,
  });

  factory CropDiseaseResult.fromJson(Map<String, dynamic> json) =>
      CropDiseaseResult(
        diseaseName: json['disease_name'] as String? ?? 'Unknown',
        confidence: json['confidence'] as String? ?? 'low',
        description: json['description'] as String? ?? '',
        treatment: json['treatment'] as String? ?? '',
      );
}

/// Result of a sky image analysis.
class SkyAnalysisResult {
  final String skyCondition;
  final String goingOut;
  final String dress;
  final List<String> utilities;
  final String food;
  final String mood;

  const SkyAnalysisResult({
    required this.skyCondition,
    required this.goingOut,
    required this.dress,
    required this.utilities,
    required this.food,
    required this.mood,
  });

  factory SkyAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SkyAnalysisResult(
      skyCondition: json['sky_condition'] as String? ?? 'Unknown',
      goingOut: json['going_out'] as String? ?? '',
      dress: json['dress'] as String? ?? '',
      utilities: (json['utilities'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      food: json['food'] as String? ?? '',
      mood: json['mood'] as String? ?? '🌤️',
    );
  }
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

  /// Analyse a crop image for disease detection using Gemini vision.
  /// Returns null on any error (no key, offline, quota, timeout).
  Future<CropDiseaseResult?> analyzeCropDisease(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final model = _getModel();
    if (model == null) return null;

    try {
      final content = Content.multi([
        TextPart(_cropDiseasePrompt),
        DataPart(mimeType, imageBytes),
      ]);

      final response = await model.generateContent([content])
          .timeout(const Duration(seconds: 60));

      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;

      return _parseCropResult(text);
    } catch (e) {
      if (kDebugMode) debugPrint('[AiService] Crop disease error: $e');
      return null;
    }
  }

  static const _cropDiseasePrompt = '''
You are an expert agricultural pathologist specialising in crops commonly grown in Bangladesh.
Analyse the provided image of a plant/crop and identify any visible disease or pest damage.

Respond with JSON only:

{
  "disease_name": "Name of the disease or 'Healthy' if no disease detected",
  "confidence": "high" | "medium" | "low",
  "description": "Brief 2-3 sentence description of the disease, its cause, and visible symptoms.",
  "treatment": "2-3 practical treatment suggestions appropriate for smallholder farmers in Bangladesh. Include both organic and chemical options if applicable."
}

Rules:
- If the image is not a plant/crop, set disease_name to "Not a plant image" and explain in description.
- If the plant looks healthy, set disease_name to "Healthy" with a positive description.
- Keep description under 200 characters.
- Keep treatment under 250 characters.
- Use plain text, no markdown.
- Output valid JSON only, nothing else.
''';

  CropDiseaseResult? _parseCropResult(String text) {
    try {
      var clean = text;
      if (clean.startsWith('```')) {
        clean = clean.replaceFirst(RegExp(r'^```\w*\n?'), '');
        clean = clean.replaceFirst(RegExp(r'\n?```$'), '');
      }
      final j = json.decode(clean.trim()) as Map<String, dynamic>;
      final name = j['disease_name'] as String? ?? '';
      if (name.isEmpty) return null;
      return CropDiseaseResult.fromJson(j);
    } catch (e) {
      if (kDebugMode) debugPrint('[AiService] Crop parse error: $e');
      return null;
    }
  }

  /// Analyse a sky photo for lifestyle suggestions using Gemini vision.
  /// Returns null on any error.
  Future<SkyAnalysisResult?> analyzeSky(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final model = _getModel();
    if (model == null) return null;

    try {
      final content = Content.multi([
        TextPart(_skyAnalysisPrompt),
        DataPart(mimeType, imageBytes),
      ]);

      final response = await model.generateContent([content])
          .timeout(const Duration(seconds: 60));

      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;

      return _parseSkyResult(text);
    } catch (e) {
      if (kDebugMode) debugPrint('[AiService] Sky analysis error: $e');
      return null;
    }
  }

  static const _skyAnalysisPrompt = '''
You are a friendly, witty lifestyle and weather assistant for the "Aakaash" app in Bangladesh.
Analyse the provided photo of the sky and provide lifestyle suggestions based on the visible weather conditions.

Respond with JSON only:

{
  "sky_condition": "Brief description of the sky (e.g. 'Heavy rain clouds gathering', 'Clear sunny sky')",
  "going_out": "Friendly advice on whether it's a good time to go outside.",
  "dress": "Suggestion on what to wear given the sky.",
  "utilities": ["List of 2-3 items to carry (e.g., '☂️ Umbrella', '🧴 Sunscreen', '🕶️ Sunglasses')"],
  "food": "A culturally relevant (Bangladeshi) food or drink suggestion that perfectly matches the weather mood.",
  "mood": "A single emoji that captures the vibe of the sky."
}

Rules:
- If the image is clearly not a sky or outdoor photo, set sky_condition to "Doesn't look like a sky" and make a joke about it in the going_out field.
- Keep the tone conversational and culturally relevant to Bangladesh.
- Use plain text, no markdown.
- Output valid JSON only, nothing else.
''';

  SkyAnalysisResult? _parseSkyResult(String text) {
    try {
      var clean = text;
      if (clean.startsWith('```')) {
        clean = clean.replaceFirst(RegExp(r'^```\w*\n?'), '');
        clean = clean.replaceFirst(RegExp(r'\n?```$'), '');
      }
      final j = json.decode(clean.trim()) as Map<String, dynamic>;
      final condition = j['sky_condition'] as String? ?? '';
      if (condition.isEmpty) return null;
      return SkyAnalysisResult.fromJson(j);
    } catch (e) {
      if (kDebugMode) debugPrint('[AiService] Sky parse error: $e');
      return null;
    }
  }

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
