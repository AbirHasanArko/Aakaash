import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';

import '../data/bangladesh_cities.dart';
import '../models/weather_models.dart';
import '../providers/subscription_provider.dart';
import '../providers/weather_provider.dart';
import '../services/location_service.dart';
import 'subscription_screen.dart';

/// Full-screen search + location screen.
///
/// Surface colors follow the active Material 3 theme so the screen
/// reads correctly in both light and dark mode.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Search Bangladesh'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _searchBox(context),
                    const SizedBox(height: 14),
                    _locationButton(context),
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Popular cities',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _popular(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: TypeAheadField<City>(
        debounceDuration: const Duration(milliseconds: 200),
        hideOnEmpty: true,
        suggestionsCallback: (pattern) async =>
            searchCities(pattern, limit: 12),
        suggestionsBoxDecoration: SuggestionsBoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        itemBuilder: (context, c) => ListTile(
          leading: Icon(Icons.location_city_rounded, color: scheme.primary),
          title: Text(
            c.name,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${c.district} • ${c.division}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        onSuggestionSelected: (c) async {
          await _loadCity(context, c);
        },
        textFieldConfiguration: TextFieldConfiguration(
          decoration: InputDecoration(
            hintText: 'Type a Bangladesh city…',
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: scheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        noItemsFoundBuilder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No match. Try nearby districts.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _locationButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        icon: const Icon(Icons.my_location_rounded),
        label: const Text('Use my current location'),
        onPressed: () => _useLocation(context),
      ),
    );
  }

  Widget _popular(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const featured = [
      'Dhaka',
      'Chittagong',
      'Khulna',
      'Rajshahi',
      'Sylhet',
      'Barishal',
      'Rangpur',
      'Comilla',
      'Cox’s Bazar',
      'Mymensingh',
      'Gazipur',
      'Narayanganj',
    ];
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 56,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: featured.length,
      itemBuilder: (_, i) {
        final name = featured[i];
        final city = kBangladeshCities.firstWhere((c) => c.name == name);
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.onSurface,
            side: BorderSide(color: scheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => _loadCity(context, city),
          child: Row(
            children: [
              Icon(Icons.location_on_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadCity(BuildContext context, City c) async {
    final sub = context.read<SubscriptionProvider>();
    final weather = context.read<WeatherProvider>();
    final nav = Navigator.of(context, rootNavigator: true);
    if (sub.status != SubscriptionStatus.registered) {
      await sub.incrementFreeUse();
      if (sub.freeQuotaExhausted) {
        await nav.push(
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
        return;
      }
    }
    await weather.loadForCity(c);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _useLocation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sub = context.read<SubscriptionProvider>();
    final weather = context.read<WeatherProvider>();
    final nav = Navigator.of(context, rootNavigator: true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (sub.status != SubscriptionStatus.registered) {
        await sub.incrementFreeUse();
        if (sub.freeQuotaExhausted) {
          await nav.push(
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          );
          return;
        }
      }
      await weather.loadForLatLon(pos.latitude, pos.longitude);
      if (context.mounted) Navigator.of(context).pop();
    } on LocationServiceException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          action: e.permissionDenied
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => LocationService().openSettings(),
                )
              : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
