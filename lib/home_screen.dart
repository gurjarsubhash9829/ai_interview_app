import 'package:flutter/material.dart';
import 'app_service.dart';
import 'login_screen.dart';
import 'voice_interview_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const LinearGradient appBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF030712), Color(0xFF050F2C), Color(0xFF0B3C5D)],
);

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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'My Interviews',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: appBackgroundGradient, // ✅ SAME GRADIENT
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _jobs.isEmpty
              ? const _EmptyState()
              : RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.black,
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
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─── LEFT ICON ───
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.work_outline,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // ─── TEXT ───
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your assigned interviews are ready',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
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

    late Color color;
    late String statusText;
    late IconData icon;

    if (completed) {
      color = Colors.green;
      statusText = 'Completed';
      icon = Icons.check_circle_rounded;
    } else if (inProgress) {
      color = Colors.orange;
      statusText = 'In Progress';
      icon = Icons.play_circle_fill_rounded;
    } else {
      color = Colors.blue;
      statusText = 'Not Started';
      icon = Icons.schedule_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04), // very subtle tint

        borderRadius: BorderRadius.circular(22),

        // ✅ LEFT SIDE BORDER ONLY
        border: Border(
          left: BorderSide(
            color: Colors.grey.shade300, // professional neutral grey
            width: 1.2,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 14),

            // STATUS BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // CTA BUTTON
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: completed ? null : onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: completed ? Colors.grey.shade200 : color,
                  foregroundColor: completed ? Colors.grey : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  completed
                      ? 'Interview Completed'
                      : inProgress
                      ? 'Resume Interview'
                      : 'Start Interview',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
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
            color: Colors.white70,
          ),
          SizedBox(height: 16),
          Text(
            'No interviews assigned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'You will see them here once assigned',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
