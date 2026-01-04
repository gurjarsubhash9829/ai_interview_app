import 'package:ai_interview_app/widgets/dashboard_cards.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_service.dart';
import 'login_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'metachip.dart';

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

class _ResumeUploadBottomSheet extends StatelessWidget {
  const _ResumeUploadBottomSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── DRAG HANDLE ───
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ─── TITLE ───
                const Text(
                  'Upload Resume',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'AI will analyze & auto-assign jobs',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),

                const SizedBox(height: 22),

                // ─── ACTUAL CONTENT ───
                const ResumeUploadDialog(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  Future<void> _reloadJobs() async {
    setState(() {
      _jobsFuture = AppService.instance.fetchAllJobsCandidates();
    });
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
    final res = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ResumeUploadBottomSheet(),
    );

    if (res == true) {
      await _reloadJobs(); // ✅ reload only on success
    }
  }

  // ===================== CREATE JOB =====================

  void _createJobDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final quesCtrl = TextEditingController();
    final topicsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── DRAG HANDLE ───
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── TITLE ───
                  const Text(
                    'Create Job',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Define role & interview configuration',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),

                  const SizedBox(height: 22),

                  // ─── JOB INFO ───
                  const Text(
                    'Job Information',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _InputField(
                    controller: titleCtrl,
                    label: 'Job Title',
                    hint: 'Flutter Developer',
                    icon: Icons.work_outline,
                  ),

                  const SizedBox(height: 12),

                  _InputField(
                    controller: descCtrl,
                    label: 'Description',
                    hint: 'Role responsibilities & expectations',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 18),

                  // ─── INTERVIEW CONFIG ───
                  const Text(
                    'Interview Configuration',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _InputField(
                          controller: expCtrl,
                          label: 'Experience',
                          hint: 'Years',
                          icon: Icons.timeline,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InputField(
                          controller: quesCtrl,
                          label: 'Questions',
                          hint: 'Count',
                          icon: Icons.help_outline,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _InputField(
                    controller: topicsCtrl,
                    label: 'Interview Topics',
                    hint: 'flutter, state, api, architecture',
                    icon: Icons.auto_awesome,
                  ),

                  const SizedBox(height: 26),

                  // ─── ACTIONS ───
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            final desc = descCtrl.text.trim();
                            final topics = topicsCtrl.text.trim();

                            final exp = int.tryParse(expCtrl.text.trim());
                            final ques = int.tryParse(quesCtrl.text.trim());

                            if (title.isEmpty ||
                                desc.isEmpty ||
                                topics.isEmpty ||
                                exp == null ||
                                ques == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Please fill all fields correctly',
                                  ),
                                  backgroundColor: warning,
                                ),
                              );
                              return;
                            }

                            try {
                              final res = await AppService.instance.createJob(
                                title: title,
                                description: desc,
                                experienceRequired: exp,
                                questionCount: ques,
                                interviewTopics: topics,
                              );

                              Navigator.pop(context);
                              // setState(_reloadJobs);

                              _showAutoAssignResult(res);
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Job creation failed: $e'),
                                  backgroundColor: danger,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Create Job',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAutoAssignResult(Map<String, dynamic> res) {
    final int count = res['auto_assigned_count'] ?? 0;
    final List assigned = res['auto_assigned_candidates'] ?? [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Job Created Successfully',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── STATUS MESSAGE ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: count > 0
                    ? success.withOpacity(0.12)
                    : warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count > 0
                    ? '✅ $count candidate(s) auto-assigned'
                    : 'ℹ️ No matching candidates found',
                style: TextStyle(
                  color: count > 0 ? success : warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ─── ASSIGNED LIST ───
            if (assigned.isNotEmpty) ...[
              const Text(
                'Assigned Candidates',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              ...assigned.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ${c['name']} (${c['email']})',
                        style: const TextStyle(color: textSecondary),
                      ),
                      if (c['password'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 2),
                          child: Text(
                            '🔑 Temp Password: ${c['password']}',
                            style: const TextStyle(
                              color: success,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── DRAG HANDLE ───
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── TITLE ───
                  const Text(
                    'Create Candidate',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add a new candidate to the system',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),

                  const SizedBox(height: 22),

                  // ─── CANDIDATE INFO ───
                  const Text(
                    'Candidate Information',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _InputField(
                    controller: nameCtrl,
                    label: 'Full Name',
                    hint: 'John Doe',
                    icon: Icons.person_outline,
                  ),

                  const SizedBox(height: 12),

                  _InputField(
                    controller: emailCtrl,
                    label: 'Email Address',
                    hint: 'john@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 12),

                  _InputField(
                    controller: passCtrl,
                    label: 'Temporary Password',
                    hint: 'Auto / Manual',
                    icon: Icons.lock_outline,
                  ),

                  const SizedBox(height: 26),

                  // ─── ACTIONS ───
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            final email = emailCtrl.text.trim();
                            final password = passCtrl.text.trim();

                            if (name.isEmpty ||
                                email.isEmpty ||
                                !email.contains('@') ||
                                password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Please enter valid candidate details',
                                  ),
                                  backgroundColor: warning,
                                ),
                              );
                              return;
                            }

                            try {
                              await AppService.instance.createCandidate(
                                name: name,
                                email: email,
                                password: password,
                              );

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Candidate created successfully',
                                  ),
                                  backgroundColor: success,
                                ),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '❌ Failed to create candidate: $e',
                                  ),
                                  backgroundColor: danger,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Create Candidate',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================== OPEN JOB DETAIL =====================

  void _openJobDetail(Map<String, dynamic> job, int candidateCount) async {
    final bool? updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JobDetailSheet(
        jobId: job['id'],
        jobTitle: job['title'],
        candidateCount: candidateCount,
      ),
    );

    if (updated == true) {
      setState(_reloadJobs);
    }
  }

  // ===================== DASHBOARD UI =====================
  void _openAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cardDark.withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── DRAG HANDLE ───
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),

                const SizedBox(height: 22),

                // ─── APP / ACCOUNT INFO ───
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset('assets/images/logo.png', height: 34),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Ninja',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Admin account',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                const Divider(color: cardBorder, height: 1),

                const SizedBox(height: 8),

                // ─── LOGOUT (DANGER ZONE) ───
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    Navigator.pop(context);
                    await _logout();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout, color: danger),
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Sign out from admin panel',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ─── CANCEL (SAFE EXIT) ───
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),

            // 🔰 APP LOGO
            Image.asset(
              'assets/images/logo.png', // 👈 update path if needed
              height: 28,
            ),

            const SizedBox(width: 10),

            // 🏷 TITLE
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _openAccountMenu,
          ),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF030712), Color(0xFF050F2C), Color(0xFF0B3C5D)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // ================= DASHBOARD CARDS =================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DashboardCard(
                        title: 'Jobs',
                        subtitle: 'Create & manage',
                        icon: Icons.work_outline,
                        gradient: const [Color(0xFF6366F1), Color(0xFF4338CA)],
                        onTap: _createJobDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardCard(
                        title: 'Candidates',
                        subtitle: 'Add & assign',
                        icon: Icons.people_outline,
                        gradient: const [Color(0xFF22C55E), Color(0xFF15803D)],
                        onTap: _createCandidateDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ================= RESUME UPLOAD (PRIMARY CTA) =================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: DashboardCard(
                  title: 'AI Resume Matching',
                  subtitle: 'Upload resume & auto-assign jobs',
                  icon: Icons.auto_awesome,
                  gradient: const [accent, accentSoft],
                  fullWidth: true,
                  onTap: _openResumeUploadDialog,
                ),
              ),
            ),

