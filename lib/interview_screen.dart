import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _recognizedText = '';
  String _apiResponse = '';
  bool _isLoading = false;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  Future<void> _initializeSpeech() async {
    await _speechToText.initialize();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage(
      Config.supportedLanguages[_selectedLanguage]!,
    );
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _changeLanguage(String language) async {
    setState(() {
      _selectedLanguage = language;
    });
    await _flutterTts.setLanguage(Config.supportedLanguages[language]!);
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _recognizedText = '';
        });
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords;
            });
          },
          localeId: Config.supportedLanguages[_selectedLanguage],
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
      if (_recognizedText.isNotEmpty) {
        await _getChatGPTResponse();
      }
    }
  }

  Future<void> _getChatGPTResponse() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Config.openAiApiKey}',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a helpful assistant. Please respond in the same language as the question.',
            },
            {'role': 'user', 'content': _recognizedText},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _apiResponse = data['choices'][0]['message']['content'];
        });
        await _speakResponse();
      } else {
        setState(() {
          _apiResponse = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _apiResponse = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _speakResponse() async {
    await _flutterTts.speak(_apiResponse);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview Assistant'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language Selector
            DropdownButton<String>(
              value: _selectedLanguage,
              isExpanded: true,
              items:
                  Config.supportedLanguages.keys.map((String language) {
                    return DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _changeLanguage(newValue);
                }
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isListening ? _stopListening : _startListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isListening ? 'Stop Recording' : 'Start Recording',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recognized Question:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _recognizedText.isEmpty
                    ? 'No question recorded yet'
                    : _recognizedText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Answer:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Text(
                        _apiResponse.isEmpty ? 'No answer yet' : _apiResponse,
                        style: const TextStyle(fontSize: 16),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
