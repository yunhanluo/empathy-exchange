import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../services/profile_service.dart';
import '../lib/firebase.dart';
import 'dart:html' as html;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  String? _profilePictureUrl;
  bool _isLoading = false;
  String? _pairToken;
  String? _bio;
  String? _displayName;

  StreamSubscription<DatabaseEvent>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    // Wait for widget to be fully built, then set up listener and load initial picture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupProfilePictureListener();
      _loadProfilePicture(); // Load initial profile picture if it exists
      _loadPairToken(); // Load pair token
      _loadBio(); // Load bio if it exists
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _bioController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _setupProfilePictureListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // _setupProfilePictureListener: Setting up Realtime Database listener for email: ${user.email}');

      // Use email as key for Realtime Database path
      final emailKey =
          user.email!.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      final path = 'profilePictures/$emailKey';

      // Listen to Realtime Database for profile picture updates
      _profileSubscription =
          FirebaseUserTools.ref.child(path).onValue.listen((DatabaseEvent event) {
        if (mounted && event.snapshot.exists) {
          final data = event.snapshot.value;
          if (data != null) {
            final dataMap = Map<dynamic, dynamic>.from(data as Map);
            final pictureBase64 = dataMap['profilePicture'] as String?;

            // Profile picture updated from Realtime Database: ${pictureBase64 != null ? "exists (${pictureBase64.length} chars)" : "null"}');
            setState(() {
              _profilePictureUrl = pictureBase64;
            });
          }
        }
      });
    }
  }

  Future<void> _loadProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // _loadProfilePicture: Loading profile picture for user ${user.uid}');
        // Use email if available (faster - goes directly to Realtime Database)
        // Otherwise use UID (will lookup email from Firestore first)
        final identifier = user.email ?? user.uid;
        final pictureBase64 =
            await _profileService.getProfilePicture(identifier);
        if (mounted) {
          setState(() {
            _profilePictureUrl = pictureBase64;
            //🔥 _loadProfilePicture: Updated state with picture data');
          });
        }
      } catch (e) {
        //🔥 _loadProfilePicture: ERROR - $e');
        // Retry after a short delay in case document is still being created
        await Future.delayed(const Duration(seconds: 2));
        try {
          final identifier = user.email ?? user.uid;
          final pictureBase64 =
              await _profileService.getProfilePicture(identifier);
          if (mounted && pictureBase64 != null) {
            setState(() {
              _profilePictureUrl = pictureBase64;

              // _loadProfilePicture: Retry successful - loaded picture');
            });
          }
        } catch (retryError) {
          //🔥 _loadProfilePicture: Retry also failed - $retryError');
        }
      }
    }
  }

  Future<void> _loadBio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final data = await FirebaseTools.load(user.uid) as Map?;
      if (data != null && mounted) {
        setState(() {
          _bio = data['bio'] as String?;
          _displayName = data['displayName'] as String? ?? user.displayName;
        });
      } else if (mounted) {
        setState(() {
          _displayName = user.displayName;
        });
      }
    } catch (_) {
      // Use auth display name as fallback
      if (mounted) {
        setState(() {
          _displayName = user.displayName;
        });
      }
    }
  }

  Future<void> _loadPairToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final pairToken =
            await FirebaseUserTools.load('${user.uid}/pairToken') as String;
        if (mounted) {
          setState(() {
            _pairToken = pairToken;
          });
        }
      } catch (e) {
        //Error loading pair token: $e');
        // Token might not exist yet, that's okay
      }
    }
  }

  Future<void> _pickAndUpdateProfilePicture() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Show image source selection
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667eea),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!kIsWeb) // Only show camera option on mobile
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: kIsWeb ? 'Choose Image' : 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? imageFile =
            await _profileService.pickImage(source: source);
        if (imageFile != null) {
          //Profile picture picked.');

          // Show progress for Firestore upload
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Uploading to Firestore...',
                style: GoogleFonts.nunito(),
              ),
              duration: const Duration(seconds: 1),
            ),
          );

          await _profileService.updateProfilePicture(imageFile);
          //Profile picture upload to Realtime Database completed.');

          if (mounted) {
            // Small delay to ensure Realtime Database write completes
            await Future.delayed(const Duration(milliseconds: 500));

            setState(() {
              _profilePictureUrl = null; // Clear to force reload
              //Profile picture updated successfully, reloading...');
            });
            // Reload the profile picture from Realtime Database
            await _loadProfilePicture();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profile picture updated!',
                  style: GoogleFonts.nunito(),
                ),
                backgroundColor: Colors.blue,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile picture: ${e.toString()}',
              style: GoogleFonts.nunito(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF667eea).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF667eea),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667eea),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    final user = FirebaseAuth.instance.currentUser;

    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(60),
            border: Border.all(
              color: const Color(0xFF667eea),
              width: 2,
            ),
          ),
          child: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(57),
                  child: Image.memory(
                    _profileService.base64ToImageBytes(_profilePictureUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar(user);
                    },
                  ),
                )
              : _buildDefaultAvatar(user),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isLoading ? null : _pickAndUpdateProfilePicture,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(User? user) {
    return Icon(
      Icons.person,
      size: 60,
      color: const Color(0xFF667eea),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF667eea),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Remove back button since this is a tab
      ),
      body: Container(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Profile Header Card
              Container(
                width: double.infinity,
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
                    // Profile Avatar with Edit Button
                    _buildProfilePicture(),
                    const SizedBox(height: 24),

                    // User Name
                    Text(
                      _displayName ?? user?.displayName ?? 'User',
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF667eea),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // User Email
                    Text(
                      user?.email ?? 'No email',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_bio?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _bio!,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Pair Token
                    if (_pairToken != null)
                      Column(
                        children: [
                          Text(
                            'Pairing Token:',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _pairToken!,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              color: const Color(0xFF667eea),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Profile Options
              Container(
                width: double.infinity,
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
                    _buildProfileOption(
                      icon: Icons.person_outline,
                      title: 'Edit Profile',
                      subtitle: 'Update your personal information',
                      onTap: () {
                        _editProfile(context);
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      icon: Icons.security_outlined,
                      title: 'Security',
                      subtitle: 'Password and security settings',
                      onTap: () {
                        // TODO: Navigate to security settings
                        _showComingSoon(context);
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Manage your notification preferences',
                      onTap: () {
                        // TODO: Navigate to notification settings
                        _showNotificationSettings(context);
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'Get help and contact support',
                      onTap: () {
                        _showHelpAndSupport(context);
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      icon: Icons.info_outline,
                      title: 'About',
                      subtitle: 'App version and information',
                      onTap: () {
                        _showAboutApp(context);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(
                    'Sign Out',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF667eea),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: Colors.grey[200],
    );
  }

  Widget _buildSupportRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  bool _notificationEnabled = false;

  void _editProfile(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _bioController.text = _bio ?? '';
    _displayNameController.text = _displayName ?? user.displayName ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Display Name',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _displayNameController,
                maxLength: 50,
                decoration: const InputDecoration(
                  hintText: 'Enter your display name',
                  border: OutlineInputBorder(),
                ),
                buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) {
                  return Text(
                    '$currentLength/$maxLength',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Bio',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                maxLines: 5,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Tell people a little about yourself',
                  border: OutlineInputBorder(),
                ),
                buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) {
                  return Text(
                    '$currentLength/$maxLength',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newBio = _bioController.text.trim();
              final newDisplayName = _displayNameController.text.trim();
              try {
                await FirebaseTools.update(user.uid, {
                  'bio': newBio,
                  'displayName': newDisplayName,
                });
                if (mounted) {
                  setState(() {
                    _bio = newBio.isEmpty ? null : newBio;
                    _displayName =
                        newDisplayName.isEmpty ? null : newDisplayName;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update profile: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userData = await FirebaseUserTools.load(user.uid);
      _notificationEnabled = userData['notificationEnabled'] ?? false;
    } catch (e) {
      _notificationEnabled = false;
    }
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: SwitchListTile(
            title: const Text('Enable Notifications'),
            value: _notificationEnabled,
            onChanged: (value) async {
              setDialogState(() {
                _notificationEnabled = value;
              });
              // Save to Firebase
              await FirebaseUserTools.update(user.uid, {
                'notificationEnabled': value,
              });
              // Request browser permission if enabling
              if (value && kIsWeb) {
                await html.Notification.requestPermission();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpAndSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Help & Support',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF667eea),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSupportRow('Email:', 'empathy@kindness.com'),
            const SizedBox(height: 12),
            _buildSupportRow('Website:',
                'https://www.ai.gov/initiatives/presidential-challenge'),
            const SizedBox(height: 12),
            _buildSupportRow('Phone:', '+1 (630)-393-3930'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667eea),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Information About the App',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF667eea),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSupportRow('Version:', 'Alpha'),
            const SizedBox(height: 24),
            // Story section with better alignment
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Story:',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Empathy Exchange was created in 2025 for the Presidential AI Challenge. It aims to provide a platform for safe, constructive, AI-guided conversations. Use it for good, not evil.\n\n'
                  'Its goal is to create a platform for effective collaboration guided by AI.\n'
                  'Users chat with each other.\n'
                  'However, our AI is there to help the conversation stay on track.\n'
                  'Empathy Exchange is 100% free to use and open source.\n'
                  'Enjoy connecting with empathy.',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667eea),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Coming Soon!',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF667eea),
          ),
        ),
        content: Text(
          'This feature is under development and will be available soon.',
          style: GoogleFonts.nunito(
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667eea),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
