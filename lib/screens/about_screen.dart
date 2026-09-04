// lib/screens/about_screen.dart
//
// About page for Aakaash: app identity, developer info, open-source
// data attribution, and the "Powered by BDApps" credit.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore – silently fail, UI keeps responsibility for messaging
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About Aakaash')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HeaderCard(),
          const SizedBox(height: 16),
          _DeveloperCard(onOpen: _open),
          const SizedBox(height: 16),
          _DataAttributionCard(),
          const SizedBox(height: 16),
          _PoweredByBdApps(),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'v${AppConstants.appVersion}  ·  Flutter ${AppConstants.appName}',
              style: tt.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: scheme.primaryContainer,
              ),
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/logo/aakaash_logo_512.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aakaash',
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Chip(
              avatar: Icon(Icons.verified_rounded,
                  size: 16, color: scheme.onTertiaryContainer),
              label: const Text('Made for Bangladesh'),
              backgroundColor: scheme.tertiaryContainer,
              labelStyle: TextStyle(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide.none,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final Future<void> Function(String url) onOpen;
  const _DeveloperCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Developer',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 2),
                    color: scheme.surface,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Transform.scale(
                    scale: 1.2,
                    child: Image.asset(
                      'assets/brand/developer.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          AppConstants.developerName.isNotEmpty
                              ? AppConstants.developerName[0]
                              : 'A',
                          style: tt.titleLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.developerName,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Made with ❤ for Bangladesh',
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _SocialRow(
              icon: Icons.code_rounded,
              label: AppConstants.developerGithub,
              onTap: () => onOpen(AppConstants.developerGithub),
            ),
            _SocialRow(
              icon: Icons.work_rounded,
              label: AppConstants.developerLinkedin,
              onTap: () => onOpen(AppConstants.developerLinkedin),
            ),
            _SocialRow(
              icon: Icons.email_rounded,
              label: AppConstants.developerEmail,
              onTap: () => onOpen('mailto:${AppConstants.developerEmail}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                color: scheme.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }
}

class _DataAttributionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dataset_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Data Attribution',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Aakaash is built on free public data from these providers.',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            const _AttributionRow(
              title: 'Weather data',
              source: 'OpenWeather',
              url: 'https://openweathermap.org',
            ),
            const _AttributionRow(
              title: 'AI Weather Insights',
              source: 'Google Gemini 3.6 Flash',
              url: 'https://ai.google.dev',
            ),
            const _AttributionRow(
              title: 'Flood forecast',
              source: 'Open-Meteo Flood',
              url: 'https://flood-api.open-meteo.com',
            ),
            const _AttributionRow(
              title: 'Global disaster alerts',
              source: 'GDACS (OCHA / EC / WMO)',
              url: 'https://www.gdacs.org',
            ),
            const _AttributionRow(
              title: 'Earthquakes',
              source: 'USGS Earthquake Hazards Program',
              url: 'https://earthquake.usgs.gov',
            ),
            const _AttributionRow(
              title: 'Active fires',
              source: 'NASA FIRMS',
              url: 'https://firms.modaps.eosdis.nasa.gov',
            ),
            const _AttributionRow(
              title: 'Relief reports',
              source: 'ReliefWeb',
              url: 'https://reliefweb.int',
            ),
            const _AttributionRow(
              title: 'Bangladesh map',
              source: 'Hand-curated district polygons',
              url: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributionRow extends StatelessWidget {
  final String title;
  final String source;
  final String? url;
  const _AttributionRow({
    required this.title,
    required this.source,
    required this.url,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: scheme.primary, size: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  source,
                  style: tt.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (url != null)
            IconButton(
              tooltip: 'Open',
              icon: Icon(Icons.open_in_new_rounded,
                  color: scheme.onSurfaceVariant, size: 18),
              onPressed: () async {
                try {
                  await launchUrl(Uri.parse(url!),
                      mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
        ],
      ),
    );
  }
}

class _PoweredByBdApps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/brand/bdapps.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.workspace_premium_rounded,
                  color: scheme.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Powered by BDApps',
                    style: tt.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subscriptions billed to your mobile balance via '
                    'Bangladesh telecom operators.',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
