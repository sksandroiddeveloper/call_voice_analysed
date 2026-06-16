import 'package:flutter/foundation.dart';

class JobModel extends ChangeNotifier {
  List<Map<String, dynamic>> _jobs = [];
  bool _isProcessing = false;

  List<Map<String, dynamic>> get jobs => _jobs;
  bool get isProcessing => _isProcessing;

  void addJob(Map<String, dynamic> job) {
    _jobs.insert(0, job);
    notifyListeners();
  }

  void updateJobStatus(String jobId, String status) {
    final index = _jobs.indexWhere((job) => job['id'] == jobId);
    if (index != -1) {
      _jobs[index]['status'] = status;
      notifyListeners();
    }
  }

  void setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }
}