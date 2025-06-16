import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  static const Map<String, String> supportedLanguages = {
    'English': 'en-US',
    'Arabic': 'ar-SA',
    'French': 'fr-FR',
  };
}
