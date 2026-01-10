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

      profanity["*" * dat[0].length] = RegExp(dat[1], multiLine: true, caseSensitive: false);
    }

    initialized = true;

    print(profanity);
    print(censor("1. sh,it!! i don't like s,!hit. ashit?"));
    print(censor("2. i don't like"));
    print("3. ${hasProfanity("sh,it!! i don't like s,!hit. ashit?")}");
    print("4. ${hasProfanity("i don't like")}");
    print("5. ${getProfanities("sh,it!! i don't like s,!hit. ashit?")}");
    print("6. ${getProfanities("i don't like")}");
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

    profanity.forEach((censored, re) {
      out = input.replaceAll(re, censored);
    });

    return out;
  }
}