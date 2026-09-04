import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../services/bdapps_service.dart';
import 'notification_provider.dart';

enum SubscriptionStatus { unknown, unregistered, pending, registered, error }

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider(this._service, {NotificationProvider? notif})
      : _notif = notif;
  final BdappsService _service;
  /// Optional bridge to the notification provider. When present,
  /// subscription state changes are mirrored into SharedPreferences so
  /// the background worker can gate pushes.
  final NotificationProvider? _notif;

  /// Mirror the current subscription state into the notification
  /// provider (daily alarm + calamity / earthquake workers). Always
  /// `await`ed so the OS-side scheduling actually completes before
  /// the user navigates away — otherwise a fast back-press could
  /// race the app being killed and leave notifications silently off.
  Future<void> _syncNotif() async {
    await _notif?.syncWithSubscription(status);
  }

  SubscriptionStatus status = SubscriptionStatus.unknown;
  String? phone;
  String? lastError;
  String? subscriberId;
  String? lastOtpReference;

  /// Tracks free-tier daily usage (search count today).
  int freeSearchesUsedToday = 0;
  static const _kCountKey = 'free_search_count';
  static const _kDateKey = 'free_search_date';
  static const _kPhoneKey = 'subscribed_phone';
  static const _kSubscriberIdKey = 'subscribed_subscriber_id';

  /// Build a YYYY-MM-DD key for the local calendar day.
  static String _todayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Has the user already used their daily free quota?
  bool get freeQuotaExhausted =>
      freeSearchesUsedToday >= AppConstants.freeDailyLimit;

  int get freeRemaining =>
      (AppConstants.freeDailyLimit - freeSearchesUsedToday).clamp(0, 99);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    final savedDate = p.getString(_kDateKey);
    if (savedDate == today) {
      freeSearchesUsedToday = p.getInt(_kCountKey) ?? 0;
    } else {
      freeSearchesUsedToday = 0;
      await p.setString(_kDateKey, today);
      await p.setInt(_kCountKey, 0);
    }
    phone = p.getString(_kPhoneKey);
    subscriberId = p.getString(_kSubscriberIdKey);
    // If we have a cached subscriber id from a previous successful
    // verify, trust it and skip the network status call. AppsPro's
    // /sdk/status endpoint is unreliable for already-registered users
    // — it returns `E1951 / format invalid` for many numbers it
    // happily shows as REGISTERED on the dashboard, and we don't want
    // to clobber the registered state on every cold start.
    if (subscriberId != null && subscriberId!.isNotEmpty) {
      status = SubscriptionStatus.registered;
      notifyListeners();
      await _syncNotif();
      return;
    }
    if (phone != null) {
      status = SubscriptionStatus.pending;
      notifyListeners();
      await _syncNotif();
      await refreshStatus();
    }
    notifyListeners();
    await _syncNotif();
  }

  /// Best-effort status refresh that won't downgrade a user we know
  /// is registered. Called only from explicit user actions (opening
  /// the subscription screen, tapping Refresh). The result is
  /// published so the UI sees the latest state, but a transient API
  /// failure (rate limit, 5xx) or a spurious `E1951` from AppsPro's
  /// status endpoint won't flip the in-memory `status` away from
  /// `registered`.
  Future<void> _refreshStatusInBackground(String phone) async {
    try {
      final s = await _service.checkStatus(phone);
      if (s.isSubscribed) {
        status = SubscriptionStatus.registered;
        if (s.subscriberId.isNotEmpty) subscriberId = s.subscriberId;
      }
      // Only treat an explicit UNREGISTERED response as a downgrade —
      // and only when the cached subscriber id is empty. AppsPro's
      // status endpoint returns `E1951` for many numbers it considers
      // format-invalid, even when those numbers are actually
      // registered on the dashboard.
      else if (subscriberId == null || subscriberId!.isEmpty) {
        status = SubscriptionStatus.unregistered;
      }
      lastError = null;
    } catch (_) {
      // Swallow — keep the cached registered state until the next
      // manual refresh succeeds.
    }
    notifyListeners();
    await _syncNotif();
  }

  Future<void> incrementFreeUse() async {
    freeSearchesUsedToday += 1;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kCountKey, freeSearchesUsedToday);
    notifyListeners();
  }

  Future<bool> requestOtp(String phoneE164OrLocal) async {
    lastError = null;
    notifyListeners();
    try {
      final r = await _service.requestOtp(phoneE164OrLocal);
      if (r.success && r.referenceNo != null) {
        lastOtpReference = r.referenceNo;
        phone = _normalizeLocal(phoneE164OrLocal);
        final p = await SharedPreferences.getInstance();
        await p.setString(_kPhoneKey, phone!);
        status = SubscriptionStatus.pending;
        notifyListeners();
        await _syncNotif();
        return true;
      }
      lastError = _formatAppsproError(
        detail: r.statusDetail,
        code: r.statusCode,
        fallback: 'Could not send OTP. Try again.',
      );
      status = SubscriptionStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = _friendlyMessage(e);
      status = SubscriptionStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    if (lastOtpReference == null || phone == null) {
      lastError = 'Please request an OTP first.';
      notifyListeners();
      return false;
    }
    try {
      final r = await _service.verifyOtp(
        phoneE164OrLocal: phone!,
        referenceNo: lastOtpReference!,
        otp: otp,
      );
      if (r.success && r.isSubscribed) {
        subscriberId = r.subscriberId;
        status = SubscriptionStatus.registered;
        // Reset free quota — subscribers get unlimited.
        freeSearchesUsedToday = 0;
        final p = await SharedPreferences.getInstance();
        await p.setInt(_kCountKey, 0);
        await p.setString(_kSubscriberIdKey, subscriberId ?? '');
        notifyListeners();
        // Await the notif sync so the daily alarm + calamity/earthquake
        // workers are actually scheduled before the user navigates
        // away. Fire-and-forget here would race the OS killing the
        // app and leave notifications silently off.
        await _syncNotif();
        return true;
      }
      lastError = _formatAppsproError(
        detail: r.statusDetail,
        code: r.statusCode,
        fallback: 'Invalid OTP. Please try again.',
      );
      status = SubscriptionStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = _friendlyMessage(e);
      status = SubscriptionStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshStatus() async {
    if (phone == null) return;
    try {
      final s = await _service.checkStatus(phone!);
      if (s.isSubscribed) {
        status = SubscriptionStatus.registered;
        subscriberId = s.subscriberId;
      } else if (subscriberId == null || subscriberId!.isEmpty) {
        // Only downgrade when we have no cached id to fall back on.
        status = SubscriptionStatus.unregistered;
      }
      lastError = null;
    } catch (e) {
      lastError = _friendlyMessage(e);
    }
    notifyListeners();
    await _syncNotif();
  }

  /// User-triggered background refresh: queries AppsPro and may update
  /// [status] to `registered` if it confirms. Will NOT downgrade a
  /// user we already know is registered (AppsPro's `/sdk/status` is
  /// unreliable for already-registered numbers — it returns
  /// `E1951` even for active subscriptions).
  Future<void> refreshStatusInBackground() async {
    if (phone == null) return;
    await _refreshStatusInBackground(phone!);
  }

  Future<bool> unsubscribe() async {
    if (phone == null) return false;
    try {
      final s = await _service.unsubscribe(
        phone!,
        subscriberId: subscriberId,
      );
      final ok = s.statusCode == 'S1000' || s.statusCode == '0000';
      // AppsPro returns `E1951` ("Format of the address is invalid Or
      // User Already UnRegistered") when the user has no active
      // subscription on their side — even if our local cache still
      // shows one. Treat that as a successful reconciliation: drop the
      // stale cache and flip the UI to unregistered. Otherwise the
      // app would claim the user is subscribed forever, even though
      // AppsPro has already cancelled them.
      final alreadyUnregistered = s.statusCode == 'E1951';
      if (ok || alreadyUnregistered) {
        status = SubscriptionStatus.unregistered;
        subscriberId = null;
        final p = await SharedPreferences.getInstance();
        await p.remove(_kSubscriberIdKey);
        lastError = null;
      } else {
        // Any other error code means the request was rejected for a
        // reason we can't reconcile locally. Keep state, surface the
        // AppsPro detail.
        status = SubscriptionStatus.registered;
        lastError = _formatAppsproError(
          detail: s.statusDetail,
          code: s.statusCode,
          fallback: 'Could not cancel subscription.',
        );
      }
      notifyListeners();
      await _syncNotif();
      return ok || alreadyUnregistered;
    } catch (e) {
      lastError = _friendlyMessage(e);
      status = SubscriptionStatus.registered;
      notifyListeners();
      return false;
    }
  }

  String _normalizeLocal(String phone) {
    var s = phone.replaceAll(RegExp(r'\D'), '');
    if (s.startsWith('880') && s.length == 13) s = '0${s.substring(3)}';
    if (s.startsWith('88') && s.length == 12) s = '0${s.substring(2)}';
    if (s.length == 10 && !s.startsWith('0')) s = '0$s';
    return s;
  }

  /// Strip the "Exception: " / "FormatException: " prefix from
  /// e.toString() so the TextField error text reads as a friendly
  /// sentence rather than the raw Dart class name.
  static String _friendlyMessage(Object e) {
    final s = e.toString();
    final colon = s.indexOf(': ');
    if (colon > 0 && colon < 30) {
      final head = s.substring(0, colon);
      if (head.endsWith('Exception') || head == 'Error') {
        return s.substring(colon + 2);
      }
    }
    return s;
  }

  /// Compose a user-visible error string from an AppsPro response.
  /// AppsPro returns `status_code` like `E1929`, `E1984`, `E1951`
  /// etc. on failure. Those opaque codes are MUCH more useful when
  /// shown verbatim than buried behind "Try again".
  static String _formatAppsproError({
    required String detail,
    required String code,
    required String fallback,
  }) {
    if (detail.isNotEmpty && code.isNotEmpty) {
      return '$detail ($code)';
    }
    if (detail.isNotEmpty) return detail;
    if (code.isNotEmpty) return '$fallback ($code)';
    return fallback;
  }
}
