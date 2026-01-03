import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_service.dart';
import 'login_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ================= DESIGN SYSTEM =================
const Color bgDark = Color(0xFF0B1220);
const Color cardDark = Color(0xFF111827);
const Color cardBorder = Color(0xFF1F2937);

const Color accent = Color(0xFF3B82F6);
const Color accentSoft = Color(0xFF1E40AF);

const Color success = Color(0xFF22C55E);
const Color warning = Color(0xFFF59E0B);
const Color danger = Color(0xFFEF4444);

const Color textPrimary = Color(0xFFE5E7EB);
const Color textSecondary = Color(0xFF9CA3AF);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<List<Map<String, dynamic>>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _reloadJobs();
  }

  void _reloadJobs() {
    _jobsFuture = AppService.instance.fetchAllJobsCandidates();
  }

  Future<void> _logout() async {
    await AppService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openResumeUploadDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const ResumeUploadDialog(),
    );

    // 🔁 Refresh jobs after upload
    setState(_reloadJobs);
  }

  // ===================== CREATE JOB =====================

  void _createJobDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final quesCtrl = TextEditingController();
    final topicsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Job'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Job Title'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: expCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Experience Required (years)',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: topicsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Interview Topics (comma separated)',
                  hintText: 'flutter, state management, api, architecture',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: quesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Questions',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            child: const Text('Create Job'),
            onPressed: () async {
              try {
                // ✅ CALL BACKEND (NOT SUPABASE DIRECT)
                final res = await AppService.instance.createJob(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  experienceRequired: int.parse(expCtrl.text.trim()),
                  questionCount: int.parse(quesCtrl.text.trim()),
                  interviewTopics: topicsCtrl.text.trim(),
                );

                Navigator.pop(context);
                setState(_reloadJobs);

                final int count = res['auto_assigned_count'] ?? 0;
                final List assigned = res['auto_assigned_candidates'] ?? [];

                // 🎉 AUTO ASSIGN RESULT POPUP
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: cardDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Job Created'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          count > 0
                              ? '✅ $count existing candidates auto-assigned'
                              : 'ℹ️ No existing candidates matched',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: count > 0 ? Colors.green : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (assigned.isNotEmpty) ...[
                          const Text(
                            'Assigned Candidates:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ...assigned.map(
                            (c) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ${c['name']} (${c['email']})'),
                                if (c['password'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      top: 2,
                                    ),
                                    child: Text(
                                      '🔑 Temp Password: ${c['password']}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Job creation failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ===================== CREATE CANDIDATE =====================

  void _createCandidateDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Candidate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Temp Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AppService.instance.createCandidate(
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                password: passCtrl.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ===================== OPEN JOB DETAIL =====================

  void _openJobDetail(Map<String, dynamic> job) async {
    final bool? updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => JobDetailSheet(jobId: job['id'], jobTitle: job['title']),
    );

    if (updated == true) {
      setState(_reloadJobs);
    }
  }

  // ===================== DASHBOARD UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // 🔥 IMPORTANT
        actions: [
          IconButton(
            tooltip: 'Create Candidate',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _createCandidateDialog,
          ),
          IconButton(
            tooltip: 'Create Job',
            icon: const Icon(Icons.work_outline),
            onPressed: _createJobDialog,
          ),
          IconButton(
            tooltip: 'Upload Resume',
            icon: const Icon(Icons.upload_file),
            onPressed: _openResumeUploadDialog,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),

      body: Column(
        children: [
          // ===== RESUME UPLOAD CTA (CHANGE 4) =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openResumeUploadDialog,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accentSoft],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.upload_file,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Resume',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'AI will auto-match candidates with jobs',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== EXISTING JOB LIST =====
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _jobsFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final jobs = snapshot.data ?? [];
                if (jobs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No jobs created yet',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: jobs.length,
                  itemBuilder: (_, i) {
                    final job = jobs[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openJobDetail(job),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      job['title'],
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: danger,
                                    ),
                                    onPressed: () async {
                                      await AppService.instance.deleteJob(
                                        job['id'],
                                      );
                                      setState(_reloadJobs);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_outline,
                                      size: 16,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${job['candidates_count']} candidates assigned',
                                      style: const TextStyle(color: accent),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'View Details →',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// JOB DETAIL SHEET (UI POLISHED, LOGIC SAME)
// =================================================================

class JobDetailSheet extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const JobDetailSheet({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobDetailSheet> createState() => _JobDetailSheetState();
}

class _JobDetailSheetState extends State<JobDetailSheet> {
  late Future<List<Map<String, dynamic>>> _candidatesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _candidatesFuture = AppService.instance.fetchCandidatesForJob(widget.jobId);
  }

  Future<void> _assignCandidateDialog() async {
    final candidates = await AppService.instance.fetchAllCandidates();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Assign Candidate'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (_, i) {
              final c = candidates[i];
              return ListTile(
                title: Text(c['name']),
                subtitle: Text(c['email']),
                trailing: ElevatedButton(
                  child: const Text('Assign'),
                  onPressed: () async {
                    await AppService.instance.assignCandidateToJob(
                      candidateId: c['id'],
                      jobId: widget.jobId,
                    );
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.jobTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt),
                  onPressed: _assignCandidateDialog,
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Assigned Candidates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _candidatesFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Center(child: Text('No candidates assigned'));
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final profile = list[i]['profile'] ?? {};
                    final interview = list[i]['interview'] ?? {};
                    final status = interview['status'] ?? 'not started';

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: interview['status'] == 'completed'
                          ? () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => DraggableScrollableSheet(
                                  initialChildSize: 0.9,
                                  minChildSize: 0.75,
                                  maxChildSize: 0.95,
                                  expand: false,
                                  builder: (_, controller) {
                                    return Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                      ),
                                      child: InterviewDetailSheet(
                                        interviewId: interview['id'],
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 🔵 AVATAR
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                (profile['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // 🧑 NAME + STATUS
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    interview['status'] == 'completed'
                                        ? 'Interview Completed'
                                        : 'Interview Pending',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: interview['status'] == 'completed'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 📊 SCORE + DELETE
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (interview['status'] == 'completed')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${interview['total_score']} / 100',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 8),

                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    await AppService.instance
                                        .removeCandidateFromJob(
                                          candidateId: profile['id'],
                                          jobId: widget.jobId,
                                        );
                                    Navigator.pop(context, true);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// INTERVIEW DETAIL SHEET (UI SAME LOGIC)
// =================================================================

class InterviewDetailSheet extends StatelessWidget {
  final String interviewId;

  const InterviewDetailSheet({super.key, required this.interviewId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: FutureBuilder<Map<String, dynamic>>(
        future: AppService.instance.fetchInterviewDetails(interviewId),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final profile = data['profiles'];
          final job = data['jobs'];
          final int score = data['total_score'] ?? 0;
          final Map<String, dynamic> topicBreakdown = Map<String, dynamic>.from(
            data['topic_breakdown'] ?? {},
          );

          final Map<String, dynamic> skillSummary = Map<String, dynamic>.from(
            data['skill_summary'] ?? {},
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Job: ${job['title']}'),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Final Score',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$score / 100',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: score >= 70
                              ? Colors.green
                              : score >= 40
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (skillSummary.isNotEmpty) ...[
                  const Text(
                    'Skill Evaluation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _SkillBar(
                    label: 'Communication',
                    value: (skillSummary['communication'] ?? 0).toDouble(),
                  ),
                  _SkillBar(
                    label: 'Technical Accuracy',
                    value: (skillSummary['technical_accuracy'] ?? 0).toDouble(),
                  ),
                  _SkillBar(
                    label: 'Problem Solving',
                    value: (skillSummary['problem_solving'] ?? 0).toDouble(),
                  ),
                  _SkillBar(
                    label: 'Confidence',
                    value: (skillSummary['confidence'] ?? 0).toDouble(),
                  ),

                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 24),

                if (topicBreakdown.isNotEmpty) ...[
                  const Text(
                    'Score Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...topicBreakdown.entries.map(
                    (e) => _ScoreBar(
                      label: _prettyTopic(e.key),
                      value: (e.value as num).toDouble(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (data['transcript_pdf'] != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Open Transcript PDF'),
                      onPressed: () async {
                        await launchUrl(
                          Uri.parse(data['transcript_pdf']),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _prettyTopic(String key) =>
      key.replaceAll('_', ' ').toUpperCase();
}

// =================================================================
// SCORE BAR (UNCHANGED LOGIC)
// =================================================================

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value; // 0–10

  const _ScoreBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 10).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label – ${value.toStringAsFixed(1)} / 10',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                value >= 7
                    ? Colors.green
                    : value >= 4
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResumeUploadDialog extends StatefulWidget {
  const ResumeUploadDialog({super.key});

  @override
  State<ResumeUploadDialog> createState() => _ResumeUploadDialogState();
}

class _ResumeUploadDialogState extends State<ResumeUploadDialog> {
  File? _resume;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  // ================= PICK PDF =================
  Future<void> _pickResume() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (res != null && res.files.single.path != null) {
      setState(() {
        _resume = File(res.files.single.path!);
        _error = null;
      });
    }
  }

  // ================= UPLOAD =================
  Future<void> _upload() async {
    if (_resume == null) {
      setState(() => _error = 'Please select a PDF resume');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.130.137:3000/admin/resume/upload'),
      );

      req.files.add(await http.MultipartFile.fromPath('file', _resume!.path));

      final res = await req.send();
      final body = await res.stream.bytesToString();
      final json = jsonDecode(body);

      setState(() => _result = json);
    } catch (e, st) {
      debugPrint('❌ Upload exception: $e');
      debugPrint('$st');
      setState(() => _error = 'Upload failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Upload Resume'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------- PICKER --------
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(
                _resume == null ? 'Select PDF Resume' : 'Change Resume',
              ),
              onPressed: _loading ? null : _pickResume,
            ),

            if (_resume != null) ...[
              const SizedBox(height: 6),
              Text(
                _resume!.path.split('/').last,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 16),

            // -------- ERROR --------
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            // -------- RESULT --------
            if (_result != null) _ResultView(result: _result!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _upload,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload & Match'),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final status = result['status'];

    if (status == 'parse_failed') {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          '❌ Resume could not be parsed. Please upload a readable PDF.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    // ❌ NO MATCH
    if (status == 'no_match') {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          '❌ No suitable job found for this resume',
          style: TextStyle(color: Colors.orange),
        ),
      );
    }

    // ⚠️ NO JOBS
    if (status == 'no_job_available') {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          '⚠️ No jobs available in system',
          style: TextStyle(color: Colors.orange),
        ),
      );
    }

    // ✅ SUCCESS
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== SUCCESS HEADER (CHANGE 3) =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '🎉 Resume processed & auto-matched successfully',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(),

          Text(
            '✅ Candidate: ${result['name']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Email: ${result['email']}'),

          const SizedBox(height: 8),

          // ===== TEMP PASSWORD =====
          if (result['candidate_created'] == true) ...[
            const Text(
              'Temporary Password',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              result['temp_password'],
              style: const TextStyle(fontSize: 16, color: Colors.green),
            ),
            const Text(
              '⚠️ Copy this now. It will not be shown again.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ] else
            const Text(
              'ℹ️ Candidate already exists. No new password generated.',
            ),

          const SizedBox(height: 12),

          // ===== ASSIGNED JOBS =====
          const Text(
            'Assigned Jobs',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...(() {
            final assignedJobs = (result['assigned_jobs'] as List?) ?? [];

            if (assignedJobs.isEmpty) {
              return [
                const Text(
                  '• No jobs assigned',
                  style: TextStyle(color: Colors.grey),
                ),
              ];
            }

            return assignedJobs.map<Widget>((job) {
              if (job is Map && job['title'] != null) {
                return Text(
                  '• ${job['title']}',
                  style: const TextStyle(fontSize: 14),
                );
              }

              return Text('• $job', style: const TextStyle(fontSize: 14));
            }).toList();
          })(),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final String label;
  final double value; // 0–10

  const _SkillBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 10).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label – ${value.toStringAsFixed(1)} / 10',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                value >= 7
                    ? Colors.green
                    : value >= 4
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
