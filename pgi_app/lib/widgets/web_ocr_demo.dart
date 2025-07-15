import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class WebOCRDemo extends StatelessWidget {
  const WebOCRDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.web,
            color: Colors.blue,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Web Platform Detected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'OCR functionality is running in demo mode on web. '
            'For full functionality, use on mobile devices or deploy with server-side OCR.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
