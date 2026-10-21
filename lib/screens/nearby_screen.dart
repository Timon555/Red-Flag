import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
import '../verdict_style.dart';
import 'check_screen.dart';
import 'history_screen.dart';
import 'red_flags_screen.dart';

/// The main screen: restaurants around the user's exact position, nearest
/// first. Tapping one checks it against the user's red flags.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.profile});

  final RedFlagProfile profile;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  static const _radii = [500, 1000, 1500, 3000, 5000];

  final _location = LocationService();
  final _api = ApiService();

  late RedFlagProfile _profile = widget.profile;
  int _radius = 1500;
  Position? _position;
  List<Restaurant>? _restaurants;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await _location.currentPosition();
      final restaurants = await _api.nearbyRestaurants(
        lat: position.latitude,
        lng: position.longitude,
        radius: _radius,
      );
      for (final r in restaurants) {
        if (r.lat != null && r.lng != null) {
          r.distanceMeters = _location.distanceBetween(
            position.latitude,
            position.longitude,
            r.lat!,
            r.lng!,
          );
        }
      }
      restaurants.sort(
        (a, b) => (a.distanceMeters ?? double.infinity).compareTo(
          b.distanceMeters ?? double.infinity,
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _restaurants = restaurants;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editFlags() async {
    final saved = await Navigator.of(context).push<RedFlagProfile>(
      MaterialPageRoute(builder: (_) => RedFlagsScreen(initial: _profile)),
    );
    if (saved != null) setState(() => _profile = saved);
  }

  void _open(Restaurant restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckScreen(restaurant: restaurant, profile: _profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, color: redFlagRed),
            SizedBox(width: 8),
            Text('Red Flag'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Verlauf',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            tooltip: 'Meine Red Flags',
            icon: Badge.count(
              count: _profile.redFlags.length + _profile.customFlags.length,
              backgroundColor: redFlagRed,
              child: const Icon(Icons.tune),
            ),
            onPressed: _editFlags,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final radius in _radii)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_formatDistance(radius.toDouble())),
                      selected: radius == _radius,
                      onSelected: _loading
                          ? null
                          : (_) {
                              setState(() => _radius = radius);
                              _load();
                            },
                    ),
                  ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    final error = _error;
    if (error != null) {
      return _Message(
        icon: Icons.location_off,
        text: error is LocationException ? error.message : describeError(error),
        action: error is LocationException && error.canOpenSettings
            ? TextButton(
                onPressed: _location.openSettings,
                child: const Text('Einstellungen öffnen'),
              )
            : null,
        onRetry: _load,
      );
    }
    final restaurants = _restaurants;
    if (restaurants == null) {
      return const _Message(
        icon: Icons.my_location,
        text: 'Wir suchen deinen Standort…',
      );
    }
    if (restaurants.isEmpty) {
      return _Message(
        icon: Icons.restaurant,
        text:
            'Keine Restaurants im Umkreis von '
            '${_formatDistance(_radius.toDouble())} gefunden.',
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: restaurants.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          if (index == 0) {
            final accuracy = _position?.accuracy;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Wähle das Restaurant, das du besuchen möchtest'
                '${accuracy != null ? ' · Standort auf ±${accuracy.round()} m genau' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          return _RestaurantTile(
            restaurant: restaurants[index - 1],
            onTap: () => _open(restaurants[index - 1]),
          );
        },
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({required this.restaurant, required this.onTap});

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final details = [
      if (r.distanceMeters != null) _formatDistance(r.distanceMeters!),
      if (r.type != null) r.type!,
      if (r.openNow == true) 'Geöffnet',
      if (r.openNow == false) 'Geschlossen',
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.restaurant),
      ),
      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        details.isEmpty ? r.address : '$details\n${r.address}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: details.isNotEmpty,
      trailing: r.rating == null
          ? const Icon(Icons.chevron_right)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    Text(r.rating!.toStringAsFixed(1)),
                  ],
                ),
                Text(
                  '(${r.ratingCount})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final Widget? action;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 8), action!],
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Nochmal versuchen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = (meters / 1000).toStringAsFixed(1);
  return '${km.endsWith('.0') ? km.substring(0, km.length - 2) : km.replaceAll('.', ',')} km';
}
