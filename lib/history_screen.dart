// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _conversationFuture;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    _conversationFuture = apiService.getConversations();
  }

  Future<void> _refreshConversations() async {
    setState(_loadConversations);
    await _conversationFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job History',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'View and manage your past conversation analysis results',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(_loadConversations);
                  },
                  icon: const Icon(Icons.refresh, color: Color(0xFF4F46E5)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _conversationFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildMessageCard(
                      icon: Icons.error_outline,
                      title: 'Unable to load history',
                      message: snapshot.error.toString(),
                      iconColor: Colors.red,
                    );
                  }

                  final conversations = snapshot.data ?? [];

                  if (conversations.isEmpty) {
                    return _buildMessageCard(
                      icon: Icons.history,
                      title: 'No history found',
                      message: 'Your analyzed conversations will appear here.',
                      iconColor: const Color(0xFF4F46E5),
                    );
                  }

                  conversations.sort((a, b) {
                    final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(1900);
                    final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(1900);
                    return bDate.compareTo(aDate);
                  });

                  return RefreshIndicator(
                    onRefresh: _refreshConversations,
                    child: ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildConversationCard(conversations[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final conversationId = conversation['conversationId']?.toString() ?? '';
    final fileName = conversation['phoneNo']?.toString() ?? 'Unknown file';
    final rating = conversation['rating']?.toString() ?? '0';
    final remark = conversation['remark']?.toString() ?? '';
    final conversationText = conversation['conversationText']?.toString() ?? '';
    final createdAt = conversation['createdAt']?.toString() ?? '';
    final formattedDate = _formatDateTime(createdAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversationId.isEmpty ? formattedDate : 'ID: $conversationId  •  $formattedDate',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildRatingBadge(rating),
              ],
            ),
            const SizedBox(height: 14),
            if (remark.isNotEmpty) ...[
              Text(
                remark,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (conversationText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  conversationText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showConversationDetails(conversation),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Results'),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => _downloadConversationDoc(conversation),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download .doc'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBadge(String rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$rating / 10',
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    required Color iconColor,
  }) {
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConversationDetails(Map<String, dynamic> conversation) {
    final fileName = conversation['phoneNo']?.toString() ?? 'Unknown file';
    final rating = conversation['rating']?.toString() ?? '0';
    final remark = conversation['remark']?.toString() ?? '';
    final conversationText = conversation['conversationText']?.toString() ?? '';
    final createdAt = _formatDateTime(conversation['createdAt']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _detailChip(Icons.star_outline, 'Rating: $rating / 10'),
                    _detailChip(Icons.access_time, createdAt),
                  ],
                ),
                const SizedBox(height: 16),
                _detailSection('Remark', remark.isEmpty ? '-' : remark),
                const SizedBox(height: 16),
                _detailSection('Conversation Text', _formatConversationText(conversationText)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _downloadConversationDoc(conversation),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download .doc'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _detailSection(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SelectableText(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );
  }

  void _downloadConversationDoc(Map<String, dynamic> conversation) {
    final fileName = conversation['phoneNo']?.toString() ?? 'conversation';
    final rating = conversation['rating']?.toString() ?? '0';
    final remark = conversation['remark']?.toString() ?? '';
    final conversationText = conversation['conversationText']?.toString() ?? '';
    final createdAt = _formatDateTime(conversation['createdAt']?.toString() ?? '');

    final safeDownloadName = _sanitizeFileName(fileName).replaceAll(RegExp(r'\.[^.]+$'), '');
    final htmlContent = '''
<html>
  <head>
    <meta charset="utf-8">
    <title>Conversation Result</title>
  </head>
  <body>
    <h2>Conversation Result</h2>
    <p><strong>File Name:</strong> ${_escapeHtml(fileName)}</p>
    <p><strong>Date Time:</strong> ${_escapeHtml(createdAt)}</p>
    <p><strong>Rating:</strong> ${_escapeHtml(rating)} / 10</p>
    <h3>Remark</h3>
    <pre>${_escapeHtml(remark)}</pre>
    <h3>Conversation Text</h3>
    <pre>${_escapeHtml(_formatConversationText(conversationText))}</pre>
  </body>
</html>
''';

    final blob = html.Blob(
      [htmlContent],
      'application/msword;charset=utf-8',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${safeDownloadName}_conversation.doc')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _formatDateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? '-' : value;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour:$minute';
  }

  String _formatConversationText(String value) {
    return value
        .replaceAllMapped(RegExp(r'(Speaker\s+\d+:)'), (match) => '\n${match.group(1)} ')
        .trim();
  }

  String _sanitizeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
    return sanitized.isEmpty ? 'conversation' : sanitized;
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
