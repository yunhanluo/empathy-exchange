import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  String? _profilePictureUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final pictureUrl = await _profileService.getProfilePicture(user.uid);
        if (mounted) {
          setState(() {
            _profilePictureUrl = pictureUrl;
          });
        }
      } catch (e) {
        // Handle error silently
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
          print('Profile picture picked.');

          // Show progress for Firebase Storage upload
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Uploading to Firebase Storage...',
                style: GoogleFonts.nunito(),
              ),
              duration: const Duration(seconds: 1),
            ),
          );

          await _profileService.updateProfilePicture(imageFile);
          print('Firebase Storage upload completed.');

          if (mounted) {
            setState(() {
              _profilePictureUrl = null; // Will be reloaded from Firebase
              print('Profile picture updated successfully');
            });
            // Reload the profile picture to get the new URL
            await _loadProfilePicture();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profile picture updated!',
                  style: GoogleFonts.nunito(),
                ),
                backgroundColor: Colors.white,
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
          child: _profilePictureUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(57),
                  child: Image.network(
                    _profilePictureUrl!,
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
                      user?.displayName ?? 'User',
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
                        // TODO: Navigate to edit profile
                        _showComingSoon(context);
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
                        _showComingSoon(context);
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'Get help and contact support',
                      onTap: () {
                        // TODO: Navigate to help
                        _showComingSoon(context);
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      icon: Icons.info_outline,
                      title: 'About',
                      subtitle: 'App version and information',
                      onTap: () {
                        // TODO: Navigate to about
                        _showComingSoon(context);
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
