import 'package:flutter/material.dart';

import '../red_flags.dart';
import '../services/profile_service.dart';
import '../verdict_style.dart';

/// Where the user says what would put them off a restaurant.
///
/// Shown on first launch, and later from the flag button on the main screen.
/// When [firstRun] is false the screen pops with the saved profile.
class RedFlagsScreen extends StatefulWidget {
  const RedFlagsScreen({
    super.key,
    required this.initial,
    this.firstRun = false,
    this.onSaved,
  });

  final RedFlagProfile initial;
  final bool firstRun;
  final ValueChanged<RedFlagProfile>? onSaved;

  @override
  State<RedFlagsScreen> createState() => _RedFlagsScreenState();
}

class _RedFlagsScreenState extends State<RedFlagsScreen> {
  late final Set<String> _selected = {...widget.initial.redFlags};
  late final List<String> _custom = [...widget.initial.customFlags];
  final _customController = TextEditingController();
  bool _saving = false;

  bool get _hasAny => _selected.isNotEmpty || _custom.isNotEmpty;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty || _custom.length >= 10) return;
    if (_custom.any((c) => c.toLowerCase() == text.toLowerCase())) {
      _customController.clear();
      return;
    }
    setState(() {
      _custom.add(text);
      _customController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Keep the catalogue order so the result screen lists flags consistently.
    final profile = RedFlagProfile(
      redFlags: [
        for (final flag in redFlagCatalogue)
          if (_selected.contains(flag.id)) flag.id,
      ],
      customFlags: _custom,
    );
    try {
      await ProfileService().save(profile);
      if (!mounted) return;
      widget.onSaved?.call(profile);
      if (!widget.firstRun) Navigator.of(context).pop(profile);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.firstRun ? 'Willkommen bei Red Flag' : 'Meine Red Flags',
        ),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Was ist für dich ein Grund, ein Restaurant zu meiden? '
              'Wir durchsuchen die Google-Bewertungen genau danach.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          for (final flag in redFlagCatalogue)
            CheckboxListTile(
              value: _selected.contains(flag.id),
              onChanged: (on) => setState(() {
                on == true ? _selected.add(flag.id) : _selected.remove(flag.id);
              }),
              secondary: Icon(
                flag.icon,
                color: _selected.contains(flag.id) ? redFlagRed : null,
              ),
              title: Text(flag.label),
              subtitle: Text(flag.description),
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Eigene Red Flags', style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _customController,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addCustom(),
              decoration: InputDecoration(
                hintText: 'z. B. laute Musik, kein Veggie-Angebot',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Hinzufügen',
                  onPressed: _addCustom,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final custom in _custom)
                  InputChip(
                    avatar: const Icon(Icons.flag, size: 18, color: redFlagRed),
                    label: Text(custom),
                    onDeleted: () => setState(() => _custom.remove(custom)),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _hasAny && !_saving ? _save : null,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(widget.firstRun ? 'Los geht\'s' : 'Speichern'),
        ),
      ),
    );
  }
}
