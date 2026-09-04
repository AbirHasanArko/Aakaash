import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';

/// Full subscription flow: phone -> OTP -> success.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _otpRequested = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // If we already know the user is subscribed (cached subscriber
    // id), prefill the phone field so they can Unsubscribe from here
    // without re-entering it.
    final sub = context.read<SubscriptionProvider>();
    if (sub.phone != null) _phoneCtrl.text = sub.phone!;
    // Kick off a background status check so the screen reflects any
    // change at BDApps end. Doesn't clobber cached registered state
    // on a transient API failure.
    if (sub.phone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sub.refreshStatusInBackground();
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscribe to Aakaash')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: scheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: scheme.onPrimaryContainer, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlimited Bangladesh forecasts',
                          style: tt.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No daily cap • All 70+ cities • 5-day forecast • Premium AI insights',
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _StepHeader(
              index: 1,
              title: 'Enter your mobile number',
              subtitle:
                  'We support Robi and Cirkle.',
              active: !_otpRequested,
              done: _otpRequested,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                LengthLimitingTextInputFormatter(14),
              ],
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_rounded),
                hintText: '01XXXXXXXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                errorText: sub.lastError,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.sms_rounded),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: Text(_otpRequested ? 'Resend OTP' : 'Send OTP'),
                onPressed: _busy ? null : _sendOtp,
              ),
            ),
            const SizedBox(height: 24),
            _StepHeader(
              index: 2,
              title: 'Enter OTP',
              subtitle: 'A 6-digit code was sent to your number.',
              active: _otpRequested,
              done: sub.status == SubscriptionStatus.registered,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                hintText: '6-digit OTP',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: const Text('Verify & Subscribe'),
                onPressed: !_otpRequested || _busy ? null : _verify,
              ),
            ),
            const SizedBox(height: 20),
            if (sub.status == SubscriptionStatus.registered)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: scheme.onTertiaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You are subscribed!',
                            style: tt.titleSmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enjoy unlimited Bangladesh forecasts, all 70+ cities, '
                      '5-day + hourly forecast, premium alerts, and AI weather insights.',
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.tertiary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.fingerprint_rounded,
                              size: 14,
                              color: scheme.onTertiaryContainer),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'BDApps subscriber id: ${sub.subscriberId ?? "—"}',
                              style: tt.bodySmall?.copyWith(
                                color: scheme.onTertiaryContainer,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _cancel,
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Unsubscribe'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onTertiaryContainer,
                              side: BorderSide(
                                color: scheme.onTertiaryContainer
                                    .withValues(alpha: 0.5),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Done'),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Subscription is billed daily to your mobile account at '
              'BDT 2.00/day through your operator. Standard operator '
              'charges apply. You can cancel anytime from this screen — '
              'no USSD code or SMS reply required.',
              style: tt.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOtp() async {
    setState(() => _busy = true);
    final sub = context.read<SubscriptionProvider>();
    final ok = await sub.requestOtp(_phoneCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _otpRequested = _otpRequested || ok;
    });
    final msg = ok
        ? 'OTP sent — please check your SMS'
        : (sub.lastError?.isNotEmpty == true
            ? 'Could not send OTP — ${sub.lastError}'
            : 'Could not send OTP. Try again.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await context
        .read<SubscriptionProvider>()
        .verifyOtp(_otpCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      // Stay on this screen so the user can see the "Subscribed"
      // confirmation card (with their BDApps subscriber id and the
      // Cancel button). They tap "Done" to return to the previous
      // screen. This also gives the home screen a frame to render
      // the "Subscribed" pill in the header via Provider's
      // notifyListeners -> watch<SubscriptionProvider>.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscribed! Unlimited forecasts unlocked.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    await context.read<SubscriptionProvider>().unsubscribe();
    if (!mounted) return;
    setState(() => _busy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription cancelled.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _StepHeader extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final bool active;
  final bool done;
  const _StepHeader({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tint = done
        ? scheme.tertiary
        : active
            ? scheme.primary
            : scheme.outline;
    final onTint = done || active
        ? (done ? scheme.onTertiary : scheme.onPrimary)
        : scheme.surface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: tint,
          child: Text(
            '$index',
            style: tt.labelSmall?.copyWith(
              color: onTint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
