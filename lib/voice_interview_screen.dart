import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'app_service.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _cameraPinned = false; // true = movement locked

  bool _cameraDocked = false; // false = floating, true = fixed
  bool _endingInterview = false;

  Offset _cameraOffset = const Offset(16, 80);

  CameraController? _cameraController;
  bool _cameraOn = false;
  bool _cameraInitialized = false;
  String _displayedText = '';
  Timer? _typingTimer;

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

  void _animateRecognizedText(String fullText) {
    _typingTimer?.cancel();
    _displayedText = '';

    int index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (index >= fullText.length) {
        timer.cancel();
        return;
      }

      setState(() {
        _displayedText += fullText[index];
        index++;
      });
    });
  }

  // =====================================================
  // INIT
  // =====================================================
  Future<void> _init() async {
    await _ensureMicPermission(); // 🔥 ADD THIS FIRST
    await _recorder.openRecorder();
    _recorderReady = true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);

    await http.post(
      Uri.parse('http://10.184.218.137:3000/interview/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'interview_id': widget.interviewId,
        'job_id': widget.jobId, // ✅ single source of truth
      }),
    );

    // 3️⃣ Load first question
    await _loadCurrentQuestion();
  }

  Future<void> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_recorderReady || _completed || _answerSubmitted) return;

    if (_isRecording) {
      // 🛑 STOP
      await _recorder.stopRecorder();

      setState(() {
        _isRecording = false;
        _isListening = false;
      });

      if (_recordingPath != null) {
        await _sendAudioToBackend(_recordingPath!);
      }
    } else {
      // ✅ ENSURE TTS IS STOPPED
      await _tts.stop();

      // ⏱ Small delay to let audio session release
      await Future.delayed(const Duration(milliseconds: 200));

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/answer_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      setState(() {
        _isRecording = true;
        _isListening = true;
        _recordingPath = path;
        _recognizedText = '';
      });
    }
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
      Uri.parse('http://10.184.218.137:3000/interview/snapshot'),
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
    setState(() {
      _loadingQuestion = true;
      _currentQuestion = 'Preparing Question…';

      // 🔥 RESET PREVIOUS ANSWER STATE
      _recognizedText = '';
      _displayedText = '';
      _answerSubmitted = false;
      _isListening = false;
    });

    try {
      final res = await http.post(
        Uri.parse('http://10.184.218.137:3000/interview/next-question'),
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
      Uri.parse('http://10.184.218.137:3000/speech-to-text'),
    );
    request.files.add(await http.MultipartFile.fromPath('audio', path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final decoded = jsonDecode(body);

    final text = decoded['text'] ?? '';
    setState(() {
      _recognizedText = text;
      _answerSubmitted = true;
      _displayedText = ''; // reset before animation
    });

    _animateRecognizedText(text);
  }

  // =====================================================
  // NEXT QUESTION / COMPLETE (BACKEND DRIVEN)
  // =====================================================

  Future<void> _completeInterviewAndExit() async {
    try {
      await http.post(
        Uri.parse('http://10.184.218.137:3000/interview/complete'),
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
      Uri.parse('http://10.184.218.137:3000/interview/advance'),
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
        //backgroundColor: Colors.transparent,
        //foregroundColor: Colors.white,
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

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF030712), Color(0xFF050F2C), Color(0xFF0B3C5D)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                _buildContent(),

                if (_cameraOn && _cameraInitialized && !_cameraDocked)
                  _floatingCamera(),

                if (_endingInterview) _endingInterviewOverlay(), // 🔥 ADD
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _endingInterviewOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.82),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Finalizing your interview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait while we securely submit your responses.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingCamera() {
    final size = MediaQuery.of(context).size;

    return Positioned(
      left: _cameraOffset.dx,
      top: _cameraOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (_cameraPinned) return; // 🔒 hard stop when pinned

          setState(() {
            final dx = _cameraOffset.dx + details.delta.dx;
            final dy = _cameraOffset.dy + details.delta.dy;

            _cameraOffset = Offset(
              dx.clamp(8, size.width - 160),
              dy.clamp(8, size.height - 220),
            );
          });
        },

        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 🎥 CAMERA VIEW
              Container(
                width: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black,
                  border: Border.all(color: Colors.white24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),

              // 📌 PIN (LOCK / UNLOCK)
              Positioned(
                top: 6,
                left: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _cameraPinned = !_cameraPinned;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _cameraPinned
                          ? Colors.blue.withOpacity(0.85)
                          : Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _cameraPinned ? Icons.lock : Icons.lock_open,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // 🧲 DOCK BUTTON
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _cameraDocked = true;
                      _cameraPinned = false; // reset pin when docked
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // CAMERA PREVIEW
        if (_cameraOn && _cameraInitialized && _cameraDocked)
          Container(
            height: 180,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.black,
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              children: [
                // 🎥 FULL WIDTH CAMERA
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover, // 🔥 fills entire container
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height:
                            MediaQuery.of(context).size.width /
                            _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                ),

                // 🔓 FLOAT BUTTON (ON VIDEO ITSELF)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _cameraDocked = false;
                        _cameraPinned = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (_cameraOn)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '👀 Please keep your face visible',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          ),

        _questionCard(),
        const SizedBox(height: 16),
        _answerCard(),
        const SizedBox(height: 16),
        _actionButtons(),
        const SizedBox(height: 12),
        _endInterviewButton(),
      ],
    );
  }

  Widget _endInterviewButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.transparent,
        ),
        onPressed: () async {
          setState(() {
            _endingInterview = true; // 🔥 SHOW LOADER
            _recognizedText = 'end interview';
            _answerSubmitted = true;
          });

          await _goToNextQuestion();

          if (mounted) {
            setState(() {
              _endingInterview = false; // safety fallback
            });
          }
        },

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.stop_circle_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'End Interview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.transparent,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUESTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingQuestion) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: Colors.white54,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _currentQuestion,

            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _answerCard() {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR ANSWER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _isListening
                      ? 'Listening…'
                      : _displayedText.isEmpty
                      ? 'Tap the mic and speak your answer…'
                      : _displayedText,

                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: _isListening
                        ? const Color(0xFF2563EB)
                        : _recognizedText.isEmpty
                        ? Colors.grey
                        : Colors.grey,
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
    );
  }

  Widget _actionButtons() {
    final bool canRecord =
        !_loadingQuestion && !_answerSubmitted && !_completed;

    return Row(
      children: [
        // 🎤 MIC BUTTON (TAP TO TOGGLE)
        Expanded(
          flex: 2,
          child: IgnorePointer(
            ignoring: !canRecord,
            child: Opacity(
              opacity: canRecord ? 1.0 : 0.45,
              child: GestureDetector(
                onTap: canRecord ? _toggleRecording : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isRecording
                          ? [Colors.red, Colors.redAccent]
                          : const [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isRecording
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isRecording ? Icons.stop_circle : Icons.mic,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecording ? 'Tap to Stop' : 'Tap to Speak',
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
          ),
        ),

        const SizedBox(width: 12),

        // ➡️ NEXT BUTTON
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 56,
            child: AnimatedOpacity(
              opacity: _answerSubmitted ? 1 : 0.35,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_answerSubmitted,
                child: ElevatedButton(
                  onPressed: (_answerSubmitted && !_loadingQuestion)
                      ? _goToNextQuestion
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
