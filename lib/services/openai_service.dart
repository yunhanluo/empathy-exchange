import 'package:empathy_exchange/lib/firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  // System prompts
  /* static const List<Map<String, String>> systemPromptEvaluation = [
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
          This field must be called message. These should be the ONLY FIELDS INCLUDED. Or else I will be forced to create a JSON schema.
          **** or something similar indicates profanity, by the way. It is almost always bad.'''
    }
  ];
*/
  static const List<Map<String, String>> systemPromptOwnerEvaluation = [
    {
      'role': 'system',
      'content':
          '''You are an AI assistant on a project called Empathy Exchange. 
          Our mission is to guide people as they interact with each other. 
          Your specific mission is to assign points unbiasedly to people as they interact. 
          You're supposed to evaluate messages for everyone.  
          You are given a summary of the conversation so far. You are going to be given the last 10 messages in the conversation. The points given or taken away will range from -10 to 10, with -10 being a very negative interaction and 10 being
          a very positive one. Return a JSON object with an evaluations array containg a list of evaluations. Each evaluation should be JSON objects with the user's email and the points you assign them.
          For example, if the user's email is "test@test.com", the evaluation should be {"test@test.com": 10}, not {"email": "test@test.com", "points": 10}. This will cause an error. It is not okay.
          Outside of the evaluations array, include a reasoning field for your reasoning, that is, the rationale behind the way you have assigned points to users. Also include a message field with your advice, 
          a comment, or something uplifting. If there is nothing to say, return an empty string: "".
          For example, "message": "Keep it up! You're doing great!"
          Check to see that you have evaluations for ALL users in the sample of the conversation.
          DO NOT include a field called "advice." This is not a valid field.
          Also, it is highly important that you do not randomly decide to change the case of the emails in any way. For example, do not change "test@test.com" to "Test@Test.com".
          **** or something similar indicates profanity, by the way. It is almost always bad.
          Be careful about the type of the evaluations array. It must be a list of maps. For example, '"evaluations": {
        "example@example.com": 5
    },' is not a valid format. It must be a list of maps. For example, 'evaluations:[{"example@example.com": 5}]'.
     '''
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
    // String displayName = user.displayName ?? '';
    String apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'fallback-key';

    try {
      // Load chat data
      Map data = await FirebaseChatTools.load('/');
      String chatKey = data.keys.elementAt(chatId);
      String summary = '';
      if (await FirebaseChatTools.exists('$chatKey/summary')) {
        summary = (await FirebaseChatTools.load('$chatKey/summary')) as String;
      }
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
        karmaHistory = {};
        // print(chatLength);
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
      if (type == 'owner' || (chatLength > 0 && chatLength % 5 == 0)) {
        // // print("Creating summary");
        // // print("Chat length: $chatLength");
        List<MapEntry<String, dynamic>> recentEntries;
        if (type == 'message') {
          recentEntries = entries.length > 5
              ? entries.sublist(entries.length - 5)
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
        //print("Hey! Over here! Messages text: $messagesText");

        List<Map<String, String>> sysPrompt = [
          ...systemPromptSummary,
          {
            'role': 'user',
            'content':
                'The last few messages, which must be summarized:\n$messagesText. \n The summary so far: \n$summary'
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
        // print('Summary: $summaryText');

        // print('Creating evaluation');

        //String evaluateFor = type == 'owner' ? 'everyone' : email;

        List<Map<String, String>> evalPrompt = [
          ...systemPromptOwnerEvaluation,
          {
            'role': 'user',
            'content':
                'Here is the summary of the conversation so far:\n $summaryText\n Now here are the latest messages. \n $messagesText. Please evaluate all the messages.'
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
        // print('Evaluation text: $evaluationText');
        Map<String, dynamic> jsonResponse = jsonDecode(evaluationText);
        String reasoning = jsonResponse['reasoning'] ?? '';
        String message = jsonResponse['message'] ?? '';

        if (type == 'owner' || type == 'message') {
          // Convert evaluations from dynamic to properly typed List<Map<String, int>>
          List<Map<String, int>> evaluations = [];
          dynamic evaluationsRaw = jsonResponse['evaluations'];
          // print('Evaluations raw: $evaluationsRaw');
          // print('Evaluations raw type: ${evaluationsRaw.runtimeType}');
          if (evaluationsRaw is List) {
            for (var evalItem in evaluationsRaw) {
              if (evalItem is Map) {
                Map<String, int> evaluation = {};
                evalItem.forEach((key, value) {
                  String emailKey = key.toString();
                  int points = value is int
                      ? value
                      : (value is String
                          ? int.tryParse(value) ?? 0
                          : (value is double
                              ? value.toInt()
                              : int.tryParse(value.toString()) ?? 0));
                  evaluation[emailKey] = points;
                });
                evaluations.add(evaluation);
              }
            }
          }
          // print('Hi');
          // print('Evaluations: $evaluations');

          String finalMessage = '';
          for (Map<String, int> evaluation in evaluations) {
            for (MapEntry<String, int> entry in evaluation.entries) {
              String email = entry.key;
              String? uid = await FirebaseUserTools.getUidFromToken(entry.key);
              // print('Uid: $uid');
              // print('Email: $email');
              String displayName =
                  await FirebaseUserTools.load('$uid/displayName');
              // print('DisplayName: $displayName');
              int points = entry.value;
              String formattedEmail =
                  email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
              if (karmaHistory[formattedEmail] == null) {
                karmaHistory[formattedEmail] = {};
              }
              karmaHistory[formattedEmail]?[chatLength] = points;
              if (chatLength == 5 || chatLength == 10) {
                karmaHistory[formattedEmail]?[0] = 0;
              }
              await FirebaseChatTools.set(
                  '$chatKey/karmaHistory', karmaHistory);

              dynamic oldPoints = await FirebaseUserTools.load('$uid/karma');
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
              await FirebaseUserTools.set('$uid/karma', currentKarma + points);
              finalMessage +=
                  "${points.abs()} ${points == 1 ? 'point has' : 'points have'} been ${points >= 0 ? 'added' : 'deducted'} ${points >= 0 ? 'to' : 'from'} $displayName's total. (Email: $email) \n \n";
            }
          }
          // print("Final message: $finalMessage");
          await FirebaseChatTools.listPush('$chatKey/data', {
            'sender': 'system',
            'text':
                '''Our AI has evaluated the last ${type == 'owner' ? 'ten' : 'five'} messages for empathy, kindness, and positivity. \n\n $finalMessage Here is the AI's evaluation of the state of the conversation: $reasoning \n \n ${message == '' ? '' : 'The AI would like to share the following message:'} $message''',
          });
        }
        await FirebaseChatTools.set('$chatKey/summary', summaryText);
      }
    } catch (e) {
      // print('OpenAI Error: $e');
      rethrow;
    }
  }
}
