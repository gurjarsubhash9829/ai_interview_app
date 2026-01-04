import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AppService {
  AppService._();
  static final AppService instance = AppService._();

  final SupabaseClient client = Supabase.instance.client;

  /// 🚨 Hackathon only (ADMIN)
  final SupabaseClient adminClient = SupabaseClient(
    'https://vpczododcgvbnoxsbxny.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwY3pvZG9kY2d2Ym5veHNieG55Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Njg0NDA3OCwiZXhwIjoyMDgyNDIwMDc4fQ.OtXzFajjfrQNB33I3zcYp5ZagvezGiND9sB5UQjACh0',
  );

  // =====================================================
  // AUTH
  // =====================================================
  Future<void> login({
    required String email,
    required String password,
  }) async {
    debugPrint('🔵 LOGIN REQUEST');
    debugPrint('   email: $email');
    debugPrint('   password: ******');

    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('🟢 LOGIN RESPONSE');

      if (res.session != null) {
        debugPrint('   ✅ session created');
        debugPrint('   userId: ${res.user?.id}');
        debugPrint('   email: ${res.user?.email}');
      } else {
        debugPrint('   ⚠️ session is null');
      }

      if (res.session == null || res.user == null) {
        throw Exception('Login failed: session/user null');
      }
    } catch (e) {
      // 🔴 THIS IS WHAT YOU ARE MISSING
      debugPrint('🔴 LOGIN ERROR');
      debugPrint('   error: $e');
      rethrow;
    }
  }


  Future<void> logout() async {
    await client.auth.signOut();
  }

  User get _user => client.auth.currentUser!;

  Future<String?> getMyRole() async {
    final res = await client
        .from('profiles')
        .select('role')
        .eq('id', _user.id)
        .maybeSingle();
    return res?['role'];
  }

  // =====================================================
  // ADMIN → JOBS
  // =====================================================

  Future<Map<String, dynamic>> createJob({
    required String title,
    required String description,
    required int experienceRequired,
    required int questionCount,
    required String interviewTopics,
  }) async {
    final uri = Uri.parse('http://10.184.218.137:3000/admin/job/create');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'experience_required': experienceRequired,
        'question_count': questionCount,
        'interview_topics': interviewTopics,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Job creation failed');
    }

    return jsonDecode(res.body);
  }

  Future<void> createCandidate({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await adminClient.auth.admin.createUser(
      AdminUserAttributes(email: email, password: password, emailConfirm: true),
    );

    final userId = res.user?.id;
    if (userId == null) {
      throw Exception('User creation failed');
    }

    await adminClient.from('profiles').insert({
      'id': userId,
      'name': name,
      'email': email,
      'role': 'candidate',
    });
  }

  /// Admin Dashboard – Job list with candidate count
  Future<List<Map<String, dynamic>>> fetchAllJobsCandidates() async {
    final jobs = await client.from('jobs').select('id, title');
    if (jobs.isEmpty) return [];

    final mappings = await client.from('candidate_jobs').select('job_id');

    final Map<String, int> countMap = {};
    for (final row in mappings) {
      final jobId = row['job_id'];
      countMap[jobId] = (countMap[jobId] ?? 0) + 1;
    }

    return jobs.map<Map<String, dynamic>>((job) {
      return {
        'id': job['id'],
        'title': job['title'],
        'candidates_count': countMap[job['id']] ?? 0,
      };
    }).toList();
  }

  // =====================================================
  // ADMIN → JOB DETAIL (SAFE, NO CRASH)
  // =====================================================

  Future<List<Map<String, dynamic>>> fetchCandidatesForJob(String jobId) async {
    // 1️⃣ candidate_jobs
    final assignments = await client
        .from('candidate_jobs')
        .select('candidate_id')
        .eq('job_id', jobId);

    if (assignments.isEmpty) return [];

    final candidateIds = assignments
        .map((e) => e['candidate_id'] as String)
        .toList();

    // 2️⃣ profiles
    final profiles = await client
        .from('profiles')
        .select('id, name, email')
        .inFilter('id', candidateIds);

    // 3️⃣ interviews
    final interviews = await client
        .from('interviews')
        .select('id, candidate_id, status, total_score, transcript_pdf')
        .eq('job_id', jobId);

    // 4️⃣ merge (NULL SAFE)
    return profiles.map((p) {
      final interview = interviews.cast<Map<String, dynamic>>().firstWhere(
        (i) => i['candidate_id'] == p['id'],
        orElse: () => {},
      );

      return {'profile': p, 'interview': interview};
    }).toList();
  }

  // =====================================================
  // ADMIN → ASSIGN CANDIDATE (EXISTING FLOW)
  // =====================================================

  Future<List<Map<String, dynamic>>> fetchAllCandidates() async {
    final res = await adminClient
        .from('profiles')
        .select('id, name, email')
        .eq('role', 'candidate');

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> assignCandidateToJob({
    required String candidateId,
    required String jobId,
  }) async {
    final exists = await adminClient
        .from('candidate_jobs')
        .select('id')
        .eq('candidate_id', candidateId)
        .eq('job_id', jobId)
        .maybeSingle();

    if (exists != null) return;

    await adminClient.from('candidate_jobs').insert({
      'candidate_id': candidateId,
      'job_id': jobId,
    });
  }

  // =====================================================
  // CANDIDATE
  // =====================================================

  Future<List<Map<String, dynamic>>> fetchCandidateJobs() async {
    final res = await client
        .from('candidate_jobs')
        .select('''
          job_id,
          jobs ( id, title )
        ''')
        .eq('candidate_id', _user.id);

    final List<Map<String, dynamic>> out = [];

    for (final row in res) {
      final job = row['jobs'];

      final interview = await client
          .from('interviews')
          .select('id, status')
          .eq('job_id', row['job_id'])
          .eq('candidate_id', _user.id)
          .maybeSingle();

      out.add({
        'job_id': row['job_id'],
        'title': job['title'],
        'interview_id': interview?['id'],
        'interview_status': interview?['status'],
      });
    }

    return out;
  }

  Future<String> startInterviewForJob(String jobId) async {
    final existing = await client
        .from('interviews')
        .select('id')
        .eq('job_id', jobId)
        .eq('candidate_id', _user.id)
        .maybeSingle();

    if (existing != null) return existing['id'];

    final res = await client
        .from('interviews')
        .insert({
          'job_id': jobId,
          'candidate_id': _user.id,
          'status': 'in_progress',
        })
        .select()
        .single();

    return res['id'];
  }

  Future<void> markInterviewInProgress(String interviewId) async {
    await client
        .from('interviews')
        .update({'status': 'in_progress'})
        .eq('id', interviewId);
  }

  Future<void> completeInterview(String interviewId) async {
    await client
        .from('interviews')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', interviewId);
  }

  // =====================================================
  // ADMIN → INTERVIEW DETAILS
  // =====================================================

  Future<Map<String, dynamic>> fetchInterviewDetails(String interviewId) async {
    final res = await client
        .from('interviews')
        .select('''
  status,
  total_score,
  topic_breakdown,
  skill_summary,
  transcript_pdf,
  completed_at,
  profiles(name,email),
  jobs(title)
''')
        .eq('id', interviewId)
        .single();

    return Map<String, dynamic>.from(res);
  }

  // =====================================================
  // AI STUB
  // =====================================================
  Future<void> startRealtimeInterview({
    required String interviewId,
    required String jobId,
  }) async {
    await http.post(
      Uri.parse('http://10.184.218.137:3000/interview/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'interview_id': interviewId,
        'job_id': jobId,
        'question_count': 9999, // ignored now
      }),
    );
  }

  Future<Map<String, dynamic>> getNextQuestion({
    required String interviewId,
  }) async {
    final res = await http.post(
      Uri.parse('http://10.184.218.137:3000/interview/next-question'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'interview_id': interviewId}),
    );

    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> advanceInterview({
    required String interviewId,
    required String answer,
  }) async {
    final res = await http.post(
      Uri.parse('http://10.184.218.137:3000/interview/advance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'interview_id': interviewId, 'answer': answer}),
    );

    return jsonDecode(res.body);
  }

  // =====================================================
  // INTERVIEW → JOB CONFIG (READ ONLY)
  // =====================================================

  Future<Map<String, dynamic>> getJobConfigForInterview(
    String interviewId,
  ) async {
    final res = await client
        .from('interviews')
        .select('''
                job_id,
                jobs (
                  id,
                  title,
                  experience_required,
                  question_count
                )
              ''')
        .eq('id', interviewId)
        .single();

    return {
      'job_id': res['job_id'],
      'title': res['jobs']['title'],
      'experience_required': res['jobs']['experience_required'],
      'question_count': res['jobs']['question_count'],
    };
  }

  Future<void> removeCandidateFromJob({
    required String candidateId,
    required String jobId,
  }) async {
    await adminClient
        .from('candidate_jobs')
        .delete()
        .eq('candidate_id', candidateId)
        .eq('job_id', jobId);

    // 🔥 also remove interview if exists
    await adminClient
        .from('interviews')
        .delete()
        .eq('candidate_id', candidateId)
        .eq('job_id', jobId);
  }

  Future<void> deleteJob(String jobId) async {
    // 1️⃣ remove interviews
    await adminClient.from('interviews').delete().eq('job_id', jobId);

    // 2️⃣ remove candidate mappings
    await adminClient.from('candidate_jobs').delete().eq('job_id', jobId);

    // 3️⃣ delete job
    await adminClient.from('jobs').delete().eq('id', jobId);
  }

  Future<void> deleteCandidate(String candidateId) async {
    // 1️⃣ interviews
    await adminClient
        .from('interviews')
        .delete()
        .eq('candidate_id', candidateId);

    // 2️⃣ candidate_jobs
    await adminClient
        .from('candidate_jobs')
        .delete()
        .eq('candidate_id', candidateId);

    // 3️⃣ profile
    await adminClient.from('profiles').delete().eq('id', candidateId);

    // 4️⃣ auth user
    await adminClient.auth.admin.deleteUser(candidateId);
  }
}
