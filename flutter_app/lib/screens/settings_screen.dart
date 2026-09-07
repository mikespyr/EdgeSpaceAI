import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../l10n/language_controller.dart';
import '../widgets/common.dart';
import 'devices_screen.dart';
import 'provision_device_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController backend;

  bool initialized = false;
  bool demoMode = true;
  bool useGemini = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (initialized) return;

    final state = context.read<AppState>();

    backend = TextEditingController(
      text: state.backendUrl,
    );

    demoMode = state.demoMode;
    useGemini = state.useGemini;

    initialized = true;
  }

  @override
  void dispose() {
    if (initialized) {
      backend.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final language = context.watch<LanguageController>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Text(
            context.tr(
              'Settings',
              'Ρυθμίσεις',
            ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          const SizedBox(height: 16),

          GlassCard(
            child: Row(
              children: [
                const BrandMark(size: 48),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EdgeSpace AI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Smart Spaces · IoT · Edge AI · Gemini',
                        style: TextStyle(
                          fontSize: 10,
                          color: EdgeColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: state.backendOnline
                      ? context.tr(
                          'Backend Online',
                          'Backend Online',
                        )
                      : context.tr(
                          'Backend Offline',
                          'Backend Offline',
                        ),
                  color:
                      state.backendOnline ? EdgeColors.green : EdgeColors.red,
                ),
              ],
            ),
          ),

          // =====================================================
          // LANGUAGE
          // =====================================================

          const SizedBox(height: 18),

          SectionHeader(
            context.tr(
              'Language',
              'Γλώσσα',
            ),
            subtitle: context.tr(
              'App display language',
              'Γλώσσα εμφάνισης εφαρμογής',
            ),
          ),

          const SizedBox(height: 10),

          GlassCard(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: EdgeColors.blue,
              ),
              title: Text(
                context.tr(
                  'App Language',
                  'Γλώσσα εφαρμογής',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _languageModeLabel(
                  context,
                  language.mode,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
              ),
              onTap: () => _showLanguageSelector(
                context,
                language,
              ),
            ),
          ),

          // =====================================================
          // DEVICE MANAGEMENT
          // =====================================================

          const SizedBox(height: 18),

          SectionHeader(
            context.tr(
              'Device Management',
              'Διαχείριση συσκευών',
            ),
            subtitle: context.tr(
              'ESP32-C3 kits and onboarding',
              'ESP32-C3 kits και σύνδεση συσκευών',
            ),
          ),

          const SizedBox(height: 10),

          GlassCard(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.memory_rounded,
                    color: EdgeColors.blue,
                  ),
                  title: Text(
                    context.tr(
                      'Device Manager',
                      'Διαχείριση συσκευών',
                    ),
                  ),
                  subtitle: Text(
                    context.isGreek
                        ? '${state.onlineDevices}/${state.provisionedDevices.length} kits online'
                        : '${state.onlineDevices}/${state.provisionedDevices.length} kits online',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DevicesScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.bluetooth_searching_rounded,
                    color: EdgeColors.cyan,
                  ),
                  title: Text(
                    context.tr(
                      'Connect New Kit',
                      'Σύνδεση νέου Kit',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      'Bluetooth + Wi-Fi provisioning',
                      'Ρύθμιση μέσω Bluetooth + Wi-Fi',
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProvisionDeviceScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // DATA & AI
          // =====================================================

          const SizedBox(height: 18),

          SectionHeader(
            context.tr(
              'Data & AI',
              'Δεδομένα & AI',
            ),
            subtitle: context.tr(
              'Backend and assistant configuration',
              'Ρυθμίσεις backend και βοηθού AI',
            ),
          ),

          const SizedBox(height: 10),

          GlassCard(
            child: Column(
              children: [
                TextField(
                  controller: backend,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'Backend URL',
                      'Backend URL',
                    ),
                    prefixIcon: const Icon(
                      Icons.dns_rounded,
                    ),
                    hintText: 'https://edgespace-ai-backend.onrender.com',
                  ),
                ),
                if (_usesEmulatorLoopback(backend.text)) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      '10.0.2.2 works only inside the Android emulator. '
                          'On a physical phone or ESP32-C3 use a reachable '
                          'backend address.',
                      'Η διεύθυνση 10.0.2.2 λειτουργεί μόνο μέσα στον '
                          'Android emulator. Σε πραγματικό κινητό ή ESP32-C3 '
                          'χρησιμοποίησε backend διεύθυνση που είναι προσβάσιμη.',
                    ),
                    style: const TextStyle(
                      color: EdgeColors.amber,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.tr(
                      'Demo data mode',
                      'Λειτουργία demo δεδομένων',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      'Use generated sensor values when the real backend is not connected.',
                      'Χρήση εικονικών μετρήσεων αισθητήρων όταν δεν είναι συνδεδεμένο το πραγματικό backend.',
                    ),
                    style: const TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  value: demoMode,
                  onChanged: (value) {
                    setState(() => demoMode = value);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Gemini AI Advisor',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      'AI requests are routed through the EdgeSpace backend; '
                          'the key is never stored in the mobile app.',
                      'Τα αιτήματα AI περνούν μέσω του EdgeSpace backend. '
                          'Το API key δεν αποθηκεύεται ποτέ στην εφαρμογή.',
                    ),
                    style: const TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  value: useGemini,
                  onChanged: (value) {
                    setState(() => useGemini = value);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await state.saveSettings(
                        newBackendUrl: backend.text.trim(),
                        newDemoMode: demoMode,
                        newUseGemini: useGemini,
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr(
                              'Settings saved.',
                              'Οι ρυθμίσεις αποθηκεύτηκαν.',
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.save_outlined,
                    ),
                    label: Text(
                      context.tr(
                        'Save Settings',
                        'Αποθήκευση ρυθμίσεων',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // MONITORING
          // =====================================================

          const SizedBox(height: 18),

          SectionHeader(
            context.tr(
              'Monitoring',
              'Παρακολούθηση',
            ),
            subtitle: context.tr(
              'How the platform reacts to sensor events',
              'Πώς αντιδρά η πλατφόρμα στα δεδομένα αισθητήρων',
            ),
          ),

          const SizedBox(height: 10),

          GlassCard(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.notifications_active_outlined,
                    color: EdgeColors.red,
                  ),
                  title: Text(
                    context.tr(
                      'Smart Alerts',
                      'Έξυπνες ειδοποιήσεις',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      'Prototype status: demo alerts only; backend alert rules are not wired yet.',
                      'Κατάσταση prototype: προς το παρόν χρησιμοποιούνται demo alerts.',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.insights_outlined,
                    color: EdgeColors.green,
                  ),
                  title: Text(
                    context.tr(
                      'Analysis Rules',
                      'Κανόνες ανάλυσης',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      'Local scoring and trend rules are active.',
                      'Οι τοπικοί κανόνες αξιολόγησης και τάσεων είναι ενεργοί.',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    color: EdgeColors.blue,
                  ),
                  title: Text(
                    context.tr(
                      'Retention',
                      'Ιστορικό δεδομένων',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      '24h · 7d · 30d filters are available; Custom currently uses 7 days.',
                      'Υπάρχουν φίλτρα 24 ωρών · 7 ημερών · 30 ημερών. '
                          'Το Custom χρησιμοποιεί προς το παρόν 7 ημέρες.',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            context.tr(
              'EdgeSpace AI v1.0.0 · Conference prototype',
              'EdgeSpace AI v1.0.0 · Πρωτότυπο συνεδρίου',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: EdgeColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _languageModeLabel(
    BuildContext context,
    AppLanguageMode mode,
  ) {
    return switch (mode) {
      AppLanguageMode.automatic => context.tr(
          'Automatic · Device language',
          'Αυτόματα · Γλώσσα συσκευής',
        ),
      AppLanguageMode.greek => 'Ελληνικά',
      AppLanguageMode.english => 'English',
    };
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    LanguageController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: EdgeColors.panel,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetContext.tr(
                    'Language',
                    'Γλώσσα',
                  ),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  sheetContext.tr(
                    'Choose how EdgeSpace AI selects its display language.',
                    'Επίλεξε πώς θα καθορίζεται η γλώσσα εμφάνισης του EdgeSpace AI.',
                  ),
                  style: const TextStyle(
                    color: EdgeColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                _LanguageOption(
                  icon: Icons.phone_android_rounded,
                  title: sheetContext.tr(
                    'Automatic',
                    'Αυτόματα',
                  ),
                  subtitle: sheetContext.tr(
                    'Follow the language of the device',
                    'Ακολουθεί τη γλώσσα του κινητού',
                  ),
                  selected: controller.mode == AppLanguageMode.automatic,
                  onTap: () async {
                    await controller.setMode(
                      AppLanguageMode.automatic,
                    );

                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  icon: Icons.translate_rounded,
                  title: 'Ελληνικά',
                  subtitle: 'Η εφαρμογή εμφανίζεται πάντα στα Ελληνικά',
                  selected: controller.mode == AppLanguageMode.greek,
                  onTap: () async {
                    await controller.setMode(
                      AppLanguageMode.greek,
                    );

                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  icon: Icons.language_rounded,
                  title: 'English',
                  subtitle: 'The app always uses English',
                  selected: controller.mode == AppLanguageMode.english,
                  onTap: () async {
                    await controller.setMode(
                      AppLanguageMode.english,
                    );

                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _usesEmulatorLoopback(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = uri?.host.toLowerCase() ?? '';

    return host == '10.0.2.2' || host == '127.0.0.1' || host == 'localhost';
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? EdgeColors.blue.withValues(alpha: .12) : EdgeColors.panel2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? EdgeColors.blue : EdgeColors.stroke,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? EdgeColors.blue : EdgeColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: EdgeColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: EdgeColors.blue,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
