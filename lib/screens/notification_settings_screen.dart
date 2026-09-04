// lib/screens/notification_settings_screen.dart
//
// Lets the user turn on/off daily weather + natural calamity push
// notifications, pick the daily push time, and choose the radius
// for calamity alerts. Gated behind an active BDApps subscription —
// when not subscribed, the toggles are disabled and a banner invites
// the user to subscribe.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/notification_service.dart';
import '../widgets/glass_card.dart';
import 'subscription_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool? _canExact; // null = not checked yet

  @override
  void initState() {
    super.initState();
    _checkExact();
  }

  Future<void> _checkExact() async {
    final ok = await NotificationService.instance.canScheduleExactAlarms();
    if (mounted) setState(() => _canExact = ok);
  }

  Future<void> _requestExact() async {
    await NotificationService.instance.requestExactAlarmPermission();
    // Re-check after user returns from system settings.
    await _checkExact();
    // Re-arm the alarm with the (possibly newly granted) exact mode.
    if (mounted) {
      await context.read<NotificationProvider>().rescheduleDaily();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: Consumer2<NotificationProvider, SubscriptionProvider>(
        builder: (ctx, notif, sub, _) {
          final subbed =
              sub.status == SubscriptionStatus.registered;
          final theme = Theme.of(ctx);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (!subbed) _SubscribeBanner(theme: theme),
              // Exact alarm permission banner (Android 12+ only)
              if (subbed && _canExact == false)
                _ExactAlarmBanner(onFix: _requestExact),
              const SizedBox(height: 12),
              _DailySection(notif: notif, enabled: subbed),
              const SizedBox(height: 12),
              _CalamitySection(notif: notif, enabled: subbed),
              _EarthquakeSection(notif: notif, enabled: subbed),
              const SizedBox(height: 24),
              _StatusFooter(notif: notif),
            ],
          );
        },
      ),
    );
  }
}

/// Yellow-orange banner shown above the toggles when the user is not
/// subscribed. Tapping the banner routes them to the subscription
/// screen.
class _SubscribeBanner extends StatelessWidget {
  final ThemeData theme;
  const _SubscribeBanner({required this.theme});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Subscribe to BDApps to turn on push notifications.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SubscriptionScreen(),
              ),
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}

/// Warning banner shown when SCHEDULE_EXACT_ALARM is not granted.
class _ExactAlarmBanner extends StatelessWidget {
  final VoidCallback onFix;
  const _ExactAlarmBanner({required this.onFix});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(Icons.alarm_off_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Exact alarm permission not granted. '
                  'Daily notifications may arrive late.',
                  style: tt.bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: onFix,
                child: Text('Fix',
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daily weather banner — toggle + time picker + test button.
class _DailySection extends StatelessWidget {
  final NotificationProvider notif;
  final bool enabled;
  const _DailySection({required this.notif, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final s = notif.settings;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Daily weather banner',
            subtitle: 'One summary per day for your current location.',
            trailing: Icon(Icons.wb_sunny_outlined),
          ),
          SwitchListTile.adaptive(
            value: s.dailyOn,
            onChanged: enabled
                ? (v) => notif.setDaily(v)
                : null,
            title: const Text('Send daily summary'),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            enabled: enabled && s.dailyOn,
            leading: const Icon(Icons.schedule),
            title: const Text('Time'),
            subtitle: Text(_format(s.dailyTime)),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: s.dailyTime,
              );
              if (t != null) notif.setDailyTime(t);
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  enabled && s.dailyOn ? notif.testDaily : null,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Test now'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Calamity banner — toggle + radius slider + test button.
class _CalamitySection extends StatelessWidget {
  final NotificationProvider notif;
  final bool enabled;
  const _CalamitySection({required this.notif, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final s = notif.settings;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Natural calamity alerts',
            subtitle:
                'Active earthquakes, cyclones, floods, etc. within your radius.',
            trailing: Icon(Icons.warning_amber_outlined),
          ),
          SwitchListTile.adaptive(
            value: s.calamityOn,
            onChanged: enabled
                ? (v) => notif.setCalamity(v)
                : null,
            title: const Text('Send calamity alerts'),
            contentPadding: EdgeInsets.zero,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.radar, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 100,
                    max: 800,
                    divisions: 7,
                    value: s.radiusKm.clamp(100, 800).toDouble(),
                    label: '${s.radiusKm.round()} km',
                    onChanged: enabled && s.calamityOn
                        ? (v) => notif.setRadius(v)
                        : null,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${s.radiusKm.round()} km',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  enabled && s.calamityOn ? notif.testCalamity : null,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Test now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarthquakeSection extends StatelessWidget {
  final NotificationProvider notif;
  final bool enabled;
  const _EarthquakeSection({required this.notif, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final s = notif.settings;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Instant earthquake alerts',
            subtitle:
                'M3.5+ earthquakes anywhere in or near Bangladesh, with sound.',
            trailing: Icon(Icons.public),
          ),
          SwitchListTile.adaptive(
            value: s.earthquakeOn,
            onChanged: enabled
                ? (v) => notif.setEarthquake(v)
                : null,
            title: const Text('Send instant earthquake alerts'),
            subtitle: const Text(
              'Plays an alarm-style sound and checks every ~15 minutes.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enabled && s.earthquakeOn
                  ? notif.testEarthquake
                  : null,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Test now'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer showing last-run timestamp, permission hint, and
/// OS-level alarm registration status.
class _StatusFooter extends StatefulWidget {
  final NotificationProvider notif;
  const _StatusFooter({required this.notif});

  @override
  State<_StatusFooter> createState() => _StatusFooterState();
}

class _StatusFooterState extends State<_StatusFooter> {
  String _alarmStatus = 'Checking…';

  @override
  void initState() {
    super.initState();
    _checkAlarm();
  }

  Future<void> _checkAlarm() async {
    final pending =
        await NotificationService.instance.pendingDailyAlarm();
    if (!mounted) return;
    setState(() {
      if (pending == null) {
        _alarmStatus = '⚠️ Daily alarm NOT registered with OS.';
      } else {
        _alarmStatus = '✅ Daily alarm registered (id ${pending.id}).';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = widget.notif.lastRun;
    final lastText = last == null
        ? 'Background check has not run yet.'
        : 'Last checked: ${last.toLocal()}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lastText, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(_alarmStatus, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () async {
              await widget.notif.rescheduleDaily();
              await _checkAlarm();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reschedule now'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (!widget.notif.permissionGranted)
            Text(
              'Notifications are blocked at the system level. Enable them in Settings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

String _format(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}