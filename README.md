# Empathy Exchange

An AI-powered Flutter application designed to foster kindness and empathy in digital communication. Empathy Exchange uses OpenAI's GPT-5.2 to evaluate conversations in real-time, rewarding positive interactions through a karma system and creating a safer, more supportive online environment.

## 🌟 Features

- **AI-Powered Conversation Analysis**: Real-time evaluation of messages for empathy, kindness, and positivity using OpenAI GPT-5.2
- **Karma System**: Gamified positive reinforcement with karma points (-10 to +10) based on message quality
- **Profanity Filter**: Automatic detection and filtering of inappropriate content
- **Real-Time Chat**: Live messaging powered by Firebase Realtime Database
- **Karma History Visualization**: Interactive charts showing karma trends over time
- **User Profiles**: Customizable profiles with pictures, bios, and display names
- **Badge System**: Users can give and receive badges recognizing positive contributions
- **Cross-Platform**: Works on Web, iOS, and Android

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend Services**:
  - Firebase Authentication
  - Firebase Realtime Database
  - Cloud Firestore
  - Firebase Storage
- **AI Integration**: OpenAI GPT-5.2 API
- **Additional Libraries**:
  - Google Fonts
  - fl_chart (data visualization)
  - HTTP client for API communication

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>=3.4.4)
- [Dart SDK](https://dart.dev/get-dart) (comes with Flutter)
- [Firebase CLI](https://firebase.google.com/docs/cli) (optional, for Firebase setup)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (for Python scripts, optional)

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd empathy-exchange
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable the following services:
   - Authentication (Email/Password and Google Sign-In)
   - Realtime Database
   - Cloud Firestore
   - Storage
3. Download configuration files:
   - For Android: `google-services.json` → place in `android/app/`
   - For iOS: `GoogleService-Info.plist` → place in `ios/Runner/`
   - For Web: Add Firebase config to `lib/main.dart` (already configured)

### 4. Environment Configuration

Create a `.env` file in the root directory:

```env
FIREBASE_API_KEY=your_firebase_api_key
OPENAI_API_KEY=your_openai_api_key
```

The `.env` file is already configured in `pubspec.yaml` to be included as an asset.

### 5. OpenAI API Setup

1. Sign up for an OpenAI account at [OpenAI Platform](https://platform.openai.com/)
2. Create an API key
3. Add the key to your `.env` file

### 6. Run the Application

```bash
# For web
flutter run -d chrome

# For iOS (requires macOS and Xcode)
flutter run -d ios

# For Android (requires Android Studio/Android SDK)
flutter run -d android
```

## 📁 Project Structure

```
empathy-exchange/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   ├── screens/                  # App screens
│   │   ├── chat_screen.dart
│   │   ├── login_screen.dart
│   │   ├── profile_screen.dart
│   │   └── signup_screen.dart
│   ├── services/                 # Business logic
│   │   ├── auth_service.dart
│   │   ├── fcm_service.dart
│   │   ├── openai_service.dart
│   │   ├── profanity_check.dart
│   │   └── profile_service.dart
│   └── widgets/                  # Reusable widgets
│       ├── material.dart
│       ├── message.dart
│       ├── profile_picture_widget.dart
│       └── sidetooltip.dart
├── python/                       # Python scripts (optional)
│   ├── chat_bot.py
│   ├── requirements.txt
│   └── SETUP.md
├── android/                      # Android-specific files
├── ios/                          # iOS-specific files
├── web/                          # Web-specific files
└── pubspec.yaml                  # Flutter dependencies
```

## 🤖 How the AI Works

### Conversation Evaluation

The AI system evaluates conversations through a multi-stage process:

1. **Message Collection**: Every 5 messages (or on manual trigger), the system collects recent conversation history
2. **Context Building**: The AI receives both recent messages and an existing conversation summary to maintain context
3. **Evaluation**: Messages are analyzed for:
   - Tone and language
   - Constructiveness
   - Respectfulness
   - Overall positive or negative impact
4. **Karma Assignment**: Points are assigned from -10 (very negative) to +10 (very positive)
5. **Feedback**: Evaluation results are posted as system messages with reasoning

### Profanity Detection

A custom pattern-based profanity filter:
- Scans messages for inappropriate content
- Automatically deducts karma points
- Censors inappropriate language
- Maintains a comprehensive database of profanity patterns

## 🎯 Key Features Explained

### Karma System

- Users receive karma points based on message quality
- Points range from -10 to +10 per evaluation
- Accounts with karma below -100 are automatically terminated
- Karma history is visualized through interactive charts

### Real-Time Chat

- Powered by Firebase Realtime Database
- Supports multiple concurrent users
- Automatic AI evaluation every 5 messages
- Manual evaluation triggers for chat owners

### User Profiles

- Customizable display names and bios
- Profile picture upload
- Karma history visualization
- Badge system for recognition

## 🔒 Security & Privacy

- User authentication through Firebase
- Minimal data sent to external APIs (only necessary conversation context)
- Secure storage of API keys in environment variables
- Account termination for users with excessive negative karma

## 🤝 Contributing

This project is open source. Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

Open Source - See LICENSE file for details

## 🏆 Project Status

**Status**: Active Development (Alpha Version)  
**Platform**: Web, iOS, Android  
**Developed for**: 2025 Presidential AI Challenge

## 📞 Support

For questions or issues, please open an issue in the repository.

---

**Empathy Exchange** - Building a kinder digital world, one conversation at a time. 💙
