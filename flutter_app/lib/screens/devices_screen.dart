import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'provision_device_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String query = '';
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final devices = [...state.provisionedDevices]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final visibleDevices = devices.where((device) {
      final room = state.roomForDevice(device.id);
      final buildingName = room == null ? '' : state.buildingOf(room).name;
      final text =
          '${device.name} ${device.id} ${room?.name ?? ''} $buildingName'
              .toLowerCase();

      final matchesQuery = query.isEmpty || text.contains(query);
      final matchesFilter = filter == 'all' ||
          (filter == 'online' && device.status == DeviceStatus.online) ||
          (filter == 'warning' && device.status == DeviceStatus.warning) ||
          (filter == 'offline' && device.status == DeviceStatus.offline);

      return matchesQuery && matchesFilter;
    }).toList();

    final warningCount =
        devices.where((device) => device.status == DeviceStatus.warning).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Manager'),
        actions: [
          IconButton(
            tooltip: 'Add ESP32-C3',
            onPressed: () => _openProvisioning(context, state),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    title: 'Online',
                    value: '${state.onlineDevices}',
                    icon: Icons.sensors_rounded,
                    accent: EdgeColors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KpiCard(
                    title: 'Total Kits',
                    value: '${devices.length}',
                    icon: Icons.memory_rounded,
                    accent: EdgeColors.blue,
                  ),
                ),
              ],
            ),
            if (warningCount > 0) ...[
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: EdgeColors.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$warningCount device${warningCount == 1 ? '' : 's'} need attention.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() => query = value.trim().toLowerCase());
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search devices...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  initialValue: filter,
                  onSelected: (value) => setState(() => filter = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('All devices')),
                    PopupMenuItem(value: 'online', child: Text('Online')),
                    PopupMenuItem(value: 'warning', child: Text('Warning')),
                    PopupMenuItem(value: 'offline', child: Text('Offline')),
                  ],
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: EdgeColors.panel2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: EdgeColors.stroke),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: EdgeColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            if (devices.isEmpty)
              EmptyState(
                icon: Icons.memory_rounded,
                title: 'No ESP32-C3 kits yet',
                body: state.rooms.isEmpty
                    ? 'Create a room first, then connect your first EdgeSpace kit.'
                    : 'Connect an ESP32-C3 kit and assign it to one of your rooms.',
              )
            else if (visibleDevices.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching devices',
                body: 'Try another search term or status filter.',
              )
            else
              ...visibleDevices.map(
                (device) => _deviceCard(
                  context,
                  state,
                  device,
                ),
              ),
            if (state.rooms.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openProvisioning(context, state),
                  icon: const Icon(Icons.bluetooth_searching_rounded),
                  label: const Text('Add ESP32-C3 Kit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(
    BuildContext context,
    AppState state,
    DeviceKit device,
  ) {
    final room = state.roomForDevice(device.id);
    final color = _statusColor(device.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => _showDetails(context, state, device),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        room == null
                            ? 'Unassigned'
                            : '${state.buildingOf(room).name} / ${room.name}',
                        style: const TextStyle(
                          color: EdgeColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Device options',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: EdgeColors.muted,
                  ),
                  onSelected: (value) => _handleMenu(
                    context,
                    state,
                    device,
                    value,
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: _MenuRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Device details',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: _MenuRow(
                        icon: Icons.edit_rounded,
                        label: 'Rename',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'move',
                      child: _MenuRow(
                        icon: Icons.drive_file_move_outline,
                        label: 'Move to room',
                      ),
                    ),
                    if (device.status != DeviceStatus.offline)
                      const PopupMenuItem(
                        value: 'offline',
                        child: _MenuRow(
                          icon: Icons.link_off_rounded,
                          label: 'Mark offline',
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: _MenuRow(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete device',
                        destructive: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                StatusChip(
                  label: device.status.name.toUpperCase(),
                  color: color,
                ),
                StatusChip(
                  label: '${device.rssi} dBm',
                  color: _rssiColor(device.rssi),
                  icon: Icons.network_cell_rounded,
                ),
                StatusChip(
                  label: 'FW ${device.firmware}',
                  color: EdgeColors.cyan,
                  icon: Icons.system_update_alt_rounded,
                ),
                StatusChip(
                  label: _lastSeenShort(device.lastSeen),
                  color: EdgeColors.muted,
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              device.id,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EdgeColors.muted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProvisioning(
    BuildContext context,
    AppState state,
  ) async {
    if (state.rooms.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create a room first'),
          content: const Text(
            'Every EdgeSpace kit must belong to a room. Create a Building and Room from Spaces before connecting the ESP32-C3.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final hasAvailableRoom = state.rooms.any(
      (room) => state.isRoomAvailableForDevice(room.id),
    );

    if (!hasAvailableRoom) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No available rooms'),
          content: const Text(
            'Every room already has a kit assigned. Create another room or move/delete an existing device first.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProvisionDeviceScreen(),
      ),
    );
  }

  void _handleMenu(
    BuildContext context,
    AppState state,
    DeviceKit device,
    String value,
  ) {
    switch (value) {
      case 'details':
        _showDetails(context, state, device);
        break;
      case 'rename':
        _renameDevice(context, state, device);
        break;
      case 'move':
        _moveDevice(context, state, device);
        break;
      case 'offline':
        _markOffline(context, state, device);
        break;
      case 'delete':
        _deleteDevice(context, state, device);
        break;
    }
  }

  Future<void> _renameDevice(
    BuildContext context,
    AppState state,
    DeviceKit device,
  ) async {
    final controller = TextEditingController(text: device.name);

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Device name',
            prefixIcon: Icon(Icons.memory_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save == true && controller.text.trim().isNotEmpty) {
      state.renameDevice(
        deviceId: device.id,
        name: controller.text.trim(),
      );
    }

    controller.dispose();
  }

  Future<void> _moveDevice(
    BuildContext context,
    AppState state,
    DeviceKit device,
  ) async {
    final currentRoom = state.roomForDevice(device.id);

    final availableRooms = state.rooms.where((room) {
      return room.id == currentRoom?.id ||
          state.isRoomAvailableForDevice(
            room.id,
            exceptDeviceId: device.id,
          );
    }).toList();

    if (availableRooms.length <= 1 && currentRoom != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There is no other available room for this device.'),
        ),
      );
      return;
    }

    String selectedRoomId = currentRoom?.id ?? availableRooms.first.id;

    final move = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Move device'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedRoomId,
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
            onChanged: (value) {
              if (value != null) {
                setLocal(() => selectedRoomId = value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );

    if (move == true && selectedRoomId != currentRoom?.id) {
      try {
        state.moveDevice(
          deviceId: device.id,
          newRoomId: selectedRoomId,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _markOffline(
    BuildContext context,
    AppState state,
    DeviceKit device,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark device offline?'),
        content: Text(
          'Mark "${device.name}" as offline? The room assignment and historical measurements will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark offline'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      state.disconnectDevice(device.id);
    }
  }

  Future<void> _deleteDevice(
    BuildContext context,
    AppState state,
    DeviceKit device,
  ) async {
    final room = state.roomForDevice(device.id);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete device?'),
        content: Text(
          'Delete "${device.name}" from EdgeSpace AI?\n\n'
          '${room == null ? 'The device is currently unassigned.' : '${room.name} will become unassigned.'}\n\n'
          'Historical room measurements will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EdgeColors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      state.deleteDevice(device.id);
    }
  }

  Future<void> _showDetails(
    BuildContext context,
    AppState state,
    DeviceKit device,
  ) async {
    final room = state.roomForDevice(device.id);
    final color = _statusColor(device.status);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: EdgeColors.panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.memory_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          device.id,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: EdgeColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: device.status.name.toUpperCase(),
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    _DetailLine(
                      label: 'Room',
                      value: room == null
                          ? 'Unassigned'
                          : '${state.buildingOf(room).name} / ${room.name}',
                    ),
                    _DetailLine(
                      label: 'RSSI',
                      value: '${device.rssi} dBm',
                    ),
                    _DetailLine(
                      label: 'Firmware',
                      value: device.firmware,
                    ),
                    _DetailLine(
                      label: 'Last seen',
                      value: DateFormat('dd/MM/yyyy HH:mm:ss')
                          .format(device.lastSeen),
                    ),
                    _DetailLine(
                      label: 'Uptime',
                      value: device.uptimeHours <= 0
                          ? 'Waiting for telemetry'
                          : '${device.uptimeHours.toStringAsFixed(1)} h',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(DeviceStatus status) {
    return switch (status) {
      DeviceStatus.online => EdgeColors.green,
      DeviceStatus.warning => EdgeColors.amber,
      DeviceStatus.offline => EdgeColors.red,
    };
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return EdgeColors.green;
    if (rssi >= -75) return EdgeColors.amber;
    return EdgeColors.red;
  }

  String _lastSeenShort(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd/MM HH:mm').format(value);
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? EdgeColors.red : null;

    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          color: EdgeColors.muted,
          fontSize: 11,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 210),
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
