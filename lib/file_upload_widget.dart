import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'job_model.dart';

class FileUploadWidget extends StatefulWidget {
  final Function(Map<String, dynamic> result)? onAnalysisCompleted;

  const FileUploadWidget({
    Key? key,
    this.onAnalysisCompleted,
  }) : super(key: key);

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  List<FilePickerResult> selectedFiles = [];
  bool isUploading = false;
  double uploadProgress = 0;
  String jobStatus = '';
  String? currentJobId;

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.audio,
    );

    if (result != null) {
      setState(() {
        selectedFiles = [result];
      });
    }
  }

  List<Map<String, dynamic>> _normalizeDiarizedTranscript(dynamic data) {
    if (data is List) {
      return data.map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();
    }

    if (data is Map && data['entries'] is List) {
      return (data['entries'] as List).map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();
    }

    return [];
  }

  Future<void> startUpload() async {
    if (selectedFiles.isEmpty) {
      _showSnackBar('Please select audio files first', Colors.orange);
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0;
      jobStatus = 'Creating job...';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      setState(() {
        jobStatus = 'Creating transcription job...';
        uploadProgress = 0.1;
      });

      final createResponse = await apiService.createJob(
        model: 'saaras:v3',
        mode: 'translate',
        languageCode: 'unknown',
        withDiarization: true,
        numSpeakers: 2,
      );

      if (!createResponse['success']) {
        throw Exception(createResponse['error'] ?? 'Failed to create job');
      }

      currentJobId = createResponse['jobId'];

      setState(() {
        jobStatus = 'Uploading ${selectedFiles[0].files.length} file(s)...';
        uploadProgress = 0.2;
      });

      final uploadResponse = await apiService.uploadFilesWeb(
        currentJobId!,
        selectedFiles[0],
      );

      if (!uploadResponse['success']) {
        throw Exception(uploadResponse['error'] ?? 'Failed to upload files');
      }

      setState(() {
        jobStatus = 'Starting transcription...';
        uploadProgress = 0.4;
      });

      final startResponse = await apiService.startJob(currentJobId!);

      if (!startResponse['success']) {
        throw Exception(startResponse['error'] ?? 'Failed to start job');
      }

      setState(() {
        jobStatus = 'Processing audio files with Sarvam AI...';
        uploadProgress = 0.5;
      });

      bool isComplete = false;

      while (!isComplete) {
        await Future.delayed(const Duration(seconds: 3));

        final statusResponse = await apiService.getJobStatus(currentJobId!);

        if (statusResponse['status'] == 'completed') {
          isComplete = true;

          setState(() {
            jobStatus = 'Fetching results...';
            uploadProgress = 0.8;
          });

          final resultsResponse = await apiService.getJobResults(currentJobId!);

          if (resultsResponse['success'] &&
              resultsResponse['results'] != null &&
              resultsResponse['results'].isNotEmpty) {
            final firstResult = Map<String, dynamic>.from(
              resultsResponse['results'][0],
            );

            final normalizedDiarizedTranscript = _normalizeDiarizedTranscript(
              firstResult['diarized_transcript'],
            );

            final uploadedFileNames =
            selectedFiles[0].files.map((file) => file.name).toList();

            firstResult['diarized_transcript'] = normalizedDiarizedTranscript;
            firstResult['uploaded_file_name'] =
            uploadedFileNames.isNotEmpty ? uploadedFileNames.first : '';
            firstResult['uploaded_file_names'] = uploadedFileNames;

            setState(() {
              jobStatus = 'Analyzing conversation quality...';
              uploadProgress = 0.9;
            });

            final qualityResponse = await apiService.analyzeQuality(
              transcript: firstResult['transcript'] ?? '',
              diarizedTranscript: normalizedDiarizedTranscript,
            );

            setState(() {
              uploadProgress = 1.0;
              jobStatus = 'Complete!';
            });

            widget.onAnalysisCompleted?.call(firstResult);

// Optional: comment this if you do not want popup after analysis
// _showResultsDialog(firstResult, qualityResponse);

            //
            // widget.onAnalysisCompleted?.call(firstResult);
            //
            // _showResultsDialog(firstResult, qualityResponse);

            final jobModel = Provider.of<JobModel>(context, listen: false);
            jobModel.addJob({
              'id': currentJobId,
              'status': 'Completed',
              'date': DateTime.now().toIso8601String(),
              'files': selectedFiles[0].files.map((f) => f.name).toList(),
            });
          }

          break;
        } else if (statusResponse['status'] == 'failed') {
          throw Exception('Job failed');
        }

        if (statusResponse['progress'] != null) {
          final progress = statusResponse['progress'];
          final completed = progress['completed'] ?? 0;
          final total = progress['total'] ?? 1;

          final percentComplete = 0.5 + (completed / total) * 0.4;

          setState(() {
            uploadProgress = percentComplete;
            jobStatus = 'Processing: $completed/$total files';
          });
        }
      }

      _showSnackBar('Analysis completed successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
      setState(() {
        jobStatus = 'Failed: $e';
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  void _showResultsDialog(
      Map<String, dynamic> result,
      Map<String, dynamic> quality,
      ) {
    final diarizedTranscript = _normalizeDiarizedTranscript(
      result['diarized_transcript'],
    );

    final overallScore = quality['overallScore']?.toString() ?? '0';
    final professionalism = quality['professionalism']?.toString() ?? '0';
    final empathy = quality['empathy']?.toString() ?? '0';
    final clarity = quality['clarity']?.toString() ?? '0';
    final taskCompletion = quality['taskCompletion']?.toString() ?? '0';
    final talkRatio = quality['talkRatio']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Color(0xFF4F46E5)),
            SizedBox(width: 8),
            Text('Analysis Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Overall Quality Score',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overallScore,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: double.parse(overallScore) / 10,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Detailed Metrics',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildMetricRow('Professionalism', professionalism),
              _buildMetricRow('Empathy', empathy),
              _buildMetricRow('Clarity', clarity),
              _buildMetricRow('Task Completion', taskCompletion),

              const Divider(),

              const Text(
                'Conversation Stats',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStatRow(
                'Agent Words',
                quality['agentWordCount']?.toString() ?? '0',
              ),
              _buildStatRow(
                'Customer Words',
                quality['customerWordCount']?.toString() ?? '0',
              ),
              _buildStatRow(
                'Talk Ratio',
                '${(double.parse(talkRatio) * 100).toInt()}%',
              ),

              const Divider(),

              const Text(
                'Improvement Suggestions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(quality['suggestions'] as List? ?? []).map(
                    (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(color: Color(0xFF4F46E5)),
                      ),
                      Expanded(child: Text(suggestion.toString())),
                    ],
                  ),
                ),
              ),

              if (diarizedTranscript.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Transcript Preview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: diarizedTranscript.length > 5
                        ? 5
                        : diarizedTranscript.length,
                    itemBuilder: (context, index) {
                      final segment = diarizedTranscript[index];
                      final speakerId =
                          segment['speaker_id']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speaker $speakerId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            Text(
                              segment['transcript']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Save Results'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    final parsedValue = double.tryParse(value) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Container(
            width: 100,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: parsedValue / 10,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 35,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            InkWell(
              onTap: isUploading ? null : pickFiles,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: const Color(0xFF4F46E5).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isUploading
                          ? 'Processing...'
                          : 'Drag & drop audio files here',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUploading ? jobStatus : 'or click to browse',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supports MP3, WAV, FLAC, M4A (max 1 hour)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (selectedFiles.isNotEmpty && !isUploading) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Files (${selectedFiles[0].files.length})',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...selectedFiles[0].files.map(
                          (file) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.audio_file,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.name,
                                style: GoogleFonts.poppins(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                setState(() {
                                  selectedFiles.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: startUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Start Analysis',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            if (isUploading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(value: uploadProgress),
              const SizedBox(height: 8),
              Text(
                jobStatus,
                style: GoogleFonts.poppins(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (uploadProgress < 1.0) ...[
                const SizedBox(height: 8),
                Text(
                  '${(uploadProgress * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}