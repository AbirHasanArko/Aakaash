import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import 'subscription_screen.dart';

class SkyAnalyzerScreen extends StatefulWidget {
  const SkyAnalyzerScreen({super.key});

  @override
  State<SkyAnalyzerScreen> createState() => _SkyAnalyzerScreenState();
}

class _SkyAnalyzerScreenState extends State<SkyAnalyzerScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  bool _isAnalysing = false;
  SkyAnalysisResult? _result;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final mimeType = picked.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      setState(() {
        _selectedImageBytes = bytes;
        _isAnalysing = true;
        _result = null;
        _errorMessage = null;
      });

      final result = await AiService.instance.analyzeSky(bytes, mimeType);

      if (!mounted) return;
      setState(() {
        _isAnalysing = false;
        if (result != null) {
          _result = result;
        } else {
          _errorMessage =
              'Could not analyse the sky. Please try again with a clearer photo.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalysing = false;
        _errorMessage = 'Failed to pick image. Please try again.';
      });
    }
  }

  void _clearResult() {
    setState(() {
      _selectedImageBytes = null;
      _result = null;
      _errorMessage = null;
      _isAnalysing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final isSubscribed = sub.status == SubscriptionStatus.registered;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📷', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text("Sky Analyzer"),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Text(
            'Read the Sky',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo of the sky above you. Our AI will tell you if it\'s a good time to go out, what to wear, and what to eat!',
            style: tt.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Subscription Gate
          if (!isSubscribed)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withAlpha(150),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withAlpha(80),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 48, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Unlock Sky Analyzer',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subscribe to BDApps to unlock our premium AI vision features and get instant weather and lifestyle insights from the sky.',
                    style: tt.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen()),
                      ),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('Upgrade to Premium'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Image Preview / Placeholder
            GestureDetector(
              onTap: (_selectedImageBytes == null && !_isAnalysing)
                  ? () => _pickImage(ImageSource.camera)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _selectedImageBytes == null ? 220 : 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withAlpha(80),
                    width: 2,
                  ),
                  image: _selectedImageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_selectedImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 48,
                            color: scheme.primary.withAlpha(150),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to open camera',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),

            // Gallery Option
            if (_selectedImageBytes == null && !_isAnalysing) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('Or choose from gallery'),
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),

          // Loading state
          if (_isAnalysing)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(
                    'Reading the clouds...',
                    style: tt.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          // Error state
          if (_errorMessage != null && !_isAnalysing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: tt.bodyMedium
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.tonal(
                onPressed: _clearResult,
                child: const Text('Try Again'),
              ),
            ),
          ],

          // Results
          if (_result != null && !_isAnalysing) ...[
            Row(
              children: [
                Text(
                  _result!.mood,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _result!.skyCondition,
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _SuggestionCard(
              icon: '🚶',
              title: 'Going Out',
              content: _result!.goingOut,
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 12),
            _SuggestionCard(
              icon: '👕',
              title: 'Dress Code',
              content: _result!.dress,
              color: const Color(0xFF2196F3),
            ),
            const SizedBox(height: 12),
            _SuggestionCard(
              icon: '🍛',
              title: 'Food & Mood',
              content: _result!.food,
              color: const Color(0xFFFF9800),
            ),
            if (_result!.utilities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Don\'t forget:',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _result!.utilities
                    .map(
                      (u) => Chip(
                        label: Text(u, style: tt.labelMedium),
                        backgroundColor: scheme.secondaryContainer,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _clearResult,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Scan Another Sky'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String content;
  final Color color;

  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        content,
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
