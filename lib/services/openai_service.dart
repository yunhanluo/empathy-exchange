import 'package:empathy_exchange/lib/firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  // System prompts
  static const List<Map<String, String>> systemPromptEvaluation = [
    {
      'role': 'system',
      'content':
          '''You are an AI assistant on a project called Empathy Exchange. 
          Our mission is to guide people as they interact with each other. 
          Your specific mission is to assign points unbiasedly to people as they interact. 
          You are given a summary of the conversation so far. Taking this into account, look at the given message and assign or take away kindness points to the user 
          who has sent that message. The points given or taken away will range from -10 to 10, with -10 being a very negative interaction and 10 being
          a very positive one. Your response must be a json string with reasoning, 
          a string, and points, an integer. Your reasoning should be concise. Make sure that it's not too similar to the given summary.'''
    }
  ];

  static const List<Map<String, String>> systemPromptSummary = [
    {
      'role': 'system',
      'content': '''You are an AI assistant on a called Empathy Exchange.
           Our mission: to guide people as they interact. 
           Your specific goal is summarizing a conversation and capturing the essential nuances that have happenend. 
           What major things? Who said what? Differentiate based on the usernames. Be very brief.
           Additionally, you will be given a short summary of the conversation so far. You must add to this summary
           based on the messages you are given. Do not include any introductory phrases at the beginning, such as summary update.'''
    }
  ];

  static Future<void> analyzeMessage({
    required int chatId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated');
    }
    //Next get the user's email.
    String email = user.email ?? '';
    String displayName = user.displayName ?? '';
    String apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'fallback-key';

    try {
      // Load chat data
      Map data = await FirebaseChatTools.load('/');
      String chatKey = data.keys.elementAt(chatId);
      final String summary = await FirebaseChatTools.load('/$chatKey/summary');

      dynamic messagesSnapshot = await FirebaseChatTools.load('$chatKey/data');

      // Build messages list - convert to proper types
      List<MapEntry<String, dynamic>> entries = [];
      if (messagesSnapshot is Map) {
        entries = messagesSnapshot.entries.map((entry) {
          return MapEntry<String, dynamic>(
            entry.key.toString(),
            entry.value,
          );
        }).toList();
      }
      entries = entries.where((entry) {
        final message = entry.value as Map?;
        final sender = message?['sender'] as String?;
        return sender != 'system' && sender != 'ai';
      }).toList();

      int chatLength = entries.length;

      // Only analyze if chat length is divisible by 5
      if (chatLength > 0 && chatLength % 5 == 0) {
        print("Creating summary");
        List<MapEntry<String, dynamic>> recentEntries =
            entries.length > 5 ? entries.sublist(entries.length - 5) : entries;

        List<String> messagesList = [];
        bool userIncluded =
            false; // If the currentuser isn't in it, don't worry about it
        for (MapEntry<String, dynamic> entry in recentEntries) {
          final msgMap = entry.value as Map;
          final sender = msgMap['sender'] ?? 'Unknown';
          if (sender == email) userIncluded = true;
          final text = msgMap['text'] ?? '';
          messagesList.add('$sender: $text');
        }

        if (!userIncluded) return;

        String messagesText = messagesList.join('\n');

        List<Map<String, String>> sysPrompt = [
          ...systemPromptSummary,
          {
            'role': 'user',
            'content':
                'The last five messages, which must be summarized:\n$messagesText. \n The summary so far: \n$summary'
          }
        ];

        // Call OpenAI for summary

        final summaryResponse = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': sysPrompt,
            'max_tokens': 500,
            'temperature': 0.7,
          }),
        );

        final summaryData = jsonDecode(summaryResponse.body);
        String summaryText =
            summaryData['choices']?[0]?['message']?['content'] ?? '';
        print('Summary: $summaryText');

        print('Creating evaluation');

        // Create evaluation prompt with entire chat history (not summary)
        List<Map<String, String>> evalPrompt = [
          ...systemPromptEvaluation,
          {
            'role': 'user',
            'content':
                'Here is the summary of the conversation so far:\n $summaryText\nNow evaluate the messages for the user: $email'
          }
        ];

        // Call OpenAI for evaluation
        final evalResponse = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': evalPrompt,
            'max_tokens': 500,
            'temperature': 0.7,
            'response_format': {'type': 'json_object'},
          }),
        );

        final evalData = jsonDecode(evalResponse.body);
        String evaluationText =
            evalData['choices']?[0]?['message']?['content'] ?? '';
        print('Evaluation text (hopefully json): $evaluationText');
        Map<String, dynamic> jsonResponse = jsonDecode(evaluationText);
        String reasoning = jsonResponse['reasoning'] ?? '';
        int points = jsonResponse['points'] ?? 0;

        // Write analysis results directly into the chat as system messages
        await FirebaseChatTools.listPush('$chatKey/data', {
          'sender': 'system',
          'text': 'The AI has summarized the conversation: \n "$summaryText"',
        });

        await FirebaseChatTools.listPush('$chatKey/data', {
          'sender': 'system',
          'text':
              '''The AI has evaluated the messages for the user $displayName: \n $points points have been ${points > 0 ? 'added' : 'deducted'} 
              to the user $displayName's total. \n The AI has given the following reasoning: "$reasoning"''',
        });

        await FirebaseChatTools.set('$chatKey/summary', summaryText);

        print('Analysis written directly to chat $chatKey/data');
      }
    } catch (e) {
      print('OpenAI Error: $e');
      rethrow;
    }
  }
}
