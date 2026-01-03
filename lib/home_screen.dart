import 'package:flutter/material.dart';
import 'app_service.dart';
import 'login_screen.dart';
import 'voice_interview_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    debugPrint('Candidate UID => ${user?.id}');
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    try {
      final data = await AppService.instance.fetchCandidateJobs();
      setState(() => _jobs = data);
    } catch (e) {
      debugPrint('❌ HomeScreen error: $e');
    } finally {
      setState(() => _loading = false);
    }
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

  Future<void> _startInterview(String jobId) async {
    final interviewId = await AppService.instance.startInterviewForJob(jobId);

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VoiceInterviewScreen(interviewId: interviewId, jobId: jobId),
      ),
    );

    if (result == true) {
      await _loadJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'My Interviews',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: _loadJobs,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _WelcomeHeader(),
                  const SizedBox(height: 24),
                  ..._jobs.map(
                    (job) => _InterviewCard(
                      title: job['title'],
                      status: job['interview_status'],
                      onStart: job['interview_status'] != 'completed'
                          ? () => _startInterview(job['job_id'])
                          : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F8CFF), Color(0xFF6FA1FF)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Welcome 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your assigned interviews are ready below',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  final String title;
  final String? status;
  final VoidCallback? onStart;

  const _InterviewCard({
    required this.title,
    required this.status,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final bool completed = status == 'completed';
    final bool inProgress = status == 'in_progress';

    Color accentColor;
    String statusText;
    IconData statusIcon;

    if (completed) {
      accentColor = Colors.green;
      statusText = 'Completed';
      statusIcon = Icons.check_circle;
    } else if (inProgress) {
      accentColor = Colors.orange;
      statusText = 'In Progress';
      statusIcon = Icons.play_circle_fill;
    } else {
      accentColor = Colors.blue;
      statusText = 'Not Started';
      statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🔵 LEFT ACCENT
          Container(
            width: 6,
            height: 140,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // STATUS CHIP
                  Row(
                    children: [
                      Icon(statusIcon, size: 18, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // CTA BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: completed ? null : onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: completed
                            ? Colors.grey.shade300
                            : accentColor,
                        foregroundColor: completed ? Colors.grey : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        completed
                            ? 'Interview Completed'
                            : inProgress
                            ? 'Resume Interview'
                            : 'Start Interview',
                        style: const TextStyle(
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
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 72,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No interviews assigned',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'You will see them here once assigned',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
