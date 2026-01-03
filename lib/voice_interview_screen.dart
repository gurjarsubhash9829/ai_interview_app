import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'app_service.dart';
import 'package:camera/camera.dart';

class VoiceInterviewScreen extends StatefulWidget {
  final String interviewId;
  final String jobId; // 🔥 ADD THIS

  const VoiceInterviewScreen({
    super.key,
    required this.interviewId,
    required this.jobId, // 🔥 ADD THIS
  });

  @override
  State<VoiceInterviewScreen> createState() => _VoiceInterviewScreenState();
}

class _VoiceInterviewScreenState extends State<VoiceInterviewScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _tts = FlutterTts();
  int _questionIndex = 0;
  CameraController? _cameraController;
  bool _cameraOn = false;
  bool _cameraInitialized = false;

  bool _recorderReady = false;
  bool _isRecording = false;
  bool _answerSubmitted = false;
  bool _loadingQuestion = false;
  bool _completed = false;
  bool _isListening = false;
  String _liveText = '';

  String _currentQuestion = '';
  String _recognizedText = '';
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recorder.closeRecorder();
    _tts.stop();
    super.dispose();
  }

  // =====================================================
  // INIT
  // =====================================================
  Future<void> _init() async {
    await _recorder.openRecorder();
    _recorderReady = true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);

    await http.post(
      Uri.parse('http://192.168.130.137:3000/interview/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'interview_id': widget.interviewId,
        'job_id': widget.jobId, // ✅ single source of truth
      }),
    );

    // 3️⃣ Load first question
    await _loadCurrentQuestion();
  }

  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false, // ❌ IMPORTANT: no mic conflict
    );

    await _cameraController!.initialize();

    if (!mounted) return;

    setState(() {
      _cameraInitialized = true;
      _cameraOn = true;
    });
  }

  Future<void> _stopCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;

    setState(() {
      _cameraInitialized = false;
      _cameraOn = false;
    });
  }

  Future<void> _captureSnapshot(int questionIndex) async {
    if (!_cameraOn || !_cameraInitialized) return;

    final file = await _cameraController!.takePicture();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.130.137:3000/interview/snapshot'),
    );

    request.fields['interview_id'] = widget.interviewId;
    request.fields['question_index'] = questionIndex.toString();
    request.files.add(await http.MultipartFile.fromPath('image', file.path));

    final res = await request.send();
    final body = await res.stream.bytesToString();
    final decoded = jsonDecode(body);

    if (decoded['warning'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['warning']),
          backgroundColor: Colors.orange,
        ),
      );
    }

    if (decoded['terminal'] == true) {
      await _completeInterviewAndExit();
    }
  }

  // =====================================================
  // LOAD QUESTION
  // =====================================================

  Future<void> _loadCurrentQuestion({String? previousAnswer}) async {
    setState(() => _loadingQuestion = true);

    try {
      final res = await http.post(
        Uri.parse('http://192.168.130.137:3000/interview/next-question'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'interview_id': widget.interviewId,
          'previous_answer': previousAnswer,
        }),
      );

      final decoded = jsonDecode(res.body);

      // 🔥 TERMINAL: interview ended by backend
      if (decoded['terminal'] == true) {
        await _tts.stop();

        if (_isRecording) {
          await _recorder.stopRecorder();
        }

        if (!mounted) return;
        await _completeInterviewAndExit();
        return;
      }

      setState(() {
        _currentQuestion = decoded['question'] ?? '';
        _loadingQuestion = false;
        _questionIndex++; // ✅
      });
      _captureSnapshot(_questionIndex); // fire-and-forget
      await _tts.stop();
      await _tts.speak(_currentQuestion);
    } catch (e) {
      debugPrint('Load question failed: $e');

      setState(() {
        _currentQuestion = 'Please explain your approach.';
        _loadingQuestion = false;
      });

      await _tts.speak(_currentQuestion);
    }
  }

  // =====================================================
  // RECORDING
  // =====================================================
  Future<void> _startRecording() async {
    if (!_recorderReady || _isRecording || _completed || _answerSubmitted) {
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/answer_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
    );

    setState(() {
      _isRecording = true;
      _isListening = true; // ✅ NEW
      _liveText = 'Listening…'; // ✅ NEW
      _recordingPath = path;
      _recognizedText = '';
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    await _recorder.stopRecorder();

    setState(() {
      _isRecording = false;
      _isListening = false; // ✅ stop listening state
    });

    if (_recordingPath != null) {
      await _sendAudioToBackend(_recordingPath!);
    }
  }

  Future<void> _sendAudioToBackend(String path) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.130.137:3000/speech-to-text'),
    );
    request.files.add(await http.MultipartFile.fromPath('audio', path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final decoded = jsonDecode(body);

    final text = decoded['text'] ?? '';

    setState(() {
      _recognizedText = text;
      _answerSubmitted = true;
    });
  }

  // =====================================================
  // NEXT QUESTION / COMPLETE (BACKEND DRIVEN)
  // =====================================================

  Future<void> _completeInterviewAndExit() async {
    try {
      await http.post(
        Uri.parse('http://192.168.130.137:3000/interview/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'interview_id': widget.interviewId}),
      );
    } catch (e) {
      debugPrint('Complete interview failed: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _goToNextQuestion() async {
    final lastAnswer = _recognizedText;

    final res = await http.post(
      Uri.parse('http://192.168.130.137:3000/interview/advance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'interview_id': widget.interviewId,
        'answer': lastAnswer,
      }),
    );

    if (res.statusCode != 200) {
      debugPrint('Advance API failed: ${res.body}');
      return;
    }

    final decoded = jsonDecode(res.body);

    // 🔥 TERMINAL → INTERVIEW IS REALLY OVER
    if (decoded['terminal'] == true) {
      await _tts.stop();

      if (_isRecording) {
        await _recorder.stopRecorder();
      }

      await _completeInterviewAndExit();
      return;
    }

    // ⚠️ Warning handling
    if (decoded['warning'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['warning']),
          backgroundColor: Colors.orange,
        ),
      );

      setState(() {
        _answerSubmitted = false;
        _recognizedText = '';
      });
      return;
    }

    // ✅ Continue interview
    setState(() {
      _recognizedText = '';
      _answerSubmitted = false;
    });

    await _loadCurrentQuestion(previousAnswer: lastAnswer);
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Interview'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off),
            onPressed: () async {
              if (_cameraOn) {
                await _stopCamera();
              } else {
                await _startCamera();
              }
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_cameraOn && _cameraInitialized)
                Container(
                  height: 160,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              if (_cameraOn)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    '👀 Please keep your face visible',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),

              // ================= QUESTION BOX =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Question',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadingQuestion
                          ? 'Preparing question…'
                          : _currentQuestion,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ================= ANSWER BOX =================
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Answer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _isListening
                                ? 'Listening…'
                                : _recognizedText.isEmpty
                                ? 'Hold the mic button and speak your answer…'
                                : _recognizedText,
                            style: TextStyle(
                              fontSize: 15,
                              color: _isListening
                                  ? Colors.blue
                                  : _recognizedText.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                              fontStyle: _isListening
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ================= ACTION BUTTONS =================
              Row(
                children: [
                  // MIC BUTTON
                  Expanded(
                    child: GestureDetector(
                      onLongPress: _startRecording,
                      onLongPressUp: _stopRecording,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isRecording ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isRecording ? 'Recording…' : 'Hold to Speak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // NEXT BUTTON
                  if (_answerSubmitted)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _goToNextQuestion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    // 🔥 SAME FLOW AS VOICE
                    setState(() {
                      _recognizedText = "end interview";
                      _answerSubmitted = true;
                    });

                    await _goToNextQuestion();
                  },
                  child: const Text(
                    'End Interview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
