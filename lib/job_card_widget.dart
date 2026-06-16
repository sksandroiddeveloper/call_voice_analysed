import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JobCardWidget extends StatelessWidget {
  final String jobId;
  final String status;
  final String date;
  final List<String> files;

  const JobCardWidget({
    Key? key,
    required this.jobId,
    required this.status,
    required this.date,
    required this.files,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == 'Completed' ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  jobId,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    // ❌ REMOVE THIS LINE: fontFeatures: 'Poppins',
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: files.map((file) => Chip(
                label: Text(
                  file,
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                backgroundColor: const Color(0xFFF3F4F6),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View Results'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}