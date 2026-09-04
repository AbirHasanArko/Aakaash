import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  test('gemini full test', () async {
    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: 'DUMMY_GEMINI_API_KEY_1234567890',
      generationConfig: GenerationConfig(
        temperature: 0.7,
        responseMimeType: 'application/json',
      ),
    );

    const _systemPrompt = '''
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

    final contextData = {
      'city': 'Dhaka',
      'temp': 32,
      'feels': 36,
      'humidity': 70,
      'wind_ms': 2.5,
      'desc': 'scattered clouds',
      'rain_mm': 0,
      'visibility_m': 10000,
      'next_hours': [],
    };

    try {
      final response = await model.generateContent([
        Content.text(_systemPrompt),
        Content.text(json.encode(contextData)),
      ]).timeout(const Duration(seconds: 45));

      print('Raw Response: ${response.text}');

      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        print('Empty response');
        return;
      }

      var clean = text;
      if (clean.startsWith('```')) {
        clean = clean.replaceFirst(RegExp(r'^```\w*\n?'), '');
        clean = clean.replaceFirst(RegExp(r'\n?```$'), '');
      }

      print('Clean Response: $clean');
      final j = json.decode(clean.trim()) as Map<String, dynamic>;
      print('Parsed JSON: $j');

    } catch (e) {
      print('Error during test: $e');
    }
  });
}
