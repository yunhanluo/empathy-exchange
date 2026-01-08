import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/profile_service.dart';

class ProfilePictureWidget extends StatelessWidget {
  final String? userId;
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;

  const ProfilePictureWidget({
    super.key,
    this.userId,
    this.size = 40.0,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ProfileService profileService = ProfileService();
    final user = FirebaseAuth.instance.currentUser;
    // Prefer email over UID (email is used as key in Realtime Database)
    final identifier = userId ?? user?.email ?? user?.uid;

    if (identifier == null) {
      return _buildDefaultAvatar();
    }

    return FutureBuilder<String?>(
      future: profileService.getProfilePicture(identifier),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return _buildProfilePicture(
            profileService.base64ToImageBytes(snapshot.data!),
          );
        } else if (user?.photoURL != null && userId == null) {
          return _buildNetworkImage(user!.photoURL!);
        } else {
          return _buildDefaultAvatar();
        }
      },
    );
  }

  Widget _buildProfilePicture(Uint8List imageBytes) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: const Color(0xFF667eea),
                  width: 2,
                )
              : null,
        ),
        child: ClipOval(
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String imageUrl) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: const Color(0xFF667eea),
                  width: 2,
                )
              : null,
        ),
        child: ClipOval(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: const Color(0xFF667eea),
                  width: 2,
                )
              : null,
        ),
        child: Icon(
          Icons.person,
          size: size * 0.6,
          color: const Color(0xFF667eea),
        ),
      ),
    );
  }
}
