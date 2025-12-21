import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OpenAIService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Call OpenAI API through Cloud Function
  /// Returns the AI response text
  /// 
  /// [message] - The message to send to OpenAI
  /// [model] - The OpenAI model to use (default: gpt-3.5-turbo)
  /// [maxTokens] - Maximum tokens in response (default: 200)
  static Future<String> sendMessage({
    required String message,
    String model = 'gpt-3.5-turbo',
    int maxTokens = 200,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      final callable = _functions.httpsCallable('openai_proxy');
      final result = await callable.call({
        'message': message,
        'model': model,
        'maxTokens': maxTokens,
      });

      final data = result.data as Map<String, dynamic>;
      return data['response'] as String;
    } catch (e) {
      print('Error calling OpenAI: $e');
      rethrow;
    }
  }

  /// Get usage information from the last call
  /// Note: This requires modifying the function to return usage data
  static Future<Map<String, dynamic>?> getUsage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Usage is returned in the sendMessage response
      // This is a placeholder for future usage tracking
      return null;
    } catch (e) {
      return null;
    }
  }
}

