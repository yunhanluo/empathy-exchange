import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../services/profile_service.dart';
import 'package:empathy_exchange/lib/firebase.dart';
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
  int _karma = 0;
  List<Map<String, dynamic>> _badges = [];
  bool _badgesExpanded = false;
  bool _notificationEnabled = false;

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
      _loadKarma(); // Load karma
      _loadBadges(); // Load badges
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
      _profileSubscription = FirebaseUserTools.ref
          .child(path)
          .onValue
          .listen((DatabaseEvent event) {
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
      final data = await FirebaseUserTools.load(user.uid) as Map?;
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

  Future<String?> _findUidFromGiver(String giver) async {
    try {
      // First, try if giver is already a UID
      try {
        final userData = await FirebaseUserTools.load(giver) as Map?;
        if (userData != null) {
          return giver; // It's already a UID
        }
      } catch (_) {
        // Not a UID, continue to search
      }

      // Load all users to search
      final allUsers = await FirebaseUserTools.load('/') as Map?;
      if (allUsers == null) return null;

      // Search through all users
      for (String uid in allUsers.keys) {
        try {
          final userData = await FirebaseUserTools.load(uid) as Map?;
          if (userData != null) {
            // Check if email matches
            final email = userData['email'] as String?;
            if (email == giver) {
              return uid;
            }
            // Check if pairToken matches
            final pairToken = userData['pairToken'] as String?;
            if (pairToken == giver) {
              return uid;
            }
          }
        } catch (_) {
          // Continue searching
        }
      }
    } catch (e) {
      // print('Error finding UID from giver: $e');
      rethrow;
    }

    return null;
  }

  Future<void> _loadBadges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load badges from Firebase - structure: users/{uid}/badges/{badgeId}
      final badgesData =
          await FirebaseUserTools.load('${user.uid}/badges') as Map?;
      if (badgesData != null && mounted) {
        List<Map<String, dynamic>> badgesList = [];

        // If badges is a Map, convert to list
        badgesData.forEach((key, value) {
          if (value is Map) {
            badgesList.add({
              'id': key,
              'giver': value['giver'] ?? 'Badge',
              'reason': value['reason'] ?? '',
              'icon': value['icon'] ?? 'Star',
              'time': value['time'] ?? '',
              'status': value['status'] ??
                  'accepted', // Default to accepted if missing
              ...value,
            });
          }
        });

        for (var badge in badgesList) {
          final giver = badge['giver'] as String?;
          if (giver != null) {
            try {
              // Find the UID from the giver value (could be email, token, or UID)
              final giverUid = await _findUidFromGiver(giver);
              if (giverUid != null) {
                // Load the giver's data using the UID
                final giverData =
                    await FirebaseUserTools.load(giverUid) as Map?;
                if (giverData != null) {
                  final displayName = giverData['displayName'] as String?;
                  final email = giverData['email'] as String?;

                  // Store display name
                  if (displayName != null && displayName.isNotEmpty) {
                    badge['giverDisplayName'] = displayName;
                  } else {
                    // Fallback to email if displayName doesn't exist
                    badge['giverDisplayName'] = email ?? giver;
                  }

                  // Store email separately
                  badge['giverEmail'] = email ?? giver;
                } else {
                  badge['giverDisplayName'] = giver;
                  badge['giverEmail'] = giver;
                }
              } else {
                // Couldn't find UID, use giver value as-is
                badge['giverDisplayName'] = giver;
                badge['giverEmail'] = giver;
              }
            } catch (e) {
              // print('Error loading giver display name: $e');
              badge['giverDisplayName'] = giver;
              badge['giverEmail'] = giver;
            }
          } else {
            badge['giverDisplayName'] = 'Badge';
            badge['giverEmail'] = '';
          }
        }

        if (mounted) {
          setState(() {
            _badges = badgesList;
          });
        }
      }
    } catch (e) {
      // If badges don't exist yet, that's okay
      // print('Error loading badges: $e');
      rethrow;
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

  Future<void> _loadKarma() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        dynamic karmaData = await FirebaseUserTools.load('${user.uid}/karma');
        int karma = 0;
        if (karmaData is int) {
          karma = karmaData;
        } else if (karmaData is String) {
          karma = int.tryParse(karmaData) ?? 0;
        } else if (karmaData is double) {
          karma = karmaData.toInt();
        } else {
          karma = int.tryParse(karmaData.toString()) ?? 0;
        }
        if (mounted) {
          setState(() {
            _karma = karma;
          });
        }
      } catch (e) {
        // Karma might not exist yet, default to 0
        if (mounted) {
          setState(() {
            _karma = 0;
          });
        }
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

          if (mounted) {
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
          }

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
            if (mounted) {
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
    return const Icon(
      Icons.person,
      size: 60,
      color: Color(0xFF667eea),
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
                          const SizedBox(height: 16),
                          // Total Kindness Points
                          Text(
                            'Total Kindness Points:',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _karma.toString(),
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

              // Profile Options (including Badges)
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
                    // Badges Section (Collapsible)
                    if (_badges.isNotEmpty) ...[
                      _buildProfileOption(
                        icon: Icons.workspace_premium,
                        title: 'Badges',
                        subtitle: '${_badges.length} badges available',
                        onTap: () {
                          setState(() {
                            _badgesExpanded = !_badgesExpanded;
                          });
                        },
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ),
                      if (_badgesExpanded) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: _buildBadgesGrid(),
                        ),
                      ],
                      _buildDivider(),
                    ],
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
                        _showSecuritySettings(context);
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Manage your notification preferences',
                      onTap: () {
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
    Widget? trailing,
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
            trailing ??
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

  Widget _buildBadgesGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;

    if (screenWidth < 750) {
      crossAxisCount = 1;
      childAspectRatio = 2.5;
    } else if (screenWidth < 890) {
      crossAxisCount = 2;
      childAspectRatio = 2.5;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 2.0;
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) {
        final badge = _badges[index];
        // Use display name if available, otherwise fall back to giver value
        final giverDisplayName = badge['giverDisplayName'] as String? ??
            badge['giver'] as String? ??
            'Badge';
        final giverEmail = badge['giverEmail'] as String? ?? '';
        final reason = badge['reason'] as String? ?? '';
        final time = badge['time'] as String? ?? '';
        final status = badge['status'] as String? ?? 'accepted';
        final badgeId = badge['id'] as String? ?? '';
        final iconData = _getIconData(badge['icon']);

        return _buildBadgeItem(
          badgeId: badgeId,
          name: giverDisplayName,
          email: giverEmail,
          description: reason,
          icon: iconData,
          time: time,
          status: status,
        );
      },
    );
  }

  Widget _buildBadgeItem({
    required String badgeId,
    required String name,
    required String email,
    required String description,
    required IconData icon,
    required String time,
    required String status,
  }) {
    final isPending = status == 'pending';

    Widget badgeContent = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF667eea),
                ),
                const SizedBox(height: 5),
                Text(
                  'Given by: $name',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667eea),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final scrollController = ScrollController();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Scrollbar(
                          controller: scrollController,
                          thumbVisibility: true,
                          thickness: 2,
                          radius: const Radius.circular(2),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              'Reason: $description',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Timestamp: ${formatTimeStamp(time)}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isPending)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Color(0xFF667eea),
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(badgeId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Badge'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (isPending) {
      return _PendingBadgeWidget(
        badgeContent: badgeContent,
        badgeId: badgeId,
        onAccept: () => _acceptBadge(badgeId),
        onReject: () => _rejectBadge(badgeId),
      );
    }

    return badgeContent;
  }

  Future<void> _acceptBadge(String badgeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseUserTools.update('${user.uid}/badges/$badgeId', {
        'status': 'accepted',
      });
      if (mounted) {
        await _loadBadges(); // Reload badges
      }
    } catch (e) {
      // print('Error accepting badge: $e');
      rethrow;
    }
  }

  Future<void> _rejectBadge(String badgeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseUserTools.ref.child('${user.uid}/badges/$badgeId').remove();
      if (mounted) {
        await _loadBadges(); // Reload badges
      }
    } catch (e) {
      // print('Error rejecting badge: $e');
      rethrow;
    }
  }

  void _showDeleteConfirmation(String badgeId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Delete Badge'),
          content: const Text(
            'Are you sure you want to delete this badge? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteBadge(badgeId);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBadge(String badgeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseUserTools.ref.child('${user.uid}/badges/$badgeId').remove();
      if (mounted) {
        await _loadBadges(); // Reload badges
      }
    } catch (e) {
      // print('Error deleting badge: $e');
      rethrow;
    }
  }

  IconData _getIconData(dynamic iconValue) {
    if (iconValue is int) {
      // If it's stored as an integer code point
      return IconData(iconValue, fontFamily: 'MaterialIcons');
    } else if (iconValue is String) {
      // Map common icon names to IconData
      switch (iconValue.toLowerCase()) {
        case 'love':
          return Icons.favorite;
        case 'support':
          return Icons.thumb_up;
        case 'excellence':
          return Icons.star;
        case 'insight':
          return Icons.lightbulb;
        case 'joy':
          return Icons.celebration;
        case 'help':
          return Icons.handshake;
        default:
          return Icons.star;
      }
    }
    // These are all random icons. Later, we can add different types of icons the user can choose from. For different things.
    return Icons.star;
  }

  String formatTimeStamp(String timeStamp) {
    final DateTime dateTime = DateTime.parse(timeStamp);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final String month = months[dateTime.month - 1];
    final int day = dateTime.day;
    final int year = dateTime.year;

    int hour = dateTime.hour;
    final String thing = hour < 12 ? 'AM' : 'PM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$month $day, $year - $hour:$minute $thing';
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
                await FirebaseUserTools.update(user.uid, {
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

    if (context.mounted) {
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

  void _showSecuritySettings(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get account creation date
    final creationDate = user.metadata.creationTime;
    final signInMethods = user.providerData
        .map((provider) => provider.providerId == 'password'
            ? 'Email/Password'
            : provider.providerId == 'google.com'
                ? 'Google'
                : provider.providerId)
        .join(', ');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Security Settings',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF667eea),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Information
              Text(
                'Account Information',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667eea),
                ),
              ),
              const SizedBox(height: 12),
              _buildSecurityRow('Email:', user.email ?? 'No email'),
              const SizedBox(height: 8),
              _buildSecurityRow('Sign-in Method:', signInMethods),
              if (creationDate != null) ...[
                const SizedBox(height: 8),
                _buildSecurityRow(
                  'Account Created:',
                  '${creationDate.month}/${creationDate.day}/${creationDate.year}',
                ),
              ],
              const SizedBox(height: 24),
              // Change Password (only for email/password users)

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showChangePasswordDialog(context);
                  },
                  icon: const Icon(Icons.lock_outline),
                  label: Text(
                    'Change Password',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Delete Account
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteAccountDialog(context);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text(
                    'Delete Account',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
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

  Widget _buildSecurityRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Change Password',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF667eea),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
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
              final currentPassword = currentPasswordController.text;
              final newPassword = newPasswordController.text;
              final confirmPassword = confirmPasswordController.text;

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match')),
                );
                return;
              }

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password must be at least 6 characters')),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user?.email == null) return;

                // Re-authenticate with current password
                final credential = EmailAuthProvider.credential(
                  email: user!.email!,
                  password: currentPassword,
                );
                await user.reauthenticateWithCredential(credential);

                // Update password
                await user.updatePassword(newPassword);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Failed to change password: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Account',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone. All your data, chats, and profile information will be permanently deleted.',
          style: GoogleFonts.nunito(
            color: Colors.grey[800],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667eea),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                // Delete user data from Realtime Database
                try {
                  // Clear all user data
                  final ref = FirebaseUserTools.ref.child(user.uid);
                  await ref.remove();
                } catch (e) {
                  // print('Error deleting user data: $e');
                  rethrow;
                }

                // Delete Firebase Auth account
                await user.delete();

                if (context.mounted) {
                  Navigator.pop(context); // Close delete dialog
                  // User will be automatically signed out and redirected to login
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Failed to delete account: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // void _showComingSoon(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       title: Text(
  //         'Coming Soon!',
  //         style: GoogleFonts.nunito(
  //           fontWeight: FontWeight.w700,
  //           color: const Color(0xFF667eea),
  //         ),
  //       ),
  //       content: Text(
  //         'This feature is under development and will be available soon.',
  //         style: GoogleFonts.nunito(
  //           color: Colors.grey[600],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: Text(
  //             'OK',
  //             style: GoogleFonts.nunito(
  //               fontWeight: FontWeight.w600,
  //               color: const Color(0xFF667eea),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

class _PendingBadgeWidget extends StatefulWidget {
  final Widget badgeContent;
  final String badgeId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingBadgeWidget({
    required this.badgeContent,
    required this.badgeId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_PendingBadgeWidget> createState() => _PendingBadgeWidgetState();
}

class _PendingBadgeWidgetState extends State<_PendingBadgeWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          widget.badgeContent,
          if (_isHovered)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Accept button
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.check,
                            color: Colors.white, size: 20),
                        onPressed: widget.onAccept,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    // Reject button
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                        onPressed: widget.onReject,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
