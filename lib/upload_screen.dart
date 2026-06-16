import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'file_upload_widget.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const String _transcriptStorageKey = 'latest_diarized_transcript';
  static const String _aiAnalysisStorageKey = 'latest_ai_analysis';
  static const String _recordingFileNameStorageKey = 'latest_recording_file_name';

  final ScrollController _transcriptScrollController = ScrollController();

  List<Map<String, dynamic>> diarizedTranscript = [];
  Map<String, dynamic>? aiAnalysis;
  String? currentRecordingFileName;

  bool isAiAnalyzing = false;
  String? aiError;

  @override
  void initState() {
    super.initState();
    _loadSavedTranscript();
    _loadSavedAiAnalysis();
    _loadSavedRecordingFileName();
  }

  @override
  void dispose() {
    _transcriptScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTranscript() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_transcriptStorageKey);

    if (savedData == null || savedData.isEmpty) return;

    try {
      final decoded = jsonDecode(savedData);

      if (decoded is List) {
        setState(() {
          diarizedTranscript = decoded
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        });
      }
    } catch (_) {
      await prefs.remove(_transcriptStorageKey);
    }
  }

  Future<void> _loadSavedAiAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_aiAnalysisStorageKey);

    if (savedData == null || savedData.isEmpty) return;

    try {
      final decoded = jsonDecode(savedData);

      if (decoded is Map) {
        setState(() {
          aiAnalysis = Map<String, dynamic>.from(decoded);
        });
      }
    } catch (_) {
      await prefs.remove(_aiAnalysisStorageKey);
    }
  }

  Future<void> _loadSavedRecordingFileName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_recordingFileNameStorageKey);

    if (savedData == null || savedData.isEmpty) return;

    setState(() {
      currentRecordingFileName = savedData;
    });
  }

  Future<void> _saveTranscript(
      List<Map<String, dynamic>> transcript,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _transcriptStorageKey,
      jsonEncode(transcript),
    );
  }

  Future<void> _saveAiAnalysis(Map<String, dynamic> analysis) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _aiAnalysisStorageKey,
      jsonEncode(analysis),
    );
  }

  Future<void> _saveRecordingFileName(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordingFileNameStorageKey, fileName);
  }

  void _handleAnalysisCompleted(Map<String, dynamic> result) {
    final normalizedTranscript = _extractDiarizedTranscript(result);
    final uploadedFileName = result['uploaded_file_name']?.toString() ?? '';

    setState(() {
      diarizedTranscript = normalizedTranscript;
      currentRecordingFileName = uploadedFileName;
      aiAnalysis = null;
      aiError = null;
    });

    _saveTranscript(normalizedTranscript);
    _saveRecordingFileName(uploadedFileName);
    _clearSavedAiAnalysisOnly();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_transcriptScrollController.hasClients) {
        _transcriptScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> _extractDiarizedTranscript(
      Map<String, dynamic> result,
      ) {
    final diarizedData = result['diarized_transcript'];

    if (diarizedData is List) {
      return diarizedData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    if (diarizedData is Map && diarizedData['entries'] is List) {
      return (diarizedData['entries'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return [];
  }

  Future<void> _clearSavedAiAnalysisOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aiAnalysisStorageKey);
  }

  Future<void> _clearTranscript() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_transcriptStorageKey);
    await prefs.remove(_aiAnalysisStorageKey);
    await prefs.remove(_recordingFileNameStorageKey);

    setState(() {
      diarizedTranscript = [];
      currentRecordingFileName = null;
      aiAnalysis = null;
      aiError = null;
    });
  }

  Future<void> _analyzeWithAI() async {
    if (diarizedTranscript.isEmpty || isAiAnalyzing) return;

    setState(() {
      isAiAnalyzing = true;
      aiError = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      final analysis = await apiService.analyzeTranscriptWithAI(
        diarizedTranscript: diarizedTranscript,
      );

      setState(() {
        aiAnalysis = analysis;
      });

      await _saveAiAnalysis(analysis);

      await apiService.saveConversation(
        conversationText: _buildConversationText(),
        remark: _buildFullRemark(analysis),
        phoneNo: currentRecordingFileName ?? '',
        rating: _extractRating(analysis),
      );
    } catch (e) {
      setState(() {
        aiError = e.toString();
      });
    } finally {
      setState(() {
        isAiAnalyzing = false;
      });
    }
  }


  String _buildConversationText() {
    return diarizedTranscript
        .map((item) {
      final speakerId = item['speaker_id']?.toString() ?? '';
      final transcript = item['transcript']?.toString().trim() ?? '';

      if (transcript.isEmpty) return '';
      return 'Speaker $speakerId: $transcript';
    })
        .where((line) => line.isNotEmpty)
        .join('');
    }

  String _extractRating(Map<String, dynamic> analysis) {
    return analysis['speaker0_rating']?.toString() ??
        analysis['rating']?.toString() ??
        analysis['score']?.toString() ??
        '0';
  }

  String _buildFullRemark(Map<String, dynamic> analysis) {
    final buffer = StringBuffer();
    final summary = analysis['summary']?.toString().trim() ?? '';
    final scoreTable = analysis['score_table'] as List? ?? [];
    final weakPoints = analysis['weak_points'] as List? ?? [];
    final suggestions = analysis['suggestions'] as List? ?? [];

    if (summary.isNotEmpty) {
      buffer.writeln('Summary: $summary');
    }

    if (scoreTable.isNotEmpty) {
      buffer.writeln('Score Details:');
      for (final item in scoreTable) {
        final row = Map<String, dynamic>.from(item as Map);
        final metric = row['metric']?.toString() ?? '';
        final score = row['score']?.toString() ?? '';
        final reason = row['reason']?.toString() ?? '';
        buffer.writeln('- $metric: $score - $reason');
      }
    }

    if (weakPoints.isNotEmpty) {
      buffer.writeln('Weak Points:');
      for (final point in weakPoints) {
        buffer.writeln('- ${point.toString()}');
      }
    }

    if (suggestions.isNotEmpty) {
      buffer.writeln('Suggestions:');
      for (final suggestion in suggestions) {
        buffer.writeln('- ${suggestion.toString()}');
      }
    }

    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height - 210;

    return Container(
      color: const Color(0xFFF9FAFB),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Audio Files',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload conversation recordings for analysis',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          FileUploadWidget(
                            onAnalysisCompleted: _handleAnalysisCompleted,
                          ),
                          const SizedBox(height: 24),
                          _buildConfigurationCard(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: availableHeight,
                      child: Column(
                        children: [
                          Expanded(
                            flex: aiAnalysis == null ? 1 : 2,
                            child: _buildTranscriptPanel(),
                          ),
                          if (diarizedTranscript.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildAnalyzeButton(),
                          ],
                          if (aiError != null) ...[
                            const SizedBox(height: 8),
                            _buildErrorBox(),
                          ],
                          if (aiAnalysis != null) ...[
                            const SizedBox(height: 12),
                            Expanded(
                              flex: 1,
                              child: _buildAiAnalysisPanel(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isAiAnalyzing ? null : _analyzeWithAI,
        icon: isAiAnalyzing
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(
          isAiAnalyzing
              ? 'Analyzing Speaker 0...'
              : aiAnalysis == null
              ? 'Analyze Speaker 0 with AI'
              : 'Analyze Again',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(
        aiError ?? '',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.red.shade700,
        ),
      ),
    );
  }

  Widget _buildTranscriptPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conversation Transcript',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ),
                if (diarizedTranscript.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearTranscript,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: diarizedTranscript.isEmpty
                  ? Center(
                child: Text(
                  'Transcript will appear here after audio processing is completed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              )
                  : Scrollbar(
                controller: _transcriptScrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _transcriptScrollController,
                  padding: const EdgeInsets.only(right: 12),
                  itemCount: diarizedTranscript.length,
                  itemBuilder: (context, index) {
                    final item = diarizedTranscript[index];

                    final speakerId =
                        item['speaker_id']?.toString() ?? '';
                    final transcript =
                        item['transcript']?.toString() ?? '';

                    final isSpeakerZero = speakerId == '0';

                    return Align(
                      alignment: isSpeakerZero
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(
                          maxWidth: 420,
                        ),
                        decoration: BoxDecoration(
                          color: isSpeakerZero
                              ? Colors.blue.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSpeakerZero
                                ? Colors.blue.shade100
                                : Colors.green.shade100,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speaker $speakerId',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSpeakerZero
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              transcript,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisPanel() {
    final rating = aiAnalysis?['speaker0_rating']?.toString() ?? '0';
    final summary = aiAnalysis?['summary']?.toString() ?? '';
    final scoreTable = aiAnalysis?['score_table'] as List? ?? [];
    final weakPoints = aiAnalysis?['weak_points'] as List? ?? [];
    final suggestions = aiAnalysis?['suggestions'] as List? ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Speaker 0 AI Analysis',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$rating / 10',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                const SizedBox(height: 12),
                if (scoreTable.isNotEmpty)
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(0.6),
                      2: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                        ),
                        children: [
                          _tableCell('Metric', isHeader: true),
                          _tableCell('Score', isHeader: true),
                          _tableCell('Reason', isHeader: true),
                        ],
                      ),
                      ...scoreTable.map((item) {
                        final row = Map<String, dynamic>.from(item as Map);

                        return TableRow(
                          children: [
                            _tableCell(row['metric']?.toString() ?? ''),
                            _tableCell(row['score']?.toString() ?? ''),
                            _tableCell(row['reason']?.toString() ?? ''),
                          ],
                        );
                      }),
                    ],
                  ),
                if (weakPoints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Weak Points',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...weakPoints.map(
                        (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${point.toString()}',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ),
                ],
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Suggestions',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...suggestions.map(
                        (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${item.toString()}',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          color: const Color(0xFF1F2937),
        ),
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analysis Configuration',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildConfigOption(
                    'Model',
                    'Saaras v3',
                    Icons.model_training,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildConfigOption(
                    'Mode',
                    'Translate to English',
                    Icons.translate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildConfigOption(
                    'Language',
                    'Auto Detect',
                    Icons.language,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildConfigOption(
                    'Speakers',
                    '2 Speakers',
                    Icons.people,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text(
                'Enable Quality Analysis',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Score telecallers on professionalism & empathy',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              value: true,
              onChanged: (value) {},
              activeColor: const Color(0xFF4F46E5),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigOption(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}