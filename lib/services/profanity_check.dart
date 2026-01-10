import 'package:empathy_exchange/lib/firebase.dart';

class ProfanityFilter {
  static Map<String, RegExp> profanity = {};
  static bool initialized = false;

  static void init() async {
    String encoded = await FirebaseExtraTools.load("profanity");
    List<String> data = encoded.split("&");

    for (String item in data) {
      String newItem = "";

      for (String char in item.split('')) {
        if (char == " ") {
          newItem += " ";
          continue;
        }

        newItem += String.fromCharCode(char.codeUnitAt(0) - 1);
      }

      List<String> dat = newItem.split("&");

      if (dat.length < 2) continue;

      profanity[dat[0]] = RegExp(dat[1], multiLine: true, caseSensitive: false);
    }

    initialized = true;
  }

  static bool hasProfanity(String input) {
    for (RegExp re in profanity.values) {
      if (re.hasMatch(input)) {
        return true;
      }
    }

    return false;
  }

  static int getProfanities(String input) {
    int counter = 0;

    for (RegExp re in profanity.values) {
      counter += re.allMatches(input).length;
    }

    return counter;
  }

  static String censor(String input) {
    String out = input;

    for (int i = 0; i < profanity.length; i++) {
      String key = profanity.keys.elementAt(i);
      out = out.replaceAll(profanity.values.elementAt(i), "*" * key.length);
    }

    return out;
  }
}