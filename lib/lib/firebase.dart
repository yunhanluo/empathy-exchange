import 'dart:collection';

import 'package:firebase_database/firebase_database.dart';

class FirebaseTools {
  static final DatabaseReference ref = FirebaseDatabase.instance.ref();

  static Future<void> save(String path, Map<String, dynamic> dict) async {
    final DatabaseReference ref2 = ref.child(path);
    await ref2.set(dict);
  }

  static Future<Map<String, dynamic>> load(String path) async {
    final snapshot = await ref.child(path).get();
    if (snapshot.exists) {
      return Map<String,dynamic>.from(snapshot.value as LinkedHashMap);
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

  static void initialize() async {
    if (! await exists("chats")) {
      save("chats", {});
    }
  }
}