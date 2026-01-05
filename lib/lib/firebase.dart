import 'dart:js_interop';

import 'package:firebase_database/firebase_database.dart';
import 'package:profanity_filter/profanity_filter.dart';

class FirebaseUserTools {
  static final DatabaseReference ref = FirebaseDatabase.instance.ref('users');

  static Future<void> save(String path, Map<String, dynamic> dict) async {
    final DatabaseReference ref2 = ref.child(path);
    await ref2.set(dict);
  }

  static Future<dynamic> load(String path) async {
    final snapshot = await ref.child(path).get();
    if (snapshot.exists) {
      return snapshot.value;
    } else {
      throw Exception("Firebase path not found: $path");
    }
  }

  static Future<bool> exists(String path) async {
    return (await ref.child(path).get()).exists;
  }

  static Future<void> update(String path, Map<String, dynamic> dict) async {
    final DatabaseReference ref2 = ref.child(path);
    ref2.update(dict);
  }

  static Future<void> listPush(String path, dynamic value) async {
    final DatabaseReference ref2 = ref.child(path);
    ref2.push().set(value);
  }

  static Future<void> set(String path, dynamic value) async {
    final DatabaseReference ref2 = ref.child(path);
    ref2.set(value);
  }

  // static void initialize() async {
  //   if (!await exists("users")) {
  //     save("users", {});
  //   }
  // }

  static Future<String?> getUidFromToken(String token) async {
    Map users = await load('/');
    for (String uid in users.keys) {
      String? testToken;
      
      // Try to load pairToken first
      try {
        testToken = await load('$uid/pairToken') as String?;
      } catch (e) {
        // If pairToken doesn't exist, try email
        try {
          testToken = await load('$uid/email') as String?;
        } catch (e2) {
          // Neither exists, skip this user
          continue;
        }
      }
      
      if (testToken == token) {
        return uid;
      }
    }

    return null;
  }
}

class FirebaseChatTools {
  static final DatabaseReference ref = FirebaseDatabase.instance.ref('chats');

  static final ProfanityFilter filter = ProfanityFilter();

  static Future<void> save(String path, Map<String, dynamic> dict) async {
    final DatabaseReference ref2 = ref.child(path);
    await ref2.set(dict);
  }

  static Future<dynamic> load(String path) async {
    final snapshot = await ref.child(path).get();
    if (snapshot.exists) {
      return snapshot.value;
    } else {
      throw Exception("Firebase path not found: $path");
    }
  }

  static Future<bool> exists(String path) async {
    return (await ref.child(path).get()).exists;
  }

  static Future<void> update(String path, Map<String, dynamic> dict) async {
    final DatabaseReference ref2 = ref.child(path);
    ref2.update(dict);
  }

  static Future<void> listPush(String path, dynamic value) async {
    final DatabaseReference ref2 = ref.child(path);
    ref2.push().set(value);
  }

  static Future<void> set(String path, dynamic value) async {
    final DatabaseReference ref2 = ref.child(path);
    ref2.set(value);
  }

  // static void initialize() async {
  //   if (!await exists("chats")) {
  //     save("chats", {});
  //   }
  // }
}

class FirebaseTools {
  static List asList(dynamic value) {
    if (value is Map) {
      return value.values.toList();
    } else if (value is JSArray) {
      return value.toDart;
    } else if (value is List) {
      return value;
    } else {
      return value as List;
    }
  }
}
