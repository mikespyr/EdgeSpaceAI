import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/mock_data.dart';
import 'models/models.dart';
import 'services/api_client.dart';
import 'services/app_knowledge.dart';
import 'services/local_advisor.dart';

class AppState extends ChangeNotifier {
  final _advisor = LocalAdvisor();
  final _knowledge = AppKnowledgeBase();
  final _rng = Random();
  Timer? _timer;

  List<Building> buildings = [...MockData.buildings];

  List<Room> rooms = MockData.rooms
      .map(
        (r) => Room(
          id: r.id,
          buildingId: r.buildingId,
          name: r.name,
          floor: r.floor,
          deviceId: r.deviceId,
        ),
      )
      .toList();

  List<DeviceKit> devices = MockData.devices();
  List<SensorPoint> history = MockData.history();
  List<EdgeAlert> alerts = MockData.alerts();

  String backendUrl = 'http://10.0.2.2:8000';
  bool demoMode = true;
  bool useGemini = true;
  bool backendOnline = false;

  String? activeAiModel;
  bool aiFallbackUsed = false;
  bool aiUsingRemote = false;

  RangePreset selectedRange = RangePreset.hour24;
  bool _syncing = false;

  String get aiBadgeLabel {
    if (!useGemini || !backendOnline || !aiUsingRemote) {
      return 'App Guide • Local';
    }

    final friendly = _friendlyAiModel(activeAiModel);
    if (friendly == null) {
      return 'AI • Online';
    }

    return aiFallbackUsed ? '$friendly • Fallback' : '$friendly • Online';
  }

  String? _friendlyAiModel(String? rawModel) {
    final model = rawModel?.trim().toLowerCase();
    if (model == null || model.isEmpty) {
      return null;
    }

    if (model.contains('gemini-3.8-flash')) return 'Gemini 3.8';
    if (model.contains('gemma-4-31b')) return 'Gemma 4 31B';
    if (model.contains('gemma-4-26b')) return 'Gemma 4 26B';
    if (model.contains('gemini-3.5-flash-lite')) return 'Gemini 3.5';
    if (model.contains('gemini-3.1-flash-lite')) return 'Gemini 3.1';
    if (model.contains('gemini')) return 'Gemini';
    if (model.contains('gemma')) return 'Gemma';
    return rawModel;
  }

