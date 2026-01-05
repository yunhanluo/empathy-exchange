// import 'package:empathy_exchange/lib/firebase.dart';
import 'package:empathy_exchange/lib/firebase.dart';
import 'package:empathy_exchange/screens/chat_screen.dart';
import 'package:empathy_exchange/widgets/material.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'services/profile_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
    options: const FirebaseOptions(
      apiKey: "AIzaSyCESD67BYe9qPr1XGiEfvm3oUsqWodvRJw",
      authDomain: "empathy-exchange-473417.firebaseapp.com",
      databaseURL:
          "https://empathy-exchange-473417-default-rtdb.firebaseio.com",
      projectId: "empathy-exchange-473417",
      storageBucket: "empathy-exchange-473417.firebasestorage.app",
      messagingSenderId: "45791923833",
      appId: "1:45791923833:web:2aba95f57c8e9dfa6b8ea8",
      measurementId: "G-WB44LX8J7K",
    ),
  );

  await dotenv.load(fileName: ".env");

  // FirebaseTools.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return materialAppInstance(context, const AuthWrapper());
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _initializeUserDocument();
  }

  Future<void> _initializeUserDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _profileService.createOrUpdateUserDocument();
        await _profileService.updateOnlineStatus(true);
      } catch (e) {
        // Handle error silently
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF667eea),
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          // Initialize user document when user signs in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeUserDocument();
          });
          return const HomePage();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await FirebaseUserTools.load(
              '${FirebaseAuth.instance.currentUser?.uid}/karma') <=
          -100) {
        if (mounted) {
          showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context2) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text("Your account has been terminated."),
                  content: const Text("Reason: Too little karma."),
                  actions: [
                    TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text("Log out"))
                  ],
                );
              });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Empathy Exchange',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF667eea),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            color: const Color(0xFF667eea),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF667eea),
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildChatSelectTab();
      case 2:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 64,
                    color: Color(0xFF667eea),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Empathy Exchange!',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF667eea),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are successfully signed in.',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatSelectTab() {
    /*return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Chat',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );*/
    return const ChatPage();
  }

  Widget _buildProfileTab() {
    return const ProfileScreen();
  }
}
