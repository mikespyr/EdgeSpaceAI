import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'provision_device_screen.dart';
import 'room_detail_screen.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  bool showBuildings = true;
  String query = '';
  String status = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          110,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spaces',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: () => _showAddMenu(context, state),
                icon: const Icon(
                  Icons.add_rounded,
                ),
                tooltip: 'Add',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TwoTabSwitch(
            left: 'Buildings',
            right: 'Rooms',
            leftSelected: showBuildings,
            onChanged: (value) {
              setState(() {
                showBuildings = value;
                query = '';
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      query = value.trim().toLowerCase();
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                    ),
                    hintText: 'Search spaces...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                initialValue: status,
                onSelected: (value) {
                  setState(() {
                    status = value;
                  });
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'all',
                    child: Text('All statuses'),
                  ),
                  PopupMenuItem(
                    value: 'healthy',
                    child: Text('Healthy'),
                  ),
                  PopupMenuItem(
                    value: 'attention',
                    child: Text(
                      'Needs attention',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'critical',
                    child: Text('Critical'),
                  ),
                  PopupMenuItem(
                    value: 'waiting',
                    child: Text(
                      'Waiting for data',
                    ),
                  ),
                ],
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: EdgeColors.panel2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: EdgeColors.stroke,
                    ),
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
          if (showBuildings) ..._buildingCards(state) else ..._roomCards(state),
        ],
      ),
    );
  }

  // ============================================================
  // BUILDING CARDS
  // ============================================================

  List<Widget> _buildingCards(AppState state) {
    final filteredBuildings = state.buildings.where(
      (building) {
        final matchesSearch = query.isEmpty ||
            building.name.toLowerCase().contains(query) ||
            building.location.toLowerCase().contains(query);

        if (!matchesSearch) {
          return false;
        }

        final rooms = state.rooms
            .where(
              (room) => room.buildingId == building.id,
            )
            .toList();

        final roomsWithData = rooms
            .where(
              (room) => state.hasTelemetry(room.id),
            )
            .toList();

        final waitingCount = rooms.length - roomsWithData.length;

        if (status == 'waiting') {
          return waitingCount > 0;
        }

        if (status == 'all') {
          return true;
        }

        if (roomsWithData.isEmpty) {
          return false;
        }

        final avg = (roomsWithData
                    .map(state.snapshot)
                    .map((e) => e.score)
                    .reduce((a, b) => a + b) /
                roomsWithData.length)
            .round();

        return (status == 'healthy' && avg >= 85) ||
            (status == 'attention' && avg >= 65 && avg < 85) ||
            (status == 'critical' && avg < 65);
      },
    ).toList();

    if (filteredBuildings.isEmpty) {
      return [
        _EmptyState(
          icon: Icons.apartment_rounded,
          title: state.buildings.isEmpty
              ? 'No buildings yet'
              : 'No buildings found',
          subtitle: state.buildings.isEmpty
              ? 'Tap + to create your first building.'
              : 'Try changing your search or status filter.',
        ),
      ];
    }

    return filteredBuildings.map(
      (building) {
        final rooms = state.rooms
            .where(
              (room) => room.buildingId == building.id,
            )
            .toList();

        final roomsWithData = rooms
            .where(
              (room) => state.hasTelemetry(room.id),
            )
            .toList();

        final online = rooms
            .where(
              (room) => state.deviceOf(room).status != DeviceStatus.offline,
            )
            .length;

        final waitingCount = rooms.length - roomsWithData.length;

        int? averageScore;

        if (roomsWithData.isNotEmpty) {
          final scores = roomsWithData
              .map(state.snapshot)
              .map((snapshot) => snapshot.score)
              .toList();

          averageScore =
              (scores.reduce((a, b) => a + b) / scores.length).round();
        }

        final statusLabel = rooms.isEmpty
            ? 'No rooms'
            : averageScore == null
                ? 'Waiting for data'
                : averageScore >= 85
                    ? 'Healthy'
                    : averageScore >= 65
                        ? 'Needs Attention'
                        : 'Critical';

        final statusColor = rooms.isEmpty || averageScore == null
            ? EdgeColors.muted
            : averageScore >= 85
                ? EdgeColors.green
                : averageScore >= 65
                    ? EdgeColors.amber
                    : EdgeColors.red;

        return Padding(
          padding: const EdgeInsets.only(
            bottom: 12,
          ),
          child: GlassCard(
            onTap: () {
              setState(() {
                showBuildings = false;
                query = building.name.toLowerCase();
                status = 'all';
              });
            },
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _BuildingThumb(
                  seed: building.id.hashCode,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (building.location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          building.location,
                          style: const TextStyle(
                            color: EdgeColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${rooms.length} rooms · '
                        '$online online'
                        '${waitingCount > 0 ? ' · $waitingCount waiting' : ''}',
                        style: const TextStyle(
                          color: EdgeColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StatusChip(
                        label: statusLabel,
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Building options',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: EdgeColors.muted,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editBuilding(
                        context,
                        state,
                        building,
                      );
                    }

                    if (value == 'delete') {
                      _deleteBuilding(
                        context,
                        state,
                        building,
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded),
                          SizedBox(width: 10),
                          Text('Edit building'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: EdgeColors.red,
                          ),
                          SizedBox(width: 10),
                          Text('Delete building'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).toList();
  }

  // ============================================================
  // ROOM CARDS
  // ============================================================

  List<Widget> _roomCards(AppState state) {
    final filteredSnapshots = state.snapshots.where(
      (snapshot) {
        final building = state.buildingOf(snapshot.room);

        final hasData = state.hasTelemetry(
          snapshot.room.id,
        );

        final matchesQuery = query.isEmpty ||
            snapshot.room.name.toLowerCase().contains(query) ||
            building.name.toLowerCase().contains(query) ||
            snapshot.room.floor.toLowerCase().contains(query);

        final matchesStatus = status == 'all' ||
            (status == 'waiting' && !hasData) ||
            (status == 'healthy' && hasData && snapshot.score >= 85) ||
            (status == 'attention' &&
                hasData &&
                snapshot.score >= 65 &&
                snapshot.score < 85) ||
            (status == 'critical' && hasData && snapshot.score < 65);

        return matchesQuery && matchesStatus;
      },
    ).toList();

    if (filteredSnapshots.isEmpty) {
      return [
        _EmptyState(
          icon: Icons.meeting_room_rounded,
          title: state.rooms.isEmpty ? 'No rooms yet' : 'No rooms found',
          subtitle: state.rooms.isEmpty
              ? state.buildings.isEmpty
                  ? 'Create a building first, then add a room.'
                  : 'Tap + to create your first room.'
              : 'Try changing your search or status filter.',
        ),
      ];
    }

    return filteredSnapshots.map(
      (snapshot) {
        final device = state.deviceOf(snapshot.room);

        final roomHasData = state.hasTelemetry(
          snapshot.room.id,
        );

        final statusColor = !roomHasData
            ? EdgeColors.muted
            : snapshot.score >= 85
                ? EdgeColors.green
                : snapshot.score >= 65
                    ? EdgeColors.amber
                    : EdgeColors.red;

        return Padding(
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: GlassCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoomDetailScreen(
                    room: snapshot.room,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                if (roomHasData)
                  ScoreRing(
                    score: snapshot.score,
                    size: 58,
                  )
                else
                  const _WaitingRing(size: 58),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              snapshot.room.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Room options',
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: EdgeColors.muted,
                              size: 20,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editRoom(
                                  context,
                                  state,
                                  snapshot.room,
                                );
                              }

                              if (value == 'delete') {
                                _deleteRoom(
                                  context,
                                  state,
                                  snapshot.room,
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_rounded,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Edit room'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      color: EdgeColors.red,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Delete room'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          StatusChip(
                            label: device.status == DeviceStatus.offline
                                ? 'Offline'
                                : 'Online',
                            color: device.status == DeviceStatus.offline
                                ? EdgeColors.red
                                : EdgeColors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${state.buildingOf(snapshot.room).name} '
                        '· Floor ${snapshot.room.floor}',
                        style: const TextStyle(
                          color: EdgeColors.muted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          StatusChip(
                            label: roomHasData
                                ? '${snapshot.temperature.toStringAsFixed(1)}°C'
                                : '-- °C',
                            color: roomHasData
                                ? EdgeColors.blue
                                : EdgeColors.muted,
                            icon: Icons.thermostat_rounded,
                          ),
                          StatusChip(
                            label: roomHasData
                                ? '${snapshot.humidity.toStringAsFixed(0)}%'
                                : '-- %',
                            color: roomHasData
                                ? EdgeColors.cyan
                                : EdgeColors.muted,
                            icon: Icons.water_drop_rounded,
                          ),
                          StatusChip(
                            label: roomHasData
                                ? snapshot.motion
                                    ? 'Active'
                                    : 'Idle'
                                : '--',
                            color: roomHasData
                                ? snapshot.motion
                                    ? EdgeColors.green
                                    : EdgeColors.muted
                                : EdgeColors.muted,
                            icon: Icons.motion_photos_on_rounded,
                          ),
                          StatusChip(
                            label: roomHasData
                                ? snapshot.statusText
                                : 'Waiting for data',
                            color: statusColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).toList();
  }

  // ============================================================
  // ADD MENU
  // ============================================================

  Future<void> _showAddMenu(
    BuildContext context,
    AppState state,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: EdgeColors.panel,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.add_business_rounded,
                  color: EdgeColors.blue,
                ),
                title: const Text('Add building'),
                subtitle: const Text(
                  'Create a new physical site or building.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext, 'building');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.meeting_room_rounded,
                  color: EdgeColors.green,
                ),
                title: const Text('Add room'),
                subtitle: const Text(
                  'Create a room and assign a device later.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext, 'room');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: EdgeColors.cyan,
                ),
                title: const Text(
                  'Connect ESP32-C3 kit',
                ),
                subtitle: const Text(
                  'Scan, configure Wi-Fi and assign it to a room.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext, 'device');
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case 'building':
        await _addBuilding(context, state);
        break;

      case 'room':
        await _addRoom(context, state);
        break;

      case 'device':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ProvisionDeviceScreen(),
          ),
        );
        break;
    }
  }

  // ============================================================
  // ADD BUILDING
  // ============================================================

  Future<void> _addBuilding(
    BuildContext context,
    AppState state,
  ) async {
    final name = TextEditingController();
    final location = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Building name',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: location,
              decoration: const InputDecoration(
                labelText: 'Location',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final buildingName = name.text.trim();
    final buildingLocation = location.text.trim();

    if (ok == true && buildingName.isNotEmpty) {
      state.addBuilding(
        name: buildingName,
        location: buildingLocation,
      );
    }
  }

  // ============================================================
  // ADD ROOM
  // ============================================================

  Future<void> _addRoom(
    BuildContext context,
    AppState state,
  ) async {
    if (state.buildings.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create a building before adding a room.',
          ),
        ),
      );

      return;
    }

    final name = TextEditingController();
    final floor = TextEditingController(
      text: '1',
    );

    var selected = state.buildings.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Building',
                ),
                items: state.buildings
                    .map(
                      (building) => DropdownMenuItem(
                        value: building.id,
                        child: Text(
                          building.name,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocal(() {
                      selected = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Room name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: floor,
                decoration: const InputDecoration(
                  labelText: 'Floor',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final roomName = name.text.trim();
    final roomFloor = floor.text.trim();

    if (ok == true && roomName.isNotEmpty) {
      state.addRoom(
        buildingId: selected,
        name: roomName,
        floor: roomFloor.isEmpty ? '-' : roomFloor,
      );
    }
  }

  // ============================================================
  // EDIT BUILDING
  // ============================================================

  Future<void> _editBuilding(
    BuildContext context,
    AppState state,
    Building building,
  ) async {
    final name = TextEditingController(
      text: building.name,
    );

    final location = TextEditingController(
      text: building.location,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Building name',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: location,
              decoration: const InputDecoration(
                labelText: 'Location',
              ),
            ),
          ],
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

    final buildingName = name.text.trim();
    final buildingLocation = location.text.trim();

    if (ok == true && buildingName.isNotEmpty) {
      state.editBuilding(
        id: building.id,
        name: buildingName,
        location: buildingLocation,
      );
    }
  }

  // ============================================================
  // DELETE BUILDING
  // ============================================================

  Future<void> _deleteBuilding(
    BuildContext context,
    AppState state,
    Building building,
  ) async {
    final roomCount = state.rooms
        .where(
          (room) => room.buildingId == building.id,
        )
        .length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete building?'),
        content: Text(
          roomCount == 0
              ? 'Are you sure you want to delete "${building.name}"?'
              : 'Are you sure you want to delete "${building.name}"?\n\n'
                  '$roomCount room(s), their assigned devices and stored '
                  'sensor data will also be removed.',
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
      state.deleteBuilding(building.id);
    }
  }

  // ============================================================
  // EDIT ROOM
  // ============================================================

  Future<void> _editRoom(
    BuildContext context,
    AppState state,
    Room room,
  ) async {
    if (state.buildings.isEmpty) {
      return;
    }

    final name = TextEditingController(
      text: room.name,
    );

    final floor = TextEditingController(
      text: room.floor,
    );

    var selectedBuilding = room.buildingId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Edit room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedBuilding,
                decoration: const InputDecoration(
                  labelText: 'Building',
                ),
                items: state.buildings
                    .map(
                      (building) => DropdownMenuItem(
                        value: building.id,
                        child: Text(
                          building.name,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocal(() {
                      selectedBuilding = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Room name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: floor,
                decoration: const InputDecoration(
                  labelText: 'Floor',
                ),
              ),
            ],
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
      ),
    );

    final roomName = name.text.trim();
    final roomFloor = floor.text.trim();

    if (ok == true && roomName.isNotEmpty) {
      state.editRoom(
        roomId: room.id,
        buildingId: selectedBuilding,
        name: roomName,
        floor: roomFloor.isEmpty ? '-' : roomFloor,
      );
    }
  }

  // ============================================================
  // DELETE ROOM
  // ============================================================

  Future<void> _deleteRoom(
    BuildContext context,
    AppState state,
    Room room,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete room?'),
        content: Text(
          'Are you sure you want to delete "${room.name}"?\n\n'
          'The room, its assigned device and stored sensor data '
          'will be removed.',
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
      state.deleteRoom(room.id);
    }
  }
}

class _TwoTabSwitch extends StatelessWidget {
  const _TwoTabSwitch({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(
      String text,
      bool selected,
      bool value,
    ) {
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 160,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFBFD9FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? const Color(0xFF0B2130) : EdgeColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: EdgeColors.panel2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: EdgeColors.stroke,
        ),
      ),
      child: Row(
        children: [
          item(
            left,
            leftSelected,
            true,
          ),
          item(
            right,
            !leftSelected,
            false,
          ),
        ],
      ),
    );
  }
}

class _BuildingThumb extends StatelessWidget {
  const _BuildingThumb({
    required this.seed,
  });

  final int seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: seed.isEven
              ? const [
                  Color(0xFF3B7AB2),
                  Color(0xFF10283A),
                ]
              : const [
                  Color(0xFF376B5D),
                  Color(0xFF10283A),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 11,
            bottom: 10,
            child: Icon(
              Icons.apartment_rounded,
              size: 54,
              color: Colors.white.withValues(
                alpha: .82,
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: EdgeColors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingRing extends StatelessWidget {
  const _WaitingRing({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EdgeColors.panel2,
        border: Border.all(
          color: EdgeColors.stroke,
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.hourglass_top_rounded,
        color: EdgeColors.muted,
        size: 24,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 30,
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: EdgeColors.panel2,
              shape: BoxShape.circle,
              border: Border.all(
                color: EdgeColors.stroke,
              ),
            ),
            child: Icon(
              icon,
              color: EdgeColors.muted,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: EdgeColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
