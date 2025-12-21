import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:empathy_exchange/widgets/material.dart';
import 'package:empathy_exchange/widgets/message.dart';
import 'package:empathy_exchange/lib/firebase.dart';
import 'package:empathy_exchange/services/openai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

int _ppage = 0;

final ProfanityFilter filter = ProfanityFilter();

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatTalkPage extends StatefulWidget {
  const _ChatTalkPage(
      // ignore: unused_element_parameter
      {super.key,
      required this.myToken,
      required this.otherToken,
      required this.chatId});

  final String myToken;
  final String otherToken;
  final int chatId;

  @override
  State<_ChatTalkPage> createState() =>
      // ignore: no_logic_in_create_state
      _ChatTalkPageState(chatId: chatId, myToken: myToken);
}

class _ChatTalkPageState extends State<_ChatTalkPage> {
  _ChatTalkPageState({required this.chatId, required this.myToken});

  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  final _scrollController = ScrollController();

  final List<Widget> _messages = <Widget>[];

  final int chatId;
  final String myToken;

  StreamSubscription<DatabaseEvent>? _subscription;
  DatabaseReference? thisRef;

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();

    _scrollController.dispose();

    _subscription?.cancel();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    () async {
      Map data = await FirebaseChatTools.load('/');
      Map chat = data.values.elementAt(chatId) as Map;
      dynamic items = chat['data'];

      String theirToken = ((chat['aToken'] == myToken
          ? chat['bToken']
          : chat['aToken']) as String);

      String emailKey =
          theirToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      String theirPfp = await FirebaseUserTools.load(
          'profilePictures/$emailKey/profilePicture');

      emailKey = myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      String myPfp = await FirebaseUserTools.load(
          'profilePictures/$emailKey/profilePicture');

      Map uData = await FirebaseUserTools.load('/');
      int theirKarma = 0;
      int myKarma = 0;
      for (Map user in uData.values) {
        if (user['pairToken'] == myToken) {
          dynamic karmaToParse = user['karma'];
          if (karmaToParse is int) {
            myKarma = karmaToParse;
          } else if (karmaToParse is String) {
            myKarma = int.parse(karmaToParse);
          }
        } else if (user['pairToken'] == theirToken) {
          dynamic karmaToParse = user['karma'];
          if (karmaToParse is int) {
            theirKarma = karmaToParse;
          } else if (karmaToParse is String) {
            theirKarma = int.parse(karmaToParse);
          }
        }
      }

      if (items is Map) {
        for (JSAny? item in items.values.take(items.values.length - 1)) {
          setState(() {
            Map message = item as Map;
            _messages.add(Message(
                message["text"],
                message["sender"] == myToken ? Sender.self : Sender.other,
                message["sender"],
                message["sender"] == "system"
                    ? "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEvElEQVR4Aeydv69MURDHH7UIBSEUqDQ0KqFRiIZo6IhEgqAQlcQ/oFMo/EiIhGg0KpGIggSVaFQqiValQsV82Lzivb1nzrnnx9yzRs7su+/Md+Y7M989m92V3Ld2yf+ZTsAFMB3/0pIL4AIYT8CY3k+AC2A8AWN6PwEugPEEjOl7PQHnZW6PxL7MjGv25Ne+Vo8CfJAR3xM7LbZjZlyzh0+2+lm9CfBURrtPbGjhAzPk/7c/oceeBOBZfjJidmDARkDtIT0JcCxhXCnYhLTloT0JsD+h/RRsQtry0J4E2J7Qfgo2IW15aE8ClO9+AhldAGMRpi4Ar+UPZEa/xVIXMcSSIzW2GX6KAmyU7q+KvRV7L3ZWbOwilhzkIie5x+aqEjc1AXgP/0Y6vSl2QKzUIhc5yQ1HqbzZeaYiAO9a+CqBT7F7srsaTkBuOOCCcxjZyNNQgMGOeEbyzGz5ZRpccMI9WFgLh7UADIBn5K4Wza7ggBNualjhaverpQA0zgDadTufiRqoZb638q6VADRM4ynt/RTwXbFLYkfF9optmBnX7OEDA1Zc0YtaqCk6oBTQQoCDUjwNy4+o9UpQvJ1k2Bfl+o7Yc7FPYt9nxjV7+MCAJYZYgUQtaqK2KHApkIUA1xKKvy7Yw2IPxX6JxS6wxBBLjti4lNpicwZxrQW4INXwUiE/1HVOEDfEchc5yBWTh9qoMQZbBNNSgG1ScewzjHco9wVfapGLnDH5qJFaY7DZmJYC0NjOiIo3C4b/bJcfRRc5ya0lpUZq1XBF/K0E2CTVnhHT1iEBfBOrtcgNh5afWqlZw2X7WwlwQipdLxZal8X5Wqz2ggOuEA+1UnMIE+XTQK0EOK4UwreVtxVMSTdccIZyajWHYqN9LQTgKB9RKnqm+Gu4NU5qpvYa3Ms5WwigfcLkPTsfoJaLanQBJ9whOq32UGyUr4UAu5VKHov/h1jrBSfcIV6t9lBslK+FAFuUSj4q/ppujVurPbu2KQjwNbuL8Qk07oUQYKsyH20ISniWW+PWas8iJ9hPAFMYtoU4AeuG+/vr4SvlvxcGDxq3Vnt2yS1OQHaRi5xgMQXoSDEXwFgsF8AFMJ6AMb2fABfAeALG9H4CXADjCRjT+wlwAYwnYEzvJ2BxBDDupFN6PwHGwrkALoDxBIzp/QS4AMYTMKb3E+ACGE/AmN5PgAtgPAFjej8BmQLkhrsAuRPMjHcBMgeYG+4C5E4wM94FyBxgbngJAbg1WMi0GkOxLXy59WnxQX8JAYIE7gxPwAUIz6e61wWoPuIwgQsQnk91rwtQfcRhgj4FCPfUldcFMJarhABrpIf/2aT98auEAOPZPdL/lqT1c8BPgLECPQiQ+32Q8YjD9D0I8CLcQtCbExtMXMrZgwCfM5rNic2gjQ/tQYCX8e2sQubErkpWY6MHAXgZeTKieWKIHRHaLiRBgHZFzWE6NWdP2xoTo+Us7u9FABrn0/YVLhQDA1aBTcPdkwBM7JY8cIdzbjvJ/T+5ESvGNXv4wAisj9WbAEz1nTxw41XugMutiDGu2cMn7n5WjwL0M92ISl2AiCHVhLgANacbkdsFiBhSTYgLUHO6EbldgIgh1YS4AMp0a7v/AAAA//9aRXhEAAAABklEQVQDALhvssEXv78aAAAAAElFTkSuQmCC"
                    : (message["sender"] == myToken ? myPfp : theirPfp),
                (message["sender"] == myToken ? theirKarma : myKarma)));
          });
        }
      } else if (items is JSArray) {
        for (JSAny? item in items.toDart.take(items.toDart.length - 1)) {
          setState(() {
            Map message = item as Map;
            _messages.add(Message(
                message["text"],
                message["sender"] == myToken ? Sender.self : Sender.other,
                message["sender"],
                message["sender"] == "system"
                    ? "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEvElEQVR4Aeydv69MURDHH7UIBSEUqDQ0KqFRiIZo6IhEgqAQlcQ/oFMo/EiIhGg0KpGIggSVaFQqiValQsV82Lzivb1nzrnnx9yzRs7su+/Md+Y7M989m92V3Ld2yf+ZTsAFMB3/0pIL4AIYT8CY3k+AC2A8AWN6PwEugPEEjOl7PQHnZW6PxL7MjGv25Ne+Vo8CfJAR3xM7LbZjZlyzh0+2+lm9CfBURrtPbGjhAzPk/7c/oceeBOBZfjJidmDARkDtIT0JcCxhXCnYhLTloT0JsD+h/RRsQtry0J4E2J7Qfgo2IW15aE8ClO9+AhldAGMRpi4Ar+UPZEa/xVIXMcSSIzW2GX6KAmyU7q+KvRV7L3ZWbOwilhzkIie5x+aqEjc1AXgP/0Y6vSl2QKzUIhc5yQ1HqbzZeaYiAO9a+CqBT7F7srsaTkBuOOCCcxjZyNNQgMGOeEbyzGz5ZRpccMI9WFgLh7UADIBn5K4Wza7ggBNualjhaverpQA0zgDadTufiRqoZb638q6VADRM4ynt/RTwXbFLYkfF9optmBnX7OEDA1Zc0YtaqCk6oBTQQoCDUjwNy4+o9UpQvJ1k2Bfl+o7Yc7FPYt9nxjV7+MCAJYZYgUQtaqK2KHApkIUA1xKKvy7Yw2IPxX6JxS6wxBBLjti4lNpicwZxrQW4INXwUiE/1HVOEDfEchc5yBWTh9qoMQZbBNNSgG1ScewzjHco9wVfapGLnDH5qJFaY7DZmJYC0NjOiIo3C4b/bJcfRRc5ya0lpUZq1XBF/K0E2CTVnhHT1iEBfBOrtcgNh5afWqlZw2X7WwlwQipdLxZal8X5Wqz2ggOuEA+1UnMIE+XTQK0EOK4UwreVtxVMSTdccIZyajWHYqN9LQTgKB9RKnqm+Gu4NU5qpvYa3Ms5WwigfcLkPTsfoJaLanQBJ9whOq32UGyUr4UAu5VKHov/h1jrBSfcIV6t9lBslK+FAFuUSj4q/ppujVurPbu2KQjwNbuL8Qk07oUQYKsyH20ISniWW+PWas8iJ9hPAFMYtoU4AeuG+/vr4SvlvxcGDxq3Vnt2yS1OQHaRi5xgMQXoSDEXwFgsF8AFMJ6AMb2fABfAeALG9H4CXADjCRjT+wlwAYwnYEzvJ2BxBDDupFN6PwHGwrkALoDxBIzp/QS4AMYTMKb3E+ACGE/AmN5PgAtgPAFjej8BmQLkhrsAuRPMjHcBMgeYG+4C5E4wM94FyBxgbngJAbg1WMi0GkOxLXy59WnxQX8JAYIE7gxPwAUIz6e61wWoPuIwgQsQnk91rwtQfcRhgj4FCPfUldcFMJarhABrpIf/2aT98auEAOPZPdL/lqT1c8BPgLECPQiQ+32Q8YjD9D0I8CLcQtCbExtMXMrZgwCfM5rNic2gjQ/tQYCX8e2sQubErkpWY6MHAXgZeTKieWKIHRHaLiRBgHZFzWE6NWdP2xoTo+Us7u9FABrn0/YVLhQDA1aBTcPdkwBM7JY8cIdzbjvJ/T+5ESvGNXv4wAisj9WbAEz1nTxw41XugMutiDGu2cMn7n5WjwL0M92ISl2AiCHVhLgANacbkdsFiBhSTYgLUHO6EbldgIgh1YS4AMp0a7v/AAAA//9aRXhEAAAABklEQVQDALhvssEXv78aAAAAAElFTkSuQmCC"
                    : (message["sender"] == myToken ? theirPfp : myPfp),
                (message["sender"] == myToken ? theirKarma : myKarma)));
          });
        }
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      setState(() {
        thisRef =
            FirebaseChatTools.ref.child('/${data.keys.elementAt(chatId)}/data');
        _subscription = thisRef?.onValue.listen((event) async {
          Map item = event.snapshot.children.last.value as Map;
          String sender = item['sender'];

          String pfp;
          int karma;

          if (sender != 'system') {
            String theirToken = ((chat['aToken'] == sender
                ? chat['aToken']
                : chat['bToken']) as String);

            final emailKey =
                theirToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
            pfp = await FirebaseUserTools.load(
                'profilePictures/$emailKey/profilePicture');

            Map uData = await FirebaseUserTools.load('/');
            karma = 0;
            for (Map user in uData.values) {
              if (user['pairToken'] == theirToken) {
                dynamic karmaToParse = user['karma'];
                if (karmaToParse is int) {
                  karma = karmaToParse;
                } else if (karmaToParse is String) {
                  karma = int.parse(karmaToParse);
                }

                break;
              }
            }
          } else {
            pfp = "";
            karma = 0;
          }

          setState(() {
            if (sender != 'system') {
              _messages.add(Message(
                  item["text"],
                  sender == myToken ? Sender.self : Sender.other,
                  sender,
                  pfp,
                  karma));
              if (sender != myToken) {
                _showNotification(item['text']);
              }
            } else if (sender == 'system') {
              _messages.add(Message(
                  item["text"],
                  Sender.other,
                  sender,
                  "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEvElEQVR4Aeydv69MURDHH7UIBSEUqDQ0KqFRiIZo6IhEgqAQlcQ/oFMo/EiIhGg0KpGIggSVaFQqiValQsV82Lzivb1nzrnnx9yzRs7su+/Md+Y7M989m92V3Ld2yf+ZTsAFMB3/0pIL4AIYT8CY3k+AC2A8AWN6PwEugPEEjOl7PQHnZW6PxL7MjGv25Ne+Vo8CfJAR3xM7LbZjZlyzh0+2+lm9CfBURrtPbGjhAzPk/7c/oceeBOBZfjJidmDARkDtIT0JcCxhXCnYhLTloT0JsD+h/RRsQtry0J4E2J7Qfgo2IW15aE8ClO9+AhldAGMRpi4Ar+UPZEa/xVIXMcSSIzW2GX6KAmyU7q+KvRV7L3ZWbOwilhzkIie5x+aqEjc1AXgP/0Y6vSl2QKzUIhc5yQ1HqbzZeaYiAO9a+CqBT7F7srsaTkBuOOCCcxjZyNNQgMGOeEbyzGz5ZRpccMI9WFgLh7UADIBn5K4Wza7ggBNualjhaverpQA0zgDadTufiRqoZb638q6VADRM4ynt/RTwXbFLYkfF9optmBnX7OEDA1Zc0YtaqCk6oBTQQoCDUjwNy4+o9UpQvJ1k2Bfl+o7Yc7FPYt9nxjV7+MCAJYZYgUQtaqK2KHApkIUA1xKKvy7Yw2IPxX6JxS6wxBBLjti4lNpicwZxrQW4INXwUiE/1HVOEDfEchc5yBWTh9qoMQZbBNNSgG1ScewzjHco9wVfapGLnDH5qJFaY7DZmJYC0NjOiIo3C4b/bJcfRRc5ya0lpUZq1XBF/K0E2CTVnhHT1iEBfBOrtcgNh5afWqlZw2X7WwlwQipdLxZal8X5Wqz2ggOuEA+1UnMIE+XTQK0EOK4UwreVtxVMSTdccIZyajWHYqN9LQTgKB9RKnqm+Gu4NU5qpvYa3Ms5WwigfcLkPTsfoJaLanQBJ9whOq32UGyUr4UAu5VKHov/h1jrBSfcIV6t9lBslK+FAFuUSj4q/ppujVurPbu2KQjwNbuL8Qk07oUQYKsyH20ISniWW+PWas8iJ9hPAFMYtoU4AeuG+/vr4SvlvxcGDxq3Vnt2yS1OQHaRi5xgMQXoSDEXwFgsF8AFMJ6AMb2fABfAeALG9H4CXADjCRjT+wlwAYwnYEzvJ2BxBDDupFN6PwHGwrkALoDxBIzp/QS4AMYTMKb3E+ACGE/AmN5PgAtgPAFjej8BmQLkhrsAuRPMjHcBMgeYG+4C5E4wM94FyBxgbngJAbg1WMi0GkOxLXy59WnxQX8JAYIE7gxPwAUIz6e61wWoPuIwgQsQnk91rwtQfcRhgj4FCPfUldcFMJarhABrpIf/2aT98auEAOPZPdL/lqT1c8BPgLECPQiQ+32Q8YjD9D0I8CLcQtCbExtMXMrZgwCfM5rNic2gjQ/tQYCX8e2sQubErkpWY6MHAXgZeTKieWKIHRHaLiRBgHZFzWE6NWdP2xoTo+Us7u9FABrn0/YVLhQDA1aBTcPdkwBM7JY8cIdzbjvJ/T+5ESvGNXv4wAisj9WbAEz1nTxw41XugMutiDGu2cMn7n5WjwL0M92ISl2AiCHVhLgANacbkdsFiBhSTYgLUHO6EbldgIgh1YS4AMp0a7v/AAAA//9aRXhEAAAABklEQVQDALhvssEXv78aAAAAAElFTkSuQmCC",
                  0));
              _showNotification(item['text']);
            }

            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          });
        });
      });
    }();
  }

