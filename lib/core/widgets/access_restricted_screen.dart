import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'glass_kit.dart';

class AccessRestrictedScreen extends StatelessWidget {
  const AccessRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FullGradientScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: GlassContainer(
              borderRadius: 28,
              opacity: 0.08,
              blur: 20,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              borderColor: Colors.redAccent.withOpacity(0.15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing icon circle
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phonelink_lock_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    "Access Restricted",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  Text(
                    "Access to this web portal is restricted to Apple devices (iPhone, iPad, and Mac) to ensure security and design consistency.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Supported Devices Box
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SUPPORTED PLATFORMS",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white38,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildDeviceRow(Icons.phone_iphone_rounded, "iPhone (iOS)"),
                        const SizedBox(height: 10),
                        _buildDeviceRow(Icons.tablet_mac_rounded, "iPad (iPadOS)"),
                        const SizedBox(height: 10),
                        _buildDeviceRow(Icons.laptop_mac_rounded, "MacBook / iMac (macOS)"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Footer message
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Please open this site from an Apple device.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceRow(IconData icon, String name) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF22D3EE)),
        const SizedBox(width: 12),
        Text(
          name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            size: 10,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
