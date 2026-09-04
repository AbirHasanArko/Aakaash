import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
void main() async {
  try {
    final model = GenerativeModel(model: 'gemini-2.0-flash-lite', apiKey: 'DUMMY_GEMINI_API_KEY_1234567890');
    final response = await model.generateContent([Content.text('Say hi')]);
    print('Success: \');
  } catch (e) {
    print('Error: \');
  }
}
