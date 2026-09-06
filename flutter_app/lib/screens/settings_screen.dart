import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
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
    backend = TextEditingController(text: state.backendUrl);
    demoMode = state.demoMode;
    useGemini = state.useGemini;
    initialized = true;
  }

  @override
  void dispose() {
    if (initialized) backend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          GlassCard(
            child: Row(children: [
              const BrandMark(size: 48),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('EdgeSpace AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Smart Spaces · IoT · Edge AI · Gemini', style: TextStyle(fontSize: 10, color: EdgeColors.muted))])),
              StatusChip(label: state.backendOnline ? 'Backend Online' : 'Backend Offline', color: state.backendOnline ? EdgeColors.green : EdgeColors.red),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Device Management', subtitle: 'ESP32-C3 kits and onboarding'),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.memory_rounded, color: EdgeColors.blue),
                title: const Text('Device Manager'),
                subtitle: Text('${state.onlineDevices}/${state.provisionedDevices.length} kits online'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevicesScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bluetooth_searching_rounded, color: EdgeColors.cyan),
                title: const Text('Connect New Kit'),
                subtitle: const Text('Bluetooth + Wi-Fi provisioning'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProvisionDeviceScreen())),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Data & AI', subtitle: 'Backend and assistant configuration'),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(children: [
              TextField(
                controller: backend,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Backend URL',
                  prefixIcon: Icon(Icons.dns_rounded),
                  hintText: 'http://192.168.1.100:8000',
                ),
              ),
              if (_usesEmulatorLoopback(backend.text)) ...[
                const SizedBox(height: 8),
                const Text(
                  '10.0.2.2 works only inside the Android emulator. On a physical phone or ESP32-C3 use the LAN IP of the computer running the backend, for example http://192.168.1.100:8000.',
                  style: TextStyle(color: EdgeColors.amber, fontSize: 10, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Demo data mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Use generated sensor values when the real backend is not connected.', style: TextStyle(fontSize: 10)),
                value: demoMode,
                onChanged: (v) => setState(() => demoMode = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gemini AI Advisor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('AI requests are routed through the EdgeSpace backend; the key is never stored in the mobile app.', style: TextStyle(fontSize: 10)),
                value: useGemini,
                onChanged: (v) => setState(() => useGemini = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await state.saveSettings(newBackendUrl: backend.text.trim(), newDemoMode: demoMode, newUseGemini: useGemini);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Settings'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Monitoring', subtitle: 'How the platform reacts to sensor events'),
          const SizedBox(height: 10),
          const GlassCard(
            padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: Column(children: [
              ListTile(leading: Icon(Icons.notifications_active_outlined, color: EdgeColors.red), title: Text('Smart Alerts'), subtitle: Text('Prototype status: demo alerts only; backend alert rules are not wired yet.')),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.insights_outlined, color: EdgeColors.green), title: Text('Analysis Rules'), subtitle: Text('Local scoring and trend rules are active.')),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.history_rounded, color: EdgeColors.blue), title: Text('Retention'), subtitle: Text('24h · 7d · 30d filters are available; Custom currently uses 7 days.')),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('EdgeSpace AI v1.0.0 · Conference prototype', textAlign: TextAlign.center, style: TextStyle(color: EdgeColors.muted, fontSize: 10)),
        ],
      ),
    );
  }

  bool _usesEmulatorLoopback(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = uri?.host.toLowerCase() ?? '';
    return host == '10.0.2.2' || host == '127.0.0.1' || host == 'localhost';
  }
}
