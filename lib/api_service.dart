import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';

class ApiService {
  static const String baseUrl = 'https://voice-quality-analyst.onrender.com/api';             //'http://localhost:3000/api';api

  Future<Map<String, dynamic>> createJob({
    required String model,
    required String mode,
    required String languageCode,
    required bool withDiarization,
    required int numSpeakers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stt/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'mode': mode,
          'languageCode': languageCode,
          'withDiarization': withDiarization,
          'numSpeakers': numSpeakers,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create job: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating job: $e');
    }
  }

  Future<Map<String, dynamic>> uploadFilesWeb(
      String jobId,
      FilePickerResult result,
      ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/stt/$jobId/upload'),
      );

      for (var file in result.files) {
        final multipartFile = http.MultipartFile.fromBytes(
          'files',
          file.bytes!,
          filename: file.name,
          contentType: MediaType('audio', _getContentType(file.name)),
        );

        request.files.add(multipartFile);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        throw Exception('Failed to upload files: $responseBody');
      }
    } catch (e) {
      throw Exception('Error uploading files: $e');
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'mp3':
        return 'mpeg';
      case 'wav':
        return 'wav';
      case 'flac':
        return 'flac';
      case 'm4a':
        return 'mp4';
      case 'aac':
        return 'aac';
      case 'ogg':
        return 'ogg';
      default:
        return 'mpeg';
    }
  }

  Future<Map<String, dynamic>> startJob(String jobId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stt/$jobId/start'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to start job: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error starting job: $e');
    }
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stt/$jobId/status'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get job status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting job status: $e');
    }
  }

  Future<Map<String, dynamic>> getJobResults(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stt/$jobId/results'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get results: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting results: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeQuality({
    required String transcript,
    required List<dynamic> diarizedTranscript,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quality/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transcript': transcript,
          'diarizedTranscript': diarizedTranscript,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to analyze quality: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error analyzing quality: $e');
    }
  }

  static const String localGemmaProxyUrl = 'http://localhost:3001/api/local-gemma/analyze';

  Future<Map<String, dynamic>> analyzeTranscriptWithAI({
    required List<Map<String, dynamic>> diarizedTranscript,
  }) async {
    try {
      if (diarizedTranscript.isEmpty) {
        throw Exception('Transcript is empty. Nothing to analyze.');
      }

      final response = await http.post(
        Uri.parse(localGemmaProxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'diarizedTranscript': diarizedTranscript,
        }),
      );

      final data = response.body.trim().isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200 && data['success'] == true) {
        final analysis = Map<String, dynamic>.from(data['analysis'] as Map);

        analysis['speaker0_rating'] = _normalizeScore(
          analysis['speaker0_rating'] ?? analysis['rating'] ?? analysis['score'],
        );
        analysis['summary'] = analysis['summary']?.toString() ?? '';
        analysis['score_table'] = _normalizeListOfMaps(analysis['score_table']);
        analysis['strong_points'] = _normalizeStringList(analysis['strong_points']);
        analysis['weak_points'] = _normalizeStringList(analysis['weak_points']);
        analysis['suggestions'] = _normalizeStringList(
          analysis['suggestions'] ?? analysis['improvement_suggestions'],
        );

        return analysis;
      }

      throw Exception(data['error'] ?? 'Failed to analyze transcript with local Gemma proxy');
    } catch (e) {
      throw Exception('Error analyzing transcript with local Gemma proxy: $e');
    }
  }

  double _normalizeScore(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    if (parsed < 0) return 0;
    if (parsed > 10) return 10;
    return double.parse(parsed.toStringAsFixed(1));
  }

  List<Map<String, dynamic>> _normalizeListOfMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value.whereType<Map>().map((item) {
      final row = Map<String, dynamic>.from(item);
      row['metric'] = row['metric']?.toString() ?? '';
      row['score'] = _normalizeScore(row['score']);
      row['reason'] = row['reason']?.toString() ?? '';
      return row;
    }).toList();
  }

  List<String> _normalizeStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }



  Future<Map<String, dynamic>> saveConversation({
    required String conversationText,
    required String remark,
    required String phoneNo,
    required String rating,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://test.bhagyag.com/api/Conversation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'conversationText': conversationText,
          'remark': remark,
          'phoneNo': phoneNo,
          'rating': rating,
        }),
      );

      final responseBody = response.body.trim();
      final decodedBody = responseBody.isNotEmpty
          ? jsonDecode(responseBody)
          : <String, dynamic>{'success': true};

      if (response.statusCode == 200 || response.statusCode == 201) {
        return decodedBody is Map<String, dynamic>
            ? decodedBody
            : <String, dynamic>{'success': true, 'data': decodedBody};
      }

      throw Exception('Failed to save conversation: ${response.body}');
    } catch (e) {
      throw Exception('Error saving conversation: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await http.get(
        Uri.parse('https://test.bhagyag.com/api/Conversation'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = response.body.trim();
        if (responseBody.isEmpty) {
          return <Map<String, dynamic>>[];
        }

        final decodedBody = jsonDecode(responseBody);

        if (decodedBody is List) {
          return decodedBody
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }

        if (decodedBody is Map && decodedBody['data'] is List) {
          return (decodedBody['data'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }

        return <Map<String, dynamic>>[];
      }

      throw Exception(
        'Failed to get conversations: ${response.statusCode} ${response.body}',
      );
    } catch (e) {
      throw Exception('Error getting conversations: $e');
    }
  }

}