            // ================= JOB LIST HEADER =================
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Active Jobs',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // ================= JOB LIST =================
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: RefreshIndicator(
                  color: accent,
                  backgroundColor: cardDark,
                  onRefresh: _reloadJobs, // 👈 USER CONTROLLED REFRESH
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _jobsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: _ActiveJobsShimmer(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: textSecondary),
                            ),
                          ),
                        );
                      }

                      final jobs = snapshot.data ?? [];

                      if (jobs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'No jobs created yet',
                              style: TextStyle(color: textSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: jobs.length,
                        itemBuilder: (context, i) {
                          final job = jobs[i];
                          final int candidateCount =
                              job['candidates_count'] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                _openJobDetail(job, candidateCount);
                              },

                              // onTap: () {
                              //   if (candidateCount > 0) {
                              //     _openJobDetail(job, candidateCount);
                              //   } else {
                              //     ScaffoldMessenger.of(context).showSnackBar(
                              //       const SnackBar(
                              //         content: Text(
                              //           'ℹ️ No candidates assigned to this job yet',
                              //         ),
                              //         backgroundColor: warning,
                              //         duration: Duration(seconds: 2),
                              //       ),
                              //     );
                              //   }
                              // },

                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  16,
                                  18,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [accent, accentSoft],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            job['title'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          MetaChip(
                                            icon: Icons.people_outline,
                                            label:
                                                '${job['candidates_count']} Candidates',
                                            color: accent,
                                          ),
                                          const SizedBox(height: 14),
                                          const Text(
                                            'View interview details →',
                                            style: TextStyle(
                                              color: accent,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: danger,
                                      ),
                                      onPressed: () => _confirmDeleteJob(
                                        jobId: job['id'],
                                        jobTitle: job['title'],
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteJob({
    required String jobId,
    required String jobTitle,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Job',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: textSecondary),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: jobTitle,
                style: const TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '?\n\nThis action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppService.instance.deleteJob(jobId);
      setState(_reloadJobs);
    }
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
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
  final int candidateCount;

  const JobDetailSheet({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.candidateCount,
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

  bool _isAssignSheetOpen = false;

  double get _initialSheetSize {
    final c = widget.candidateCount;
    if (c <= 1) return 0.35;
    if (c <= 4) return 0.5;
    if (c <= 8) return 0.65;
    return 0.8;
  }

  void _reload() {
    _candidatesFuture = AppService.instance.fetchCandidatesForJob(widget.jobId);
  }

  Widget _emptyCandidateState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        '⚠️ No candidates available.\nPlease create a candidate first.',
        style: TextStyle(color: warning, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _candidateAssignTile(Map<String, dynamic> c) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: accent.withOpacity(0.15),
        child: Text(
          (c['name'] ?? 'U')[0].toUpperCase(),
          style: const TextStyle(color: accent, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        c['name'],
        style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(c['email'], style: const TextStyle(color: textSecondary)),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          await AppService.instance.assignCandidateToJob(
            candidateId: c['id'],
            jobId: widget.jobId,
          );

          Navigator.pop(context); // close assign sheet
          Navigator.pop(context, true); // refresh job detail
        },
        child: const Text(
          'Assign',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _assignCandidateDialog() async {
    // 🚫 Prevent multiple opens
    if (_isAssignSheetOpen) return;

    _isAssignSheetOpen = true;

    try {
      final candidates = await AppService.instance.fetchAllCandidates();
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Assign Candidate',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a candidate to assign to this job',
                    style: TextStyle(color: textSecondary),
                  ),

                  const SizedBox(height: 20),

                  if (candidates.isEmpty)
                    _emptyCandidateState()
                  else
                    Flexible(
                      child: ListView.separated(
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: cardBorder),
                        itemBuilder: (_, i) {
                          final c = candidates[i];
                          return _candidateAssignTile(c);
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      // ✅ ALWAYS reset flag when sheet closes
      _isAssignSheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _initialSheetSize,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: bgDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // ─── DRAG HANDLE ───
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── HEADER ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.jobTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Assign Candidate',
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_add_alt,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        onPressed: _assignCandidateDialog,
                      ),
                    ],
                  ),
                ),

                const Divider(color: cardBorder, height: 1),

                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Assigned Candidates',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),

                // ─── LIST ───
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _candidatesFuture,
                    builder: (_, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _candidateShimmer(scrollController);
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: textSecondary),
                          ),
                        );
                      }

                      final list = snapshot.data ?? [];

                      if (list.isEmpty) {
                        return const Center(
                          child: Text(
                            'No candidates assigned',
                            style: TextStyle(color: textSecondary),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          return _CandidateTile(
                            data: list[i],
                            onDelete: _confirmRemoveCandidate,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _candidateShimmer(ScrollController controller) {
    final count = widget.candidateCount.clamp(2, 6);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: cardBorder,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveCandidate({
    required String candidateId,
    required String candidateName,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: danger),
            SizedBox(width: 8),
            Text('Remove Candidate'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: textSecondary),
            children: [
              const TextSpan(text: 'Remove '),
              TextSpan(
                text: candidateName,
                style: const TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text:
                    ' from this job?\n\nThe candidate interview data will be unassigned.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppService.instance.removeCandidateFromJob(
        candidateId: candidateId,
        jobId: widget.jobId,
      );
      Navigator.pop(context, true); // refresh parent
    }
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
    return Container(
      decoration: const BoxDecoration(
        color: bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: AppService.instance.fetchInterviewDetails(interviewId),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _InterviewDetailShimmer();
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: textSecondary),
                ),
              );
            }

            final data = snapshot.data!;
            final profile = data['profiles'];
            final job = data['jobs'];
            final int score = data['total_score'] ?? 0;

            final Map<String, dynamic> topicBreakdown =
                Map<String, dynamic>.from(data['topic_breakdown'] ?? {});

            final Map<String, dynamic> skillSummary = Map<String, dynamic>.from(
              data['skill_summary'] ?? {},
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── DRAG HANDLE ───
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ─── HEADER ───
                  Text(
                    profile['name'],
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Interview for ${job['title']}',
                    style: const TextStyle(color: textSecondary, fontSize: 14),
                  ),

                  const SizedBox(height: 20),

                  // ─── FINAL SCORE CARD ───
                  _ScoreCard(score: score),

                  const SizedBox(height: 28),

                  // ─── SKILLS ───
                  if (skillSummary.isNotEmpty) ...[
                    const Text(
                      'Skill Evaluation',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _SkillBar(
                      label: 'Communication',
                      value: (skillSummary['communication'] ?? 0).toDouble(),
                    ),
                    _SkillBar(
                      label: 'Technical Accuracy',
                      value: (skillSummary['technical_accuracy'] ?? 0)
                          .toDouble(),
                    ),
                    _SkillBar(
                      label: 'Problem Solving',
                      value: (skillSummary['problem_solving'] ?? 0).toDouble(),
                    ),
                    _SkillBar(
                      label: 'Confidence',
                      value: (skillSummary['confidence'] ?? 0).toDouble(),
                    ),

                    const SizedBox(height: 28),
                  ],

                  // ─── TOPIC BREAKDOWN ───
                  if (topicBreakdown.isNotEmpty) ...[
                    const Text(
                      'Score Breakdown',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...topicBreakdown.entries.map(
                      (e) => _ScoreBar(
                        label: _prettyTopic(e.key),
                        value: (e.value as num).toDouble(),
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],

                  // ─── PDF CTA ───
                  if (data['transcript_pdf'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          await launchUrl(
                            Uri.parse(data['transcript_pdf']),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              // ─── PDF ICON ───
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf,
                                  color: accent,
                                  size: 22,
                                ),
                              ),

                              const SizedBox(width: 14),

                              // ─── TEXT ───
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Interview Transcript',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'View full interview conversation (PDF)',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ─── ARROW ───
                              const Icon(
                                Icons.open_in_new,
                                color: textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _prettyTopic(String key) =>
      key.replaceAll('_', ' ').toUpperCase();
}

class _ScoreCard extends StatelessWidget {
  final int score;

  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final Color color = score >= 70
        ? success
        : score >= 40
        ? warning
        : danger;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Final Score',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Out of 100',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterviewDetailShimmer extends StatelessWidget {
  const _InterviewDetailShimmer();

  Widget _block({double height = 16, double width = double.infinity}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cardBorder.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _block(height: 5, width: 44)),
          const SizedBox(height: 24),

          _block(height: 22, width: 160),
          const SizedBox(height: 6),
          _block(height: 14, width: 220),

          const SizedBox(height: 24),

          _block(height: 90),

          const SizedBox(height: 28),

          _block(height: 18, width: 140),
          const SizedBox(height: 12),

          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _block(height: 54),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// SCORE BAR (UNCHANGED LOGIC)
// =================================================================

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value; // 0–10

  const _ScoreBar({required this.label, required this.value});

  Color get _color {
    if (value >= 7) return success;
    if (value >= 4) return warning;
    return danger;
  }

  String get _verdict {
    if (value >= 8) return 'Excellent';
    if (value >= 6) return 'Good';
    if (value >= 4) return 'Average';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (value / 10).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── LABEL + SCORE ───
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  color: _color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ─── VERDICT ───
          Text(
            _verdict,
            style: TextStyle(
              color: _color.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 10),

          // ─── ANIMATED BAR ───
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) {
                return LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation(_color),
                );
              },
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
  bool get _isSuccess {
    final status = _result?['status'];
    return status != null &&
        status != 'parse_failed' &&
        status != 'no_match' &&
        status != 'no_job_available';
  }

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
        Uri.parse('http://10.184.218.137:3000/admin/resume/upload'),
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
    // 🟢 SUCCESS → SHOW ONLY RESULT SUMMARY
    if (_isSuccess) {
      return _ResultView(result: _result!);
    }

    // 🟡 NON-SUCCESS → SHOW UPLOAD UI
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── PICK RESUME ───
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(
              _resume == null ? 'Select PDF Resume' : 'Change Resume',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrimary,
              side: BorderSide(color: cardBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _loading ? null : _pickResume,
          ),
        ),

        if (_resume != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.insert_drive_file,
                size: 16,
                color: textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _resume!.path.split('/').last,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // ─── ERROR ───
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: danger, fontSize: 13),
            ),
          ),

        const SizedBox(height: 20),

        // ─── ACTION BUTTON ───
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _loading ? null : _upload,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Upload & Match',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
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
          // ─── SUCCESS SUMMARY ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: success),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Resume processed successfully and matched with available jobs.',
                    style: TextStyle(
                      color: success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── CANDIDATE DETAILS BOX ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Candidate Details',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                _detailRow('Name', result['name']),
                _detailRow('Email', result['email']),

                // ─── TEMP PASSWORD ───
                if (result['candidate_created'] == true) ...[
                  const SizedBox(height: 14),
                  const Divider(color: cardBorder),
                  const SizedBox(height: 8),

                  const Text(
                    'Temporary Login Password',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),

                  SelectableText(
                    result['temp_password'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Copy this now. It will not be shown again.',
                    style: TextStyle(fontSize: 12, color: warning),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Candidate already exists. No new password generated.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── ASSIGNED JOBS ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assigned Jobs',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                ...(() {
                  final assignedJobs = (result['assigned_jobs'] as List?) ?? [];

                  if (assignedJobs.isEmpty) {
                    return const [
                      Text(
                        'No jobs assigned',
                        style: TextStyle(color: textSecondary),
                      ),
                    ];
                  }

                  return assignedJobs.map<Widget>(
                    (job) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${job['title'] ?? job}',
                        style: const TextStyle(color: textSecondary),
                      ),
                    ),
                  );
                })(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── CLOSE BUTTON ───
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                side: BorderSide(color: cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final String label;
  final double value; // 0–10

  const _SkillBar({required this.label, required this.value});

  double get _progress => (value / 10).clamp(0.0, 1.0);

  Color get _color {
    if (value >= 8) return success;
    if (value >= 6) return accent;
    if (value >= 4) return warning;
    return danger;
  }

  String get _level {
    if (value >= 8) return 'Excellent';
    if (value >= 6) return 'Good';
    if (value >= 4) return 'Average';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HEADER ROW ───
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  color: _color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ─── LEVEL TEXT ───
          Text(
            _level,
            style: TextStyle(
              color: _color.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 10),

          // ─── PROGRESS BAR ───
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) {
                return LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation(_color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function({
    required String candidateId,
    required String candidateName,
  })
  onDelete;

  const _CandidateTile({required this.data, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final profile = data['profile'] ?? {};
    final interview = data['interview'] ?? {};
    final bool completed = interview['status'] == 'completed';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: completed
            ? () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: 0.65,
                    maxChildSize: 0.75,
                    expand: false,
                    builder: (_, __) => Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: InterviewDetailSheet(interviewId: interview['id']),
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // AVATAR
              CircleAvatar(
                radius: 22,
                backgroundColor: completed
                    ? success.withOpacity(0.2)
                    : warning.withOpacity(0.2),
                child: Text(
                  (profile['name'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                    color: completed ? success : warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // NAME + STATUS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile['name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed ? 'Interview Completed' : 'Interview Pending',
                      style: TextStyle(
                        color: completed ? success : warning,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // SCORE + DELETE
              Column(
                children: [
                  if (completed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${interview['total_score']} / 100',
                        style: const TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: danger,
                      size: 20,
                    ),
                    onPressed: () => onDelete(
                      candidateId: profile['id'],
                      candidateName: profile['name'] ?? 'Candidate',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveJobsShimmer extends StatelessWidget {
  const _ActiveJobsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(width: 180, height: 18),
                    const SizedBox(height: 12),
                    _block(width: 120, height: 14),
                    const SizedBox(height: 14),
                    _block(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  static Widget _block({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cardBorder.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
