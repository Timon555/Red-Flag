import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/profile_service.dart';
import '../verdict_style.dart';

/// Checks one restaurant's Google reviews against the user's red flags and
/// shows the verdict, or shows a [result] from the history as it was.
class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key, this.restaurant, this.profile, this.result})
    : assert(result != null || (restaurant != null && profile != null));

  final Restaurant? restaurant;
  final RedFlagProfile? profile;
  final CheckResult? result;

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  Future<CheckResult>? _check;

  @override
  void initState() {
    super.initState();
    _check = widget.result != null ? Future.value(widget.result!) : _run();
  }

  Future<CheckResult> _run() => ApiService().checkRestaurant(
    placeId: widget.restaurant!.id,
    redFlags: widget.profile!.redFlags,
    customFlags: widget.profile!.customFlags,
  );

  @override
  Widget build(BuildContext context) {
    final name = widget.result?.name ?? widget.restaurant!.name;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FutureBuilder<CheckResult>(
        future: _check,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      describeError(snapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => setState(() => _check = _run()),
                      child: const Text('Nochmal versuchen'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) return const _Checking();
          return _ResultView(result: snapshot.data!);
        },
      ),
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Wir lesen die Google-Bewertungen…'),
          SizedBox(height: 4),
          Text('und suchen nach deinen Red Flags.'),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final CheckResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = VerdictStyle.of(result.verdict);
    final found = result.flags.where((f) => f.status != FlagStatus.clear);
    final clear = result.flags.where((f) => f.status == FlagStatus.clear);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: style.color,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(style.icon, size: 56, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  style.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.summary,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (result.rating != null) ...[
              const Icon(Icons.star, size: 18, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${result.rating!.toStringAsFixed(1)} '
                '(${result.ratingCount} Bewertungen)',
              ),
            ],
            const Spacer(),
            if (result.mapsUrl != null)
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(result.mapsUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Google Maps'),
              ),
          ],
        ),
        if (found.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Gefunden', style: theme.textTheme.titleMedium),
          for (final flag in found) _FlagCard(flag: flag),
        ],
        if (clear.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Unauffällig', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final flag in clear)
                Chip(
                  avatar: const Icon(Icons.check, color: Color(0xFF2E7D32)),
                  label: Text(flag.label),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Grundlage: die ${result.reviewCount} relevantesten '
          'Google-Bewertungen (mehr gibt Google nicht heraus). '
          '${result.engine == 'claude' ? 'Ausgewertet mit KI.' : 'Ausgewertet per Stichwortsuche.'} '
          'Das ist eine Einschätzung, keine Garantie.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FlagCard extends StatelessWidget {
  const _FlagCard({required this.flag});

  final FlagResult flag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serious = flag.status == FlagStatus.serious;
    final color = serious ? const Color(0xFFC62828) : const Color(0xFFEF6C00);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(flag.label, style: theme.textTheme.titleSmall),
                ),
                Text(
                  serious ? 'Ernst' : 'Erwähnt',
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
            if (flag.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(flag.note),
            ],
            for (final e in flag.evidence)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: color, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '«${e.quote}»',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    if (e.rating != null || e.when.isNotEmpty)
                      Text(
                        [
                          if (e.rating != null) '${e.rating} ★',
                          if (e.when.isNotEmpty) e.when,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
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
