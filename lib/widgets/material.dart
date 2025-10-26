import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

MaterialApp materialAppInstance(BuildContext context, Widget home) {
  return MaterialApp(
    title: 'Empathy Exchange',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF667eea),
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      useMaterial3: true,
    ),
    home: home,
    debugShowCheckedModeBanner: false,
  );
}

Scaffold appInstance(Widget body) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Empathy Exchange'),
      backgroundColor: Colors.white,
      foregroundColor: const Color((0xFF667eea)),
    ),
    body: Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667eea),
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
        useMaterial3: true,
      ),
      child: body,
    ),
  );
}
