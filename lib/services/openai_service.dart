import 'package:empathy_exchange/lib/firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

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
          a string, and points, an integer. Your reasoning should be concise. Make sure that it's not too similar to the given summary.
          If possible, include a message field with your advice, a comment, or something uplifting. It is fine if there is nothing to say.
          This field must be called message. These should be the ONLY FIELDS INCLUDED. Or else I will be forced to create a JSON schema.'''
    }
  ];

  static const List<Map<String, String>> systemPromptOwnerEvaluation = [
    {
      'role': 'system',
      'content':
          '''You are an AI assistant on a project called Empathy Exchange. 
          Our mission is to guide people as they interact with each other. 
          Your specific mission is to assign points unbiasedly to people as they interact. 
          You're supposed to evaluate messages for everyone.  
          You are given a summary of the conversation so far. You are going to be given the last 10 messages in the conversation. The points given or taken away will range from -10 to 10, with -10 being a very negative interaction and 10 being
          a very positive one. Your response must be a a list of json strings with reasoning, 
          a string, and points, an integer. Your reasoning should be concise. Make sure that it's not too similar to the given summary.
          If possible, include a message field with your advice, a comment, or something uplifting. It is fine if there is nothing to say.
          This field must be called message. These should be the ONLY FIELDS INCLUDED. Or else I will be forced to create a JSON schema.'''
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
    required String type,
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

      final String summary = await FirebaseChatTools.load('$chatKey/summary');
      dynamic users = await FirebaseChatTools.load('$chatKey/tokens');
      List<String> userList = FirebaseTools.asList(users).cast<String>(); //Hmm
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

      Map<String, Map<int, int>> karmaHistory;
      try {
        dynamic karmaHistoryRaw =
            await FirebaseChatTools.load('$chatKey/karmaHistory');

        // Convert from Map<Object?, Object?> to Map<String, Map<int, int>>
        karmaHistory = {};
        if (karmaHistoryRaw is Map) {
          karmaHistoryRaw.forEach((key, value) {
            String userKey = key.toString();
            Map<int, int> userHistory = {};
            if (value is Map) {
              value.forEach((k, v) {
                int messageCount =
                    k is int ? k : int.tryParse(k.toString()) ?? 0;
                int karmaValue = v is int ? v : int.tryParse(v.toString()) ?? 0;
                userHistory[messageCount] = karmaValue;
              });
            }
            karmaHistory[userKey] = userHistory;
          });
        }
      } catch (e) {
        print('Urk!!!!!!!! Not good!');
        print('Error: $e');
        karmaHistory = {};
        print(chatLength);
        for (String user in userList) {
          karmaHistory[user.replaceAll('.', '_dot_').replaceAll('@', '_at_')] =
              {
            (chatLength - 5 > 0
                ? chatLength % 5 == 0
                    ? chatLength - 5
                    : chatLength - (chatLength % 5)
                : 0): 0
          };
        }
        await FirebaseChatTools.set('$chatKey/karmaHistory', karmaHistory);
      }

      // Only analyze if chat length is divisible by 5
      if (chatLength > 0 && chatLength % 5 == 0) {
        print("Creating summary");
        print("Chat length: $chatLength");
        List<MapEntry<String, dynamic>> recentEntries;
        if (type == 'message') {
          recentEntries = entries.length > 5
              ? entries.sublist(entries.length - 5)
              : entries;
        } else if (type == 'owner') {
          recentEntries = entries.length > 10
              ? entries.sublist(entries.length - 10)
              : entries;
        } else {
          recentEntries = entries.length > 10
              ? entries.sublist(entries.length - 10)
              : entries;
        }

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
        print('Evaluation text: $evaluationText');
        Map<String, dynamic> jsonResponse = jsonDecode(evaluationText);
        String reasoning = jsonResponse['reasoning'] ?? '';
        String message = jsonResponse['message'] ?? '';
        int points = jsonResponse['points'] ?? 0;

        // Write analysis results directly into the chat as system messages
        //   await FirebaseChatTools.listPush('$chatKey/data', {
        //   'sender': 'system',
        //    'text': 'The AI has summarized the conversation: \n "$summaryText"',
        //   }); //We might not need that.

        await FirebaseChatTools.set('$chatKey/summary', summaryText);
        String formattedEmailKey =
            email.replaceAll('.', '_dot_').replaceAll('@', '_at_');

        if (karmaHistory[formattedEmailKey] == null) {
          karmaHistory[formattedEmailKey]?[(chatLength - 5 > 0
              ? chatLength % 5 == 0
                  ? chatLength - 5
                  : chatLength - (chatLength % 5)
              : 0)] = 0;
        }
        karmaHistory[formattedEmailKey]?[chatLength] = points;

        print("Karma history: $karmaHistory");

        await FirebaseChatTools.set('$chatKey/karmaHistory', karmaHistory);

        await FirebaseChatTools.listPush('$chatKey/data', {
          'sender': 'system',
          'text':
              '''The AI has evaluated the messages for $displayName. \n ${points.abs()} ${points == 1 ? 'point has' : 'points have'} been ${points >= 0 ? 'added' : 'deducted'} ${points >= 0 ? 'to' : 'from'} $displayName's total. \n \n The AI has given the following reasoning: "$reasoning \n \n ${message == '' ? '' : 'The AI would like to share the following message:'} $message''',
        });

        dynamic oldPoints = await FirebaseUserTools.load('${user.uid}/karma');

        int currentKarma = 0;
        if (oldPoints is int) {
          currentKarma = oldPoints;
        } else if (oldPoints is String) {
          currentKarma = int.tryParse(oldPoints) ?? 0;
        } else if (oldPoints is double) {
          currentKarma = oldPoints.toInt();
        } else {
          currentKarma = int.tryParse(oldPoints.toString()) ?? 0;
        }
        await FirebaseUserTools.set('${user.uid}/karma', currentKarma + points);
      }
    } catch (e) {
      print('OpenAI Error: $e');
      rethrow;
    }
  }
}