  Future<void> _showNotification(String messageText) async {
    if (!kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userData = await FirebaseUserTools.load(user.uid);
      if (userData['notificationEnabled'] != true) return;
    } catch (e) {
      return;
    }

    if (html.Notification.permission == 'default') {
      await html.Notification.requestPermission();
    }
    if (html.Notification.permission == 'granted') {
      html.Notification('New Message',
          body: messageText, icon: '/icons/Icon-67.png');
    }
  }

  void _send(String v) async {
    bool hasProf = filter.hasProfanity(v);
    String value = filter.censor(v);

    // final emailKey = myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
    // String pfp = await FirebaseUserTools.load(
    //     'profilePictures/$emailKey/profilePicture');
    // dynamic karmaD = await FirebaseUserTools.load(
    //     '${FirebaseAuth.instance.currentUser?.uid}/karma');
    // int karma =
    //     karmaD is int ? karmaD : (karmaD is String ? int.parse(karmaD) : 0);

    setState(() {
      // _messages.add(Message(value, Sender.self, pfp, karma));

      _textController.clear();
      _textFocus.requestFocus();
    });

    Map data = await FirebaseChatTools.load('/');
    String name = data.keys.elementAt(chatId);
    await FirebaseChatTools.listPush('$name/data', {
      "sender": myToken,
      "text": value,
    });

    if (hasProf) {
      dynamic thing = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser?.uid}/karma');
      if (thing is int) {
        await FirebaseUserTools.set(
            '${FirebaseAuth.instance.currentUser?.uid}/karma',
            thing - filter.getAllProfanity(v).length);
      } else if (thing is String) {
        await FirebaseUserTools.set(
            '${FirebaseAuth.instance.currentUser?.uid}/karma',
            int.parse(thing) - filter.getAllProfanity(v).length);
      }
    }
  }

  Future<void> _analyzeWithAI(String message) async {
    if (message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to analyze')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final prompt =
          'Analyze this message for empathy and emotional intelligence. Provide a brief, constructive response (max 100 words): "$message"';

      final aiResponse = await OpenAIService.sendMessage(
        message: prompt,
        maxTokens: 150,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show AI response in a dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI Analysis'),
          content: Text(aiResponse),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Optionally send AI response as a system message
                _sendAIResponseAsMessage(aiResponse);
              },
              child: const Text('Share in Chat'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendAIResponseAsMessage(String aiResponse) async {
    Map data = await FirebaseChatTools.load('/');
    String name = data.keys.elementAt(chatId);
    await FirebaseChatTools.listPush('$name/data', {
      "sender": "system",
      "text": "AI Analysis: $aiResponse",
    });
  }

  @override
  Widget build(BuildContext context) {
    return appInstance(Column(children: [
      AppBar(
        leading: IconButton(
          onPressed: () {
            _ppage = 0;
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black), // Back icon
        ),
        title: const Center(child: Text("Chat")),
      ),
      Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.blueGrey.shade100,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height -
                56 -
                56 -
                6 -
                kBottomNavigationBarHeight,
            child: SafeArea(
                child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Column(
                  children: _messages,
                  // children: <Widget>[
                  //   StreamBuilder<DatabaseEvent>(stream: thisRef?.onValue, builder: (context, snapshot) {
                  //     if (snapshot.hasError) return const Message("An error occured.", Sender.other);
                  //     if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();

                  //     final dynamic data = snapshot.data!.snapshot.value;
                  //     return Message("$data", Sender.other);
                  //   }),
                  // ],
                ),
              ),
            )),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              color: Colors.lightBlue.shade100,
              height: 60,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 5),
                    width: MediaQuery.sizeOf(context).width - 130,
                    child: TextField(
                      onSubmitted: (String value) {
                        _send(value);
                      },
                      controller: _textController,
                      focusNode: _textFocus,
                      autofocus: false,
                      decoration:
                          const InputDecoration(hintText: "Say something..."),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
                    width: 50,
                    child: IconButton(
                      onPressed: () {
                        _analyzeWithAI(_textController.value.text);
                      },
                      tooltip: "Analyze with AI",
                      icon: const Icon(Icons.psychology, size: 24),
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
                    width: 60,
                    child: FloatingActionButton(
                      onPressed: () {
                        _send(_textController.value.text);
                      },
                      tooltip: "Send",
                      child: const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      )
    ]));
  }
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController uidController = TextEditingController();

  final List<Widget> _chats = <Widget>[];
  final List<Widget> _chatPages = <Widget>[];

  bool _loading = false;

  void _runOpenChat(String enteredUid) {
    if (!mounted) return;

    setState(() {
      () async {
        String myToken = await FirebaseUserTools.load(
            '${FirebaseAuth.instance.currentUser!.uid}/pairToken');

        List<String> parts = [myToken, enteredUid];
        parts.sort();
        String path = parts.join(' ');

        try {
          Map chatList = await FirebaseChatTools.load('/');
          for (JSAny? chat in chatList.values) {
            if ((chat.dartify() as Map)["fullToken"] == path) {
              if (mounted) Navigator.of(context).pop();
              return;
            }
          }

          await FirebaseChatTools.listPush('/', {
            "aToken": uidController.text,
            "bToken": myToken,
            "fullToken": path,
            "data": [
              {"text": "This chat was created.", "sender": "system"},
            ],
          });

          if (mounted) Navigator.of(context).pop();
          rebuildChats();
        } catch (e) {
          print(e);
          if (mounted) Navigator.of(context).pop();
          rebuildChats();
          return;
        }
      }();

      setState(() {});
    });
  }

  void _addChatTalkPage(String myToken, String euid) async {
    if (await FirebaseUserTools.getUidFromToken(euid) == null) {
      return;
    }

    final emailKey = myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');

    String pfp = await FirebaseUserTools.load(
        'profilePictures/$emailKey/profilePicture');

    _chatPages
        .add(_ChatTalkPage(myToken: myToken, otherToken: euid, chatId: _ppage));
    _chats.add(TextButton(
      onPressed: () {
        _ppage = _chats.length;
        Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (context) => _chatPages[_ppage - 1]));
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, // Square corners
        ),
      ),
      child: Container(
        width: double.infinity, // Make the button fill the entire width
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.memory(base64.decode(pfp.replaceAll(RegExp(r'\s'), '')),
                width: 20, height: 20, fit: BoxFit.cover),
            Text(
              "Chat ${_chats.length + 1}",
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
            const Icon(
              Icons.arrow_forward_ios, // Right arrow icon
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    ));

    setState(() {});
  }

  void rebuildChats() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    _chats.clear();
    _chatPages.clear();

    JSAny chatArray = await FirebaseChatTools.load('/');

    if (!mounted) return;

    for (JSAny? chat in (chatArray.dartify() as Map).values) {
      Map data = chat.dartify() as Map;
      String myToken = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser!.uid}/pairToken');
      if (data['aToken'] == myToken) {
        _addChatTalkPage(myToken, data["bToken"] as String);
      } else if (data['bToken'] == myToken) {
        _addChatTalkPage(myToken, data["aToken"] as String);
      }
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    rebuildChats();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(
                color: Colors.black,
                width: 3,
                style: BorderStyle.solid,
              ))),
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height -
              56 -
              kBottomNavigationBarHeight,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (BuildContext context2, int index) {
                    return _chats[index];
                  }),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            label: const Text("New Chat"),
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text("Create New Chat"),
                      content: TextField(
                        decoration: const InputDecoration(
                          hintText: "Enter other user's pairing token...",
                        ),
                        onSubmitted: (String value) async {
                          _runOpenChat(value);
                          setState(() {});
                        },
                        controller: uidController,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            _runOpenChat(uidController.text);
                            setState(() {});
                          },
                          child: const Text("Okay"),
                        ),
                      ],
                    );
                  },
                );
              });
            },
          ),
        ),
      ],
    );
  }
}