  void _markLocalAi() {
    aiUsingRemote = false;
    aiFallbackUsed = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    backendUrl = prefs.getString('backendUrl') ?? backendUrl;
    demoMode = prefs.getBool('demoMode') ?? true;
    useGemini = prefs.getBool('useGemini') ?? true;

    _restoreTopology(prefs.getString('topologyJson'));

    unawaited(checkBackend());

    if (!demoMode) {
      history = [];
      alerts = [];
      await syncHistory(range: selectedRange);
    } else {
      _pruneOrphanedState();
    }

    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _tick(),
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOOKUPS
  // ============================================================

  Building buildingOf(Room room) {
    return buildings.firstWhere(
      (b) => b.id == room.buildingId,
    );
  }

  Building? buildingByIdOrNull(String buildingId) {
    for (final building in buildings) {
      if (building.id == buildingId) {
        return building;
      }
    }
    return null;
  }

  DeviceKit deviceOf(Room room) {
    return devices.firstWhere(
      (d) => d.id == room.deviceId,
      orElse: () => DeviceKit(
        id: room.deviceId,
        name: 'Unassigned kit',
        roomId: room.id,
        status: DeviceStatus.offline,
        rssi: -100,
        lastSeen: DateTime.now().subtract(
          const Duration(days: 1),
        ),
      ),
    );
  }

  Room roomById(String roomId) {
    return rooms.firstWhere((r) => r.id == roomId);
  }

  Room? roomByIdOrNull(String roomId) {
    for (final room in rooms) {
      if (room.id == roomId) {
        return room;
      }
    }
    return null;
  }

  DeviceKit? deviceByIdOrNull(String deviceId) {
    for (final device in devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  Room? roomForDevice(String deviceId) {
    for (final room in rooms) {
      if (room.deviceId == deviceId) {
        return room;
      }
    }
    return null;
  }

  bool isRoomAvailableForDevice(
    String roomId, {
    String? exceptDeviceId,
  }) {
    Room? room;
    for (final item in rooms) {
      if (item.id == roomId) {
        room = item;
        break;
      }
    }

    if (room == null) {
      return false;
    }

    if (room.deviceId.startsWith('pending-')) {
      return true;
    }

    return exceptDeviceId != null && room.deviceId == exceptDeviceId;
  }

  // ============================================================
  // TELEMETRY HELPERS
  // ============================================================

  bool hasTelemetry(String roomId) {
    return history.any(
      (point) => point.roomId == roomId,
    );
  }

  bool hasTelemetryType(
    String roomId,
    SensorType type,
  ) {
    return history.any(
      (point) => point.roomId == roomId && point.type == type,
    );
  }

  double? latestOrNull(
    String roomId,
    SensorType type,
  ) {
    SensorPoint? latestPoint;

    for (final point in history) {
      if (point.roomId == roomId &&
          point.type == type &&
          (latestPoint == null ||
              point.timestamp.isAfter(
                latestPoint.timestamp,
              ))) {
        latestPoint = point;
      }
    }

    return latestPoint?.value;
  }

  double latest(
    String roomId,
    SensorType type,
  ) {
    return latestOrNull(roomId, type) ?? 0;
  }

  double? latestInRange(
    String roomId,
    SensorType type,
    RangePreset range,
  ) {
    final points = pointsFor(roomId, type, range: range);
    return points.isEmpty ? null : points.last.value;
  }

  bool hasTelemetryInRange(String roomId, RangePreset range) {
    final from = DateTime.now().subtract(range.duration);
    return history.any(
      (point) => point.roomId == roomId && point.timestamp.isAfter(from),
    );
  }

  List<SensorPoint> pointsFor(
    String roomId,
    SensorType type, {
    RangePreset? range,
  }) {
    final preset = range ?? selectedRange;
    final from = DateTime.now().subtract(
      preset.duration,
    );

    return history
        .where(
          (p) =>
              p.roomId == roomId && p.type == type && p.timestamp.isAfter(from),
        )
        .toList()
      ..sort(
        (a, b) => a.timestamp.compareTo(b.timestamp),
      );
  }

  // ============================================================
  // SNAPSHOTS / SCORES
  // ============================================================

  RoomSnapshot snapshot(Room room) {
    final hasData = hasTelemetry(room.id);

    final t = latest(
      room.id,
      SensorType.temperature,
    );

    final h = latest(
      room.id,
      SensorType.humidity,
    );

    final m = latest(
          room.id,
          SensorType.motion,
        ) >
        .5;

    final n = latest(
      room.id,
      SensorType.noise,
    );

    final score = hasData
        ? calculateRoomScore(
            temperature: t,
            humidity: h,
            noise: n,
          )
        : 0;

    return RoomSnapshot(
      room: room,
      temperature: t,
      humidity: h,
      motion: m,
      noise: n,
      score: score,
      statusText: !hasData
          ? 'Waiting for data'
          : score >= 85
              ? 'Healthy'
              : score >= 65
                  ? 'Needs Attention'
                  : 'Critical',
    );
  }

  RoomSnapshot snapshotForRange(Room room, RangePreset range) {
    final hasData = hasTelemetryInRange(room.id, range);
    final t = latestInRange(room.id, SensorType.temperature, range) ?? 0;
    final h = latestInRange(room.id, SensorType.humidity, range) ?? 0;
    final m = (latestInRange(room.id, SensorType.motion, range) ?? 0) > .5;
    final n = latestInRange(room.id, SensorType.noise, range) ?? 0;

    final score = hasData
        ? calculateRoomScore(
            temperature: t,
            humidity: h,
            noise: n,
          )
        : 0;

    return RoomSnapshot(
      room: room,
      temperature: t,
      humidity: h,
      motion: m,
      noise: n,
      score: score,
      statusText: !hasData
          ? 'Waiting for data'
          : score >= 85
              ? 'Healthy'
              : score >= 65
                  ? 'Needs Attention'
                  : 'Critical',
    );
  }

  List<RoomSnapshot> get snapshots {
    return rooms.map(snapshot).toList();
  }

  List<RoomSnapshot> get snapshotsWithData {
    return rooms.where((room) => hasTelemetry(room.id)).map(snapshot).toList();
  }

  List<DeviceKit> get provisionedDevices {
    return devices.where((d) => !d.id.startsWith('pending-')).toList();
  }

  int get onlineDevices {
    return provisionedDevices
        .where(
          (d) => d.status != DeviceStatus.offline,
        )
        .length;
  }

  int get activeAlerts {
    return alerts.where((a) => !a.acknowledged).length;
  }

  int get averageScore {
    final roomsWithData = rooms.where((room) => hasTelemetry(room.id)).toList();

    if (roomsWithData.isEmpty) {
      return 0;
    }

    final scored = roomsWithData.map(snapshot);

    return (scored.fold<int>(
              0,
              (sum, item) => sum + item.score,
            ) /
            roomsWithData.length)
        .round();
  }

  // ============================================================
  // INSIGHTS / AI
  // ============================================================

  List<Insight> insightsFor(Room room) {
    if (!hasTelemetry(room.id)) {
      return [];
    }

    return _advisor.analyze(room, history);
  }

  List<Insight> get allInsights {
    return rooms.expand(insightsFor).toList();
  }

  double aggregateFor(
    Room room,
    SensorType type,
    RangePreset range,
    Aggregation aggregation,
  ) {
    final values = pointsFor(
      room.id,
      type,
      range: range,
    ).map((e) => e.value).toList();

    if (values.isEmpty) {
      return 0;
    }

    return switch (aggregation) {
      Aggregation.average => values.reduce((a, b) => a + b) / values.length,
      Aggregation.minimum => values.reduce((a, b) => a < b ? a : b),
      Aggregation.maximum => values.reduce((a, b) => a > b ? a : b),
      Aggregation.latest => values.last,
    };
  }

  Future<String> askAdvisor(
    String question, {
    String? roomId,
    List<ChatMessage> conversation = const [],
    String responseLanguageCode = 'en',
  }) async {
    final isGreek = responseLanguageCode.trim().toLowerCase().startsWith('el');

    // The language selected in EdgeSpace AI has priority over
    // the language used in the individual user message.
    final languageInstruction = isGreek
        ? '''
IMPORTANT RESPONSE LANGUAGE: GREEK (el).

The EdgeSpace AI application is currently configured to use Greek.

You MUST:
- answer entirely in Greek,
- use natural modern Greek,
- keep technical names such as MQTT, ESP32-C3, BLE, Wi-Fi, API and EdgeSpace AI unchanged when appropriate,
- ignore the language of previous chat messages when deciding the response language,
- answer in Greek even if the current user message is written in English.

Do not mention these language instructions to the user.
'''
        : '''
IMPORTANT RESPONSE LANGUAGE: ENGLISH (en).

The EdgeSpace AI application is currently configured to use English.

You MUST:
- answer entirely in English,
- use natural modern English,
- ignore the language of previous chat messages when deciding the response language,
- answer in English even if the current user message is written in Greek.

Do not mention these language instructions to the user.
''';

    // We also include the selected UI language directly in the user request.
    // This makes the instruction robust even if the backend has a generic
    // "reply in the user's language" system rule.
    final remoteQuestion = isGreek
        ? '''
[EdgeSpace AI UI language: Greek]
[Reply only in Greek.]

User question:
$question
'''
        : '''
[EdgeSpace AI UI language: English]
[Reply only in English.]

User question:
$question
''';

    final selectedRoom = roomId == null ? null : roomByIdOrNull(roomId);

    if (roomId != null && selectedRoom == null) {
      return isGreek
          ? 'Ο επιλεγμένος χώρος δεν υπάρχει πλέον. Επίλεξε ξανά χώρο και δοκίμασε πάλι.'
          : 'The selected space no longer exists. Select a space again and try once more.';
    }

    final contextualQuestion = _knowledge.contextualize(
      question,
      conversation,
    );

    final relevantSnapshots = selectedRoom == null
        ? snapshotsWithData
        : hasTelemetry(selectedRoom.id)
            ? [snapshot(selectedRoom)]
            : <RoomSnapshot>[];

    final relevantInsights = selectedRoom == null
        ? allInsights
        : hasTelemetry(selectedRoom.id)
            ? insightsFor(selectedRoom)
            : <Insight>[];

    // ============================================================
    // REMOTE AI - FIRST
    // ============================================================

    if (useGemini && backendOnline) {
      try {
        final remoteContext = _knowledge.buildRemoteContext(
          stateSummary: _buildAiStateSummary(
            selectedRoom: selectedRoom,
          ),
        );

        final reply = await ApiClient(
          backendUrl,
        ).askAiDetailed(
          question: remoteQuestion,
          roomId: selectedRoom?.id,
          conversation: conversation,
          appContext: '''
$languageInstruction

$remoteContext
''',
        );

        if (reply.answer.isNotEmpty) {
          activeAiModel = reply.model.isEmpty ? activeAiModel : reply.model;

          aiFallbackUsed = reply.fallbackUsed;
          aiUsingRemote = true;

          notifyListeners();

          return reply.answer;
        }
      } catch (e) {
        debugPrint('EdgeSpace remote AI failed: $e');
      }
    }

    // ============================================================
    // LOCAL APP GUIDE FALLBACK
    // ============================================================

    final appGuideAnswer = _knowledge.answer(
      contextualQuestion,
      buildingCount: buildings.length,
      roomCount: rooms.length,
      provisionedDeviceCount: provisionedDevices.length,
      demoMode: demoMode,
      backendOnline: backendOnline,
      conversation: conversation,
    );

    if (appGuideAnswer != null) {
      _markLocalAi();

      // The existing local knowledge base currently contains mostly
      // Greek deterministic responses. Do not show Greek text while
      // the application is explicitly set to English.
      if (!isGreek) {
        return useGemini
            ? 'The cloud AI is temporarily unavailable. Please try again in a moment.'
            : 'Cloud AI is disabled. Enable the AI Advisor in Settings to ask questions in English.';
      }

      return appGuideAnswer;
    }

    // ============================================================
    // GENERAL LOCAL FALLBACK
    // ============================================================

    if (!_advisor.canAnswer(contextualQuestion)) {
      _markLocalAi();

      if (isGreek) {
        return backendOnline && useGemini
            ? 'Το cloud AI δεν μπόρεσε να απαντήσει αυτή τη στιγμή. Δοκίμασε ξανά σε λίγο.'
            : 'Η ερώτησή σου χρειάζεται το cloud AI για να απαντηθεί σωστά. Αυτή τη στιγμή δεν είναι διαθέσιμο, αλλά μπορώ να σε βοηθήσω με τη χρήση του EdgeSpace AI και με τις μετρήσεις των χώρων.';
      }

      return backendOnline && useGemini
          ? 'The cloud AI could not answer right now. Please try again in a moment.'
          : 'This question requires the cloud AI for a complete answer. It is currently unavailable.';
    }

    // ============================================================
    // NO SENSOR DATA
    // ============================================================

    if (relevantSnapshots.isEmpty) {
      _markLocalAi();

      if (isGreek) {
        return selectedRoom == null
            ? 'Δεν υπάρχουν ακόμη μετρήσεις χώρων για ανάλυση. Μπορείς όμως να με ρωτήσεις οτιδήποτε για το πώς χρησιμοποιείται η εφαρμογή, π.χ. «πώς φτιάχνω νέο δωμάτιο;».'
            : 'Δεν υπάρχουν ακόμη μετρήσεις για το ${selectedRoom.name}. Μπορώ παρ’ όλα αυτά να σε καθοδηγήσω για τις λειτουργίες της εφαρμογής ή τη σύνδεση του kit.';
      }

      return selectedRoom == null
          ? 'There are no space measurements available for analysis yet.'
          : 'There are no measurements available for ${selectedRoom.name} yet.';
    }

    // ============================================================
    // LOCAL SENSOR ADVISOR
    // ============================================================

    _markLocalAi();

    final localAnswer = _advisor.answer(
      contextualQuestion,
      relevantSnapshots,
      relevantInsights,
    );

    if (isGreek) {
      return localAnswer;
    }

    // Current LocalAdvisor responses are primarily Greek.
    // Until LocalAdvisor itself is localized, never display a Greek
    // fallback while the UI language is English.
    return useGemini
        ? 'The cloud AI is temporarily unavailable. Your sensor data are still available in Analytics and the room dashboard.'
        : 'Cloud AI is disabled. Your sensor data are still available in Analytics and the room dashboard.';
  }

  String _buildAiStateSummary({
    Room? selectedRoom,
  }) {
    final buffer = StringBuffer();

    final modeLabel = demoMode ? 'Demo data' : 'Real data';
    final backendLabel = backendOnline ? 'online' : 'offline';

    buffer.writeln('Mode: $modeLabel');
    buffer.writeln('Backend: $backendLabel ($backendUrl)');
    buffer.writeln('Buildings: ${buildings.length}');
    buffer.writeln('Rooms: ${rooms.length}');
    buffer.writeln('Provisioned kits: ${provisionedDevices.length}');
    buffer.writeln('Online kits: $onlineDevices');
    buffer.writeln('Active alerts: $activeAlerts');
    if (selectedRoom != null) {
      buffer.writeln(
          'Selected AI scope: ${selectedRoom.name} (${selectedRoom.id})');
    } else {
      buffer.writeln('Selected AI scope: All spaces');
    }

    buffer.writeln();
    buffer.writeln('Topology and latest room state:');
    for (final room in rooms) {
      final building = buildingByIdOrNull(room.buildingId);
      final device = deviceByIdOrNull(room.deviceId);
      final hasData = hasTelemetry(room.id);
      final roomSnapshot = snapshot(room);

      final buildingName = building?.name ?? 'Unknown building';
      buffer.write('- $buildingName / ${room.name}');
      buffer.write(' | floor ${room.floor}');
      final deviceName = device?.name ?? 'Unassigned';
      final deviceStatus = device?.status.name ?? 'offline';
      buffer.write(' | device $deviceName');
      buffer.write(' ($deviceStatus)');

      if (hasData) {
        buffer
            .write(' | temp ${roomSnapshot.temperature.toStringAsFixed(1)} C');
        buffer
            .write(' | humidity ${roomSnapshot.humidity.toStringAsFixed(0)}%');
        buffer.write(' | noise ${roomSnapshot.noise.toStringAsFixed(0)}');
        final motionLabel = roomSnapshot.motion ? 'active' : 'idle';
        buffer.write(' | motion $motionLabel');
        buffer.write(' | score ${roomSnapshot.score}/100');
        buffer.write(' | ${roomSnapshot.statusText}');
      } else {
        buffer.write(' | Waiting for data');
      }
      buffer.writeln();
    }

    final openAlerts = alerts.where((alert) => !alert.acknowledged).take(8);
    if (openAlerts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Open alerts:');
      for (final alert in openAlerts) {
        final room = roomByIdOrNull(alert.roomId);
        final roomName = room?.name ?? 'Removed room';
        buffer.writeln(
          '- ${alert.severity.name}: ${alert.title} | $roomName | ${alert.message}',
        );
      }
    }

    return buffer.toString().trim();
  }

  // ============================================================
  // BACKEND / SETTINGS
  // ============================================================

  Future<void> checkBackend() async {
    final info = await ApiClient(
      backendUrl,
    ).healthInfo();

    backendOnline = info.online;
    if (info.model != null && info.model!.isNotEmpty) {
      activeAiModel = info.model;
    }

    aiUsingRemote = useGemini && backendOnline;
    if (!backendOnline) {
      aiFallbackUsed = false;
    }

    notifyListeners();
  }

  Future<void> saveSettings({
    required String newBackendUrl,
    required bool newDemoMode,
    required bool newUseGemini,
  }) async {
    final modeChanged = demoMode != newDemoMode;

    backendUrl = newBackendUrl.trim();
    demoMode = newDemoMode;
    useGemini = newUseGemini;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'backendUrl',
      backendUrl,
    );

    await prefs.setBool(
      'demoMode',
      demoMode,
    );

    await prefs.setBool(
      'useGemini',
      useGemini,
    );

    if (modeChanged) {
      history = demoMode ? MockData.history() : [];
      alerts = demoMode ? MockData.alerts() : [];
      _pruneOrphanedState();

      if (!demoMode) {
        await syncHistory(
          range: selectedRange,
        );
      }
    }

    await checkBackend();
    notifyListeners();
  }

  // ============================================================
  // ALERTS
  // ============================================================

  void acknowledgeAlert(String id) {
    for (final alert in alerts) {
      if (alert.id == id) {
        alert.acknowledged = true;
        notifyListeners();
        return;
      }
    }
  }

  // ============================================================
  // BUILDING CRUD
  // ============================================================

  void addBuilding({
    required String name,
    String location = '',
  }) {
    final id = 'b${DateTime.now().microsecondsSinceEpoch}';

    buildings.add(
      Building(
        id: id,
        name: name,
        location: location,
      ),
    );

    unawaited(_persistTopology());
    notifyListeners();
  }

  void editBuilding({
    required String id,
    required String name,
    String location = '',
  }) {
    final index = buildings.indexWhere(
      (b) => b.id == id,
    );

    if (index == -1) {
      return;
    }

    buildings[index] = Building(
      id: id,
      name: name,
      location: location,
    );

    unawaited(_persistTopology());
    notifyListeners();
  }

  void deleteBuilding(String buildingId) {
    final buildingRooms = rooms
        .where(
          (r) => r.buildingId == buildingId,
        )
        .toList();

    final roomIds = buildingRooms.map((r) => r.id).toSet();

    final deviceIds = buildingRooms.map((r) => r.deviceId).toSet();

    history.removeWhere(
      (p) => roomIds.contains(p.roomId),
    );

    alerts.removeWhere(
      (alert) => roomIds.contains(alert.roomId),
    );

    devices.removeWhere(
      (d) => roomIds.contains(d.roomId) || deviceIds.contains(d.id),
    );

    rooms.removeWhere(
      (r) => r.buildingId == buildingId,
    );

    buildings.removeWhere(
      (b) => b.id == buildingId,
    );

    unawaited(_persistTopology());
    notifyListeners();
  }

  // ============================================================
  // ROOM CRUD
  // ============================================================

  void addRoom({
    required String buildingId,
    required String name,
    required String floor,
  }) {
    final buildingExists = buildings.any(
      (building) => building.id == buildingId,
    );

    if (!buildingExists) {
      return;
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;

    final roomId = 'r$stamp';
    final pendingDeviceId = 'pending-$stamp';

    rooms.add(
      Room(
        id: roomId,
        buildingId: buildingId,
        name: name,
        floor: floor,
        deviceId: pendingDeviceId,
      ),
    );

    devices.add(
      DeviceKit(
        id: pendingDeviceId,
        name: 'No kit assigned',
        roomId: roomId,
        status: DeviceStatus.offline,
        rssi: -100,
        lastSeen: DateTime.now().subtract(
          const Duration(days: 1),
        ),
      ),
    );

    unawaited(_persistTopology());
    notifyListeners();
  }

  void editRoom({
    required String roomId,
    required String buildingId,
    required String name,
    required String floor,
  }) {
    final index = rooms.indexWhere(
      (r) => r.id == roomId,
    );

    if (index == -1) {
      return;
    }

    final buildingExists = buildings.any(
      (building) => building.id == buildingId,
    );

    if (!buildingExists) {
      return;
    }

    final oldRoom = rooms[index];

    rooms[index] = Room(
      id: oldRoom.id,
      buildingId: buildingId,
      name: name,
      floor: floor,
      deviceId: oldRoom.deviceId,
    );

    unawaited(_persistTopology());
    notifyListeners();
  }

  void deleteRoom(String roomId) {
    final index = rooms.indexWhere(
      (r) => r.id == roomId,
    );

    if (index == -1) {
      return;
    }

    final room = rooms[index];

    history.removeWhere(
      (p) => p.roomId == roomId,
    );

    alerts.removeWhere(
      (alert) => alert.roomId == roomId,
    );

    devices.removeWhere(
      (d) => d.roomId == roomId || d.id == room.deviceId,
    );

    rooms.removeAt(index);

    unawaited(_persistTopology());
    notifyListeners();
  }

  // ============================================================
  // DEVICE MANAGEMENT / PROVISIONING
  // ============================================================

  void addProvisionedDevice({
    required String id,
    required String roomId,
    required String name,
    int rssi = -50,
    String firmware = '1.0.0',
  }) {
    final roomIndex = rooms.indexWhere((r) => r.id == roomId);
    if (roomIndex == -1) {
      throw StateError('The selected room no longer exists.');
    }

    final targetRoom = rooms[roomIndex];

    if (!targetRoom.deviceId.startsWith('pending-') &&
        targetRoom.deviceId != id) {
      throw StateError('The selected room already has a device assigned.');
    }

    final existingRoom = roomForDevice(id);
    if (existingRoom != null && existingRoom.id != targetRoom.id) {
      _setRoomPending(existingRoom);
    }

    final oldTargetId = targetRoom.deviceId;
    if (oldTargetId.startsWith('pending-')) {
      devices.removeWhere((d) => d.id == oldTargetId);
    }

    devices.removeWhere((d) => d.id == id);

    targetRoom.deviceId = id;

    devices.add(
      DeviceKit(
        id: id,
        name: name.trim().isEmpty ? 'EdgeSpace Kit' : name.trim(),
        roomId: roomId,
        status: DeviceStatus.online,
        rssi: rssi,
        lastSeen: DateTime.now(),
        firmware: firmware,
      ),
    );

    unawaited(_persistTopology());
    notifyListeners();
  }

  void renameDevice({
    required String deviceId,
    required String name,
  }) {
    final device = deviceByIdOrNull(deviceId);
    if (device == null || device.id.startsWith('pending-')) {
      return;
    }

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return;
    }

    device.name = cleanName;
    unawaited(_persistTopology());
    notifyListeners();
  }

  void moveDevice({
    required String deviceId,
    required String newRoomId,
  }) {
    final device = deviceByIdOrNull(deviceId);
    if (device == null || device.id.startsWith('pending-')) {
      return;
    }

    final targetIndex = rooms.indexWhere((r) => r.id == newRoomId);
    if (targetIndex == -1) {
      throw StateError('The selected room no longer exists.');
    }

    final targetRoom = rooms[targetIndex];
    final currentRoom = roomForDevice(deviceId);

    if (currentRoom?.id == targetRoom.id) {
      return;
    }

    if (!targetRoom.deviceId.startsWith('pending-')) {
      throw StateError('The selected room already has a device assigned.');
    }

    if (currentRoom != null) {
      _setRoomPending(currentRoom);
    }

    devices.removeWhere(
      (d) => d.id == targetRoom.deviceId && d.id.startsWith('pending-'),
    );

    targetRoom.deviceId = device.id;
    device.roomId = targetRoom.id;

    unawaited(_persistTopology());
    notifyListeners();
  }

  void disconnectDevice(String deviceId) {
    final device = deviceByIdOrNull(deviceId);
    if (device == null || device.id.startsWith('pending-')) {
      return;
    }

    device.status = DeviceStatus.offline;
    unawaited(_persistTopology());
    notifyListeners();
  }

  void deleteDevice(String deviceId) {
    final device = deviceByIdOrNull(deviceId);
    if (device == null || device.id.startsWith('pending-')) {
      return;
    }

    final assignedRoom = roomForDevice(deviceId);
    devices.removeWhere((d) => d.id == deviceId);

    if (assignedRoom != null) {
      _setRoomPending(assignedRoom);
    }

    unawaited(_persistTopology());
    notifyListeners();
  }

  void _setRoomPending(Room room) {
    devices.removeWhere(
      (d) => d.roomId == room.id && d.id.startsWith('pending-'),
    );

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final pendingId = 'pending-${room.id}-$stamp';

    room.deviceId = pendingId;

    devices.add(
      DeviceKit(
        id: pendingId,
        name: 'No kit assigned',
        roomId: room.id,
        status: DeviceStatus.offline,
        rssi: -100,
        lastSeen: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
  }

  // ============================================================
  // BACKEND TELEMETRY SYNC
  // ============================================================

  Future<void> syncHistory({
    String? roomId,
    RangePreset? range,
  }) async {
    if (_syncing || demoMode) {
      return;
    }

    _syncing = true;

    try {
      final preset = range ?? selectedRange;

      final hours = switch (preset) {
        RangePreset.hour24 => 24,
        RangePreset.day7 => 24 * 7,
        RangePreset.day30 => 24 * 30,
        RangePreset.custom => 24 * 7,
      };

      final targets =
          roomId == null ? rooms : rooms.where((r) => r.id == roomId).toList();

      final api = ApiClient(backendUrl);

      for (final room in targets) {
        final points = await api.fetchTelemetry(
          roomId: room.id,
          hours: hours,
        );

        history.removeWhere(
          (p) => p.roomId == room.id,
        );

        history.addAll(points);
      }
    } catch (_) {
      // Keep existing data so temporary network failures do not
      // blank the UI.
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncLatest() async {
    if (_syncing || demoMode) {
      return;
    }

    _syncing = true;

    try {
      final api = ApiClient(backendUrl);

      for (final room in rooms) {
        final points = await api.fetchLatest(
          room.id,
        );

        if (points.isEmpty) {
          final device = deviceByIdOrNull(room.deviceId);
          if (device != null &&
              !device.id.startsWith('pending-') &&
              DateTime.now().difference(device.lastSeen) >
                  const Duration(seconds: 90)) {
            device.status = DeviceStatus.offline;
          }
          continue;
        }

        final newestTs = points.first.timestamp;

        history.removeWhere(
          (p) =>
              p.roomId == room.id &&
              p.timestamp.isAtSameMomentAs(
                newestTs,
              ),
        );

        history.addAll(points);

        final device = deviceOf(room);
        device.status = DeviceStatus.online;
        device.lastSeen = DateTime.now();
      }
    } catch (_) {
      // The next timer cycle retries automatically.
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // ============================================================
  // DEMO DATA TICK
  // ============================================================

  void _tick() {
    if (!demoMode) {
      unawaited(_syncLatest());
      return;
    }

    final now = DateTime.now();

    for (final room in rooms) {
      final device = deviceOf(room);

      if (device.status == DeviceStatus.offline) {
        continue;
      }

      final prevT = latestOrNull(
            room.id,
            SensorType.temperature,
          ) ??
          22.0;

      final prevH = latestOrNull(
            room.id,
            SensorType.humidity,
          ) ??
          45.0;

      final prevN = latestOrNull(
            room.id,
            SensorType.noise,
          ) ??
          300.0;

      final active = _rng.nextDouble() > .56;

      history.add(
        SensorPoint(
          roomId: room.id,
          type: SensorType.temperature,
          value: (prevT + (_rng.nextDouble() - .48) * .22)
              .clamp(16, 34)
              .toDouble(),
          timestamp: now,
        ),
      );

      history.add(
        SensorPoint(
          roomId: room.id,
          type: SensorType.humidity,
          value:
              (prevH + (_rng.nextDouble() - .5) * .9).clamp(20, 85).toDouble(),
          timestamp: now,
        ),
      );

      history.add(
        SensorPoint(
          roomId: room.id,
          type: SensorType.noise,
          value: (prevN + (_rng.nextDouble() - .5) * 55 + (active ? 18 : -12))
              .clamp(100, 1100)
              .toDouble(),
          timestamp: now,
        ),
      );

      history.add(
        SensorPoint(
          roomId: room.id,
          type: SensorType.motion,
          value: active ? 1 : 0,
          timestamp: now,
        ),
      );

      device.lastSeen = now;

      device.rssi = (device.rssi + _rng.nextInt(5) - 2).clamp(-90, -35).toInt();
    }

    final cutoff = now.subtract(
      const Duration(days: 35),
    );

    history.removeWhere(
      (p) => p.timestamp.isBefore(cutoff),
    );

    notifyListeners();
  }

  void _pruneOrphanedState() {
    final roomIds = rooms.map((room) => room.id).toSet();
    final assignedDeviceIds = rooms.map((room) => room.deviceId).toSet();

    history.removeWhere((point) => !roomIds.contains(point.roomId));
    alerts.removeWhere((alert) => !roomIds.contains(alert.roomId));
    devices.removeWhere(
      (device) => !assignedDeviceIds.contains(device.id),
    );
  }

  // ============================================================
  // LOCAL PERSISTENCE
  // ============================================================

  Future<void> _persistTopology() async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'buildings': buildings
          .map(
            (b) => {
              'id': b.id,
              'name': b.name,
              'location': b.location,
              'description': b.description,
            },
          )
          .toList(),
      'rooms': rooms
          .map(
            (r) => {
              'id': r.id,
              'buildingId': r.buildingId,
              'name': r.name,
              'floor': r.floor,
              'deviceId': r.deviceId,
            },
          )
          .toList(),
      'devices': devices
          .map(
            (d) => {
              'id': d.id,
              'name': d.name,
              'roomId': d.roomId,
              'status': d.status.name,
              'rssi': d.rssi,
              'lastSeen': d.lastSeen.toIso8601String(),
              'firmware': d.firmware,
              'uptimeHours': d.uptimeHours,
            },
          )
          .toList(),
    };

    await prefs.setString(
      'topologyJson',
      jsonEncode(data),
    );
  }

  void _restoreTopology(String? raw) {
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final restoredBuildings = (data['buildings'] as List?)
          ?.map(
            (e) => Building(
              id: e['id'],
              name: e['name'],
              location: e['location'] ?? '',
              description: e['description'] ?? '',
            ),
          )
          .toList();

      final restoredRooms = (data['rooms'] as List?)
          ?.map(
            (e) => Room(
              id: e['id'],
              buildingId: e['buildingId'],
              name: e['name'],
              floor: e['floor'],
              deviceId: e['deviceId'],
            ),
          )
          .toList();

      final restoredDevices = (data['devices'] as List?)?.map(
        (e) {
          final rawStatus = e['status']?.toString();
          final status = DeviceStatus.values.firstWhere(
            (value) => value.name == rawStatus,
            orElse: () => DeviceStatus.offline,
          );

          return DeviceKit(
            id: e['id'],
            name: e['name'] ?? 'EdgeSpace Kit',
            roomId: e['roomId'],
            status: status,
            rssi: (e['rssi'] as num?)?.toInt() ?? -100,
            lastSeen: DateTime.tryParse(
                  e['lastSeen']?.toString() ?? '',
                ) ??
                DateTime.now().subtract(const Duration(days: 1)),
            firmware: e['firmware'] ?? '1.0.0',
            uptimeHours: (e['uptimeHours'] as num?)?.toDouble() ?? 0,
          );
        },
      ).toList();

      if (restoredBuildings != null) {
        buildings = restoredBuildings;
      }

      if (restoredRooms != null) {
        rooms = restoredRooms;
      }

      if (restoredDevices != null) {
        devices = restoredDevices;
      } else if (restoredRooms != null) {
        final existingDevices = {
          for (final device in devices) device.id: device,
        };

        devices = [];

        for (final room in rooms) {
          final existing = existingDevices[room.deviceId];
          if (existing != null) {
            existing.roomId = room.id;
            devices.add(existing);
          } else {
            devices.add(
              DeviceKit(
                id: room.deviceId,
                name: room.deviceId.startsWith('pending-')
                    ? 'No kit assigned'
                    : 'Edge Kit',
                roomId: room.id,
                status: DeviceStatus.offline,
                rssi: -100,
                lastSeen: DateTime.now().subtract(const Duration(days: 1)),
              ),
            );
          }
        }
      }

      // Guarantee that every room always has a matching device record.
      for (final room in rooms) {
        final matching = deviceByIdOrNull(room.deviceId);
        if (matching != null) {
          matching.roomId = room.id;
          continue;
        }

        devices.add(
          DeviceKit(
            id: room.deviceId,
            name: room.deviceId.startsWith('pending-')
                ? 'No kit assigned'
                : 'Edge Kit',
            roomId: room.id,
            status: DeviceStatus.offline,
            rssi: -100,
            lastSeen: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
      }

      _pruneOrphanedState();
    } catch (_) {
      // Ignore corrupt local topology and keep the demo dataset.
    }
  }
}
