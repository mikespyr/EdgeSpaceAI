import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class AiReply {
  const AiReply({
    required this.answer,
    required this.model,
    required this.fallbackUsed,
  });

  final String answer;
  final String model;
  final bool fallbackUsed;
}

class BackendHealthInfo {
  const BackendHealthInfo({
    required this.online,
    this.model,
    this.fallbackModels = const [],
  });

  final bool online;
  final String? model;
  final List<String> fallbackModels;
}

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final clean = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$clean$path').replace(queryParameters: query);
  }

  Future<BackendHealthInfo> healthInfo() async {
    try {
      final response = await http
          .get(_uri('/health'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 300) {
        return const BackendHealthInfo(online: false);
      }

      String? model;
      var fallbackModels = <String>[];

      try {
        final data = (jsonDecode(response.body) as Map).cast<String, dynamic>();
        final rawModel = '${data['gemini_model'] ?? ''}'.trim();
        model = rawModel.isEmpty ? null : rawModel;

        final rawFallbacks = data['gemini_fallback_models'];
        if (rawFallbacks is List) {
          fallbackModels = rawFallbacks
              .map((item) => '$item'.trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // Older backend health payloads may not expose model metadata.
      }

      return BackendHealthInfo(
        online: true,
        model: model,
        fallbackModels: fallbackModels,
      );
    } catch (_) {
      return const BackendHealthInfo(online: false);
    }
  }

  Future<bool> health() async {
    return (await healthInfo()).online;
  }

  Future<void> registerDevice({required String deviceId, required String roomId, String? name}) async {
    final response = await http.post(
      _uri('/api/v1/devices/register'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'device_id': deviceId, 'room_id': roomId, 'name': name}),
    );
    if (response.statusCode >= 300) throw Exception('Device registration failed (${response.statusCode})');
  }

  Future<List<SensorPoint>> fetchTelemetry({required String roomId, required int hours}) async {
    final response = await http.get(_uri('/api/v1/rooms/$roomId/telemetry', {'hours': '$hours'})).timeout(const Duration(seconds: 8));
    if (response.statusCode >= 300) throw Exception('Telemetry request failed (${response.statusCode})');
    final rows = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    return _rowsToPoints(roomId, rows);
  }

  Future<List<SensorPoint>> fetchLatest(String roomId) async {
    final response = await http.get(_uri('/api/v1/rooms/$roomId/latest')).timeout(const Duration(seconds: 5));
    if (response.statusCode == 404) return [];
    if (response.statusCode >= 300) throw Exception('Latest telemetry failed (${response.statusCode})');
    final row = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    return _rowsToPoints(roomId, [row]);
  }

  Future<AiReply> askAiDetailed({
    required String question,
    String? roomId,
    String? appContext,
    List<ChatMessage> conversation = const [],
  }) async {
    final recentConversation = conversation.length > 12
        ? conversation.sublist(conversation.length - 12)
        : conversation;

    final response = await http
        .post(
          _uri('/api/v1/ai/chat'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'question': question,
            'room_id': roomId,
            'app_context': appContext,
            'conversation': recentConversation
                .map(
                  (message) => {
                    'role': message.fromUser ? 'user' : 'assistant',
                    'text': message.text,
                  },
                )
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode >= 300) {
      final detail = response.body.isEmpty ? 'AI request failed' : response.body;
      throw Exception(detail);
    }

    final data = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    final answer = '${data['answer'] ?? ''}'.trim();
    final model = '${data['model'] ?? ''}'.trim();
    final fallbackUsed = data['fallback_used'] == true;

    return AiReply(
      answer: answer,
      model: model,
      fallbackUsed: fallbackUsed,
    );
  }

  Future<String> askAi({
    required String question,
    String? roomId,
    String? appContext,
    List<ChatMessage> conversation = const [],
  }) async {
    final result = await askAiDetailed(
      question: question,
      roomId: roomId,
      appContext: appContext,
      conversation: conversation,
    );
    return result.answer;
  }

  List<SensorPoint> _rowsToPoints(String roomId, List<Map<String, dynamic>> rows) {
    final points = <SensorPoint>[];
    for (final row in rows) {
      final ts = DateTime.tryParse('${row['ts']}')?.toLocal() ?? DateTime.now();
      void add(SensorType type, dynamic value) {
        if (value == null) return;
        final numeric = type == SensorType.motion ? ((value == true || value == 1) ? 1.0 : 0.0) : (value as num).toDouble();
        points.add(SensorPoint(roomId: roomId, type: type, value: numeric, timestamp: ts));
      }
      add(SensorType.temperature, row['temperature']);
      add(SensorType.humidity, row['humidity']);
      add(SensorType.motion, row['motion']);
      add(SensorType.noise, row['noise']);
    }
    return points;
  }
}
