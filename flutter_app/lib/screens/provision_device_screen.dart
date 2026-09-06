import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/ble_provisioning_service.dart';
import '../widgets/common.dart';
import 'qr_scan_screen.dart';

class ProvisionDeviceScreen extends StatefulWidget {
  const ProvisionDeviceScreen({super.key});

  @override
  State<ProvisionDeviceScreen> createState() => _ProvisionDeviceScreenState();
}

class _ProvisionDeviceScreenState extends State<ProvisionDeviceScreen> {
  final ble = BleProvisioningService();
  final ssid = TextEditingController();
  final password = TextEditingController();
  final deviceName = TextEditingController(text: 'EdgeSpace Kit');

  var step = 0;
  var scanning = false;
  var provisioning = false;

  var candidates = <ProvisionCandidate>[];
  ProvisionCandidate? selected;

  String? roomId;
  String? statusText;
  String? qrDeviceId;

  @override
  void dispose() {
    ssid.dispose();
    password.dispose();
    deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.rooms.isEmpty) {
      return _noRoomsScaffold();
    }

    final availableRooms = _availableRooms(state);

    if (step < 3) {
      if (roomId != null && !availableRooms.any((room) => room.id == roomId)) {
        roomId = null;
      }

      roomId ??= availableRooms.isNotEmpty ? availableRooms.first.id : null;

      if (availableRooms.isEmpty) {
        return _noAvailableRoomsScaffold();
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Device',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 26),
          children: [
            _StepHeader(step: step),
            const SizedBox(height: 30),
            if (step == 0) _scanStep(state),
            if (step == 1) _connectStep(),
            if (step == 2) _configureStep(state),
            if (step == 3) _doneStep(state),
          ],
        ),
      ),
    );
  }

  List<Room> _availableRooms(AppState state) {
    return state.rooms
        .where((room) => state.isRoomAvailableForDevice(room.id))
        .toList();
  }

  Scaffold _noRoomsScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.meeting_room_outlined,
            title: 'Create a room first',
            body:
                'Every ESP32-C3 kit must be assigned to a room. Create a Building and Room from Spaces, then return here.',
          ),
        ),
      ),
    );
  }

  Scaffold _noAvailableRoomsScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.domain_disabled_rounded,
            title: 'No available rooms',
            body:
                'Every room already has a kit assigned. Create another room or move/delete an existing device first.',
          ),
        ),
      ),
    );
  }

  Widget _scanStep(AppState state) {
    return Column(
      children: [
        Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: EdgeColors.blue.withValues(alpha: .45),
            ),
            boxShadow: [
              BoxShadow(
                color: EdgeColors.blue.withValues(alpha: .15),
                blurRadius: 30,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            scanning
                ? Icons.bluetooth_searching_rounded
                : Icons.bluetooth_rounded,
            color: EdgeColors.blue,
            size: 52,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          scanning ? 'Scanning for ESP devices...' : 'Find your EdgeSpace Kit',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'The app searches for ESP32-C3 kits advertising the EdgeSpace provisioning service.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: EdgeColors.muted,
            height: 1.45,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: scanning ? null : _scan,
            icon: scanning
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bluetooth_searching_rounded),
            label: Text(
              scanning ? 'Scanning...' : 'Scan Bluetooth',
            ),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final value = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const QrScanScreen(),
                ),
              );

              if (value != null && value.trim().isNotEmpty && mounted) {
                setState(() => qrDeviceId = value.trim());
              }
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(
              qrDeviceId == null ? 'Scan Kit QR Code' : 'QR: $qrDeviceId',
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (candidates.isEmpty && !scanning)
          const EmptyState(
            icon: Icons.sensors_off_rounded,
            title: 'No scanned devices yet',
            body:
                'Power the ESP32-C3 kit, put it in provisioning mode, then tap Scan Bluetooth.',
          )
        else
          ...candidates.map(
            (candidate) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: EdgeColors.blue.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bluetooth_rounded,
                        color: EdgeColors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            candidate.device.remoteId.str,
                            style: const TextStyle(
                              color: EdgeColors.muted,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'RSSI ${candidate.rssi} dBm',
                            style: const TextStyle(
                              color: EdgeColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(82, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () => _selectCandidate(candidate),
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (state.demoMode && candidates.isEmpty && !scanning) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              setState(() {
                selected = null;
                deviceName.text = 'EdgeSpace Demo Kit';
                step = 1;
              });
            },
            icon: const Icon(Icons.science_outlined),
            label: const Text('Continue with demo kit'),
          ),
        ],
      ],
    );
  }

  void _selectCandidate(ProvisionCandidate candidate) {
    setState(() {
      selected = candidate;
      if (deviceName.text.trim().isEmpty ||
          deviceName.text.trim() == 'EdgeSpace Kit') {
        deviceName.text = candidate.name;
      }
      step = 1;
    });
  }

  Widget _connectStep() {
    final displayId =
        qrDeviceId ?? selected?.device.remoteId.str ?? 'DEMO-C3-001';

    return Column(
      children: [
        Container(
          width: 102,
          height: 102,
          decoration: BoxDecoration(
            color: EdgeColors.green.withValues(alpha: .1),
            shape: BoxShape.circle,
            border: Border.all(
              color: EdgeColors.green.withValues(alpha: .4),
            ),
          ),
          child: const Icon(
            Icons.link_rounded,
            color: EdgeColors.green,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Kit selected',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          selected?.name ?? 'EdgeSpace Demo Kit',
          style: const TextStyle(color: EdgeColors.muted),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
          child: Column(
            children: [
              _ConnectionLine(
                label: 'Bluetooth',
                value: selected == null ? 'Demo' : 'Discovered',
                color: selected == null ? EdgeColors.amber : EdgeColors.green,
              ),
              _ConnectionLine(
                label: 'Device ID',
                value: displayId,
                color: EdgeColors.blue,
              ),
              const _ConnectionLine(
                label: 'Provisioning service',
                value: 'EdgeSpace BLE',
                color: EdgeColors.cyan,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => step = 2),
            child: const Text('Continue to Configuration'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => step = 0),
          child: const Text('Choose another device'),
        ),
      ],
    );
  }

  Widget _configureStep(AppState state) {
    final availableRooms = _availableRooms(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: EdgeColors.blue.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_input_antenna_rounded,
                  color: EdgeColors.blue,
                  size: 42,
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Configure EdgeSpace Kit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Name the kit, choose its room and send Wi-Fi configuration over BLE.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: EdgeColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: deviceName,
          decoration: const InputDecoration(
            labelText: 'Device name',
            prefixIcon: Icon(Icons.memory_rounded),
          ),
        ),
        const SizedBox(height: 11),
        DropdownButtonFormField<String>(
          initialValue: roomId,
          decoration: const InputDecoration(
            labelText: 'Assign to room',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          items: availableRooms
              .map(
                (room) => DropdownMenuItem(
                  value: room.id,
                  child: Text(
                    '${state.buildingOf(room).name} / ${room.name}',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => roomId = value),
        ),
        const SizedBox(height: 11),
        TextField(
          controller: ssid,
          decoration: const InputDecoration(
            labelText: 'Wi-Fi Network (SSID)',
            prefixIcon: Icon(Icons.wifi_rounded),
          ),
        ),
        const SizedBox(height: 11),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 11),
        TextFormField(
          initialValue: state.backendUrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'EdgeSpace Server',
            prefixIcon: Icon(Icons.dns_outlined),
          ),
        ),
        if (_usesLoopbackBackend(state.backendUrl) && selected != null) ...[
          const SizedBox(height: 8),
          const Text(
            '10.0.2.2 / localhost cannot be reached by a physical ESP32-C3. Use the LAN IP of the computer running the backend before provisioning.',
            style: TextStyle(
              color: EdgeColors.amber,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(
              Icons.lock_rounded,
              color: EdgeColors.muted,
              size: 13,
            ),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Credentials are sent only during local BLE provisioning. Do not store cloud API keys on the ESP32.',
                style: TextStyle(
                  color: EdgeColors.muted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: provisioning ? null : () => _provision(state),
            icon: provisioning
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              provisioning ? 'Configuring...' : 'Provision Device',
            ),
          ),
        ),
        if (statusText != null) ...[
          const SizedBox(height: 12),
          Text(
            statusText!,
            style: const TextStyle(
              color: EdgeColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _doneStep(AppState state) {
    final room = state.roomById(roomId!);
    final deviceId = room.deviceId;
    final device = state.deviceByIdOrNull(deviceId);

    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: EdgeColors.green.withValues(alpha: .11),
            shape: BoxShape.circle,
            border: Border.all(
              color: EdgeColors.green.withValues(alpha: .4),
            ),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: EdgeColors.green,
            size: 58,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Device Connected',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${device?.name ?? 'EdgeSpace Kit'} is assigned to ${room.name}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: EdgeColors.muted),
        ),
        const SizedBox(height: 22),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
          child: Column(
            children: [
              const _ConnectionLine(
                label: 'Wi-Fi',
                value: 'Configured',
                color: EdgeColors.green,
              ),
              _ConnectionLine(
                label: 'Device ID',
                value: deviceId,
                color: EdgeColors.blue,
              ),
              const _ConnectionLine(
                label: 'Telemetry',
                value: 'Ready',
                color: EdgeColors.green,
              ),
              const _ConnectionLine(
                label: 'Sensors',
                value: 'Waiting for first packet',
                color: EdgeColors.blue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Future<void> _scan() async {
    setState(() {
      scanning = true;
      candidates = [];
      statusText = null;
    });

    try {
      final result = await ble.scan();
      if (!mounted) return;

      setState(() => candidates = result);

      if (result.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No EdgeSpace provisioning devices were found.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth scan failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => scanning = false);
      }
    }
  }

  Future<void> _provision(AppState state) async {
    final cleanName = deviceName.text.trim();
    final cleanSsid = ssid.text.trim();

    if (cleanName.isEmpty) {
      _showMessage('Enter a device name.');
      return;
    }

    if (roomId == null) {
      _showMessage('Choose a room.');
      return;
    }

    if (!state.isRoomAvailableForDevice(roomId!)) {
      _showMessage('The selected room already has a device assigned.');
      return;
    }

    if (cleanSsid.isEmpty) {
      _showMessage('Enter the Wi-Fi SSID.');
      return;
    }

    if (selected == null && !state.demoMode) {
      _showMessage('Select an ESP32-C3 over Bluetooth before provisioning.');
      return;
    }

    if (selected != null && _usesLoopbackBackend(state.backendUrl)) {
      _showMessage(
        'The backend URL uses emulator/localhost loopback. Set the PC LAN IP in Settings (for example http://192.168.1.100:8000) before provisioning a physical ESP32-C3.',
      );
      return;
    }

    setState(() {
      provisioning = true;
      statusText = 'Sending configuration...';
    });

    final deviceId = qrDeviceId?.trim().isNotEmpty == true
        ? qrDeviceId!.trim()
        : selected?.device.remoteId.str ??
            'edge-${const Uuid().v4().substring(0, 8)}';

    try {
      if (selected != null) {
        final result = await ble.provision(
          device: selected!.device,
          ssid: cleanSsid,
          password: password.text,
          serverUrl: state.backendUrl,
          deviceId: deviceId,
          roomId: roomId!,
        );

        final normalizedStatus = result.trim().toLowerCase();
        if (normalizedStatus.contains('error') ||
            normalizedStatus.contains('fail') ||
            normalizedStatus.contains('invalid')) {
          throw Exception(
            result.isEmpty ? 'ESP32-C3 rejected the configuration.' : result,
          );
        }

        statusText = result.isEmpty ? 'Configuration written.' : result;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        statusText = 'Demo provisioning completed.';
      }

      if (!state.demoMode) {
        await ApiClient(state.backendUrl).registerDevice(
          deviceId: deviceId,
          roomId: roomId!,
          name: cleanName,
        );
      }

      state.addProvisionedDevice(
        id: deviceId,
        roomId: roomId!,
        name: cleanName,
        rssi: selected?.rssi ?? -50,
      );

      if (!mounted) return;

      setState(() => step = 3);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusText = 'Could not complete provisioning: $e';
      });
    } finally {
      if (mounted) {
        setState(() => provisioning = false);
      }
    }
  }

  bool _usesLoopbackBackend(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = uri?.host.toLowerCase() ?? '';
    return host == '10.0.2.2' || host == '127.0.0.1' || host == 'localhost';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Scan', 'Select', 'Configure', 'Done'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(labels.length, (index) {
        final done = index < step;
        final active = index == step;
        final color = done || active ? EdgeColors.blue : EdgeColors.muted;

        return Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        color: active
                            ? EdgeColors.blueStrong
                            : done
                                ? EdgeColors.green
                                : EdgeColors.panel2,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: .7),
                        ),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : color,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (index != labels.length - 1)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  height: 1,
                  width: 18,
                  color: index < step ? EdgeColors.green : EdgeColors.stroke,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: EdgeColors.muted,
          fontSize: 11,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          value,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
