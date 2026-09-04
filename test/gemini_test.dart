import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  test('gemini test', () async {
    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: 'DUMMY_GEMINI_API_KEY_1234567890',
    );
    try {
      final response = await model.generateContent([Content.text('Say hi')]).timeout(const Duration(seconds: 30));
      print('Response: ${response.text}');
    } catch (e) {
      print('Error: $e');
    }
  });
}
