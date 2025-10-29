import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DigitalPictureFrameApp());
}

class DigitalPictureFrameApp extends StatelessWidget {
  const DigitalPictureFrameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Picture Frame',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
        useMaterial3: true,
      ),
      home: const PictureFrameScreen(),
    );
  }
}

class PictureFrameScreen extends StatefulWidget {
  const PictureFrameScreen({super.key});

  @override
  State<PictureFrameScreen> createState() => _PictureFrameScreenState();
}

class _PictureFrameScreenState extends State<PictureFrameScreen> {
  // --- your S3 images ---
  final List<String> _imageUrls = const [
    'https://digital-picture-frame-jashan.s3.us-east-2.amazonaws.com/IMG_20220113_064421.jpg',
    'https://digital-picture-frame-jashan.s3.us-east-2.amazonaws.com/IMG_20230611_124104.jpg',
    'https://digital-picture-frame-jashan.s3.us-east-2.amazonaws.com/IMG_20230610_154614.jpg',
    'https://digital-picture-frame-jashan.s3.us-east-2.amazonaws.com/IMG_20230719_142811_508.jpg',
  ];

  // slideshow state
  int _index = 0;
  bool _paused = false;
  bool _shuffle = false;
  int _intervalSeconds = 10; // adjustable 3..30
  Timer? _timer;

  // UI auto-hide
  bool _uiVisible = true;
  Timer? _hideUiTimer;

  // smooth zoom per slide
  bool _zoomFlag = false;

  // for keyboard
  final FocusNode _focusNode = FocusNode();

  bool _didInitialPrecache = false;

  @override
  void initState() {
    super.initState();
    if (_imageUrls.isNotEmpty) _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialPrecache && _imageUrls.isNotEmpty) {
      _didInitialPrecache = true;
      _precacheNext();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideUiTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  // ---- helpers ----

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _intervalSeconds), (_) {
      if (!_paused) _next();
    });
  }

  void _bumpUi() {
    if (!_uiVisible) setState(() => _uiVisible = true);
    _hideUiTimer?.cancel();
    _hideUiTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _uiVisible = false);
    });
  }

  void _precacheNext() {
    if (!mounted || _imageUrls.isEmpty) return;
    final next = (_index + 1) % _imageUrls.length;
    precacheImage(CachedNetworkImageProvider(_imageUrls[next]), context);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _bumpUi();
  }

  void _toggleShuffle() {
    setState(() => _shuffle = !_shuffle);
    _bumpUi();
  }

  void _toggleFullscreen() {
    _bumpUi();
    SystemChrome.setEnabledSystemUIMode(
      _uiVisible ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _setInterval(double seconds) {
    _intervalSeconds = seconds.round().clamp(3, 30);
    _startTimer();
    _bumpUi();
    setState(() {});
  }

  void _next() {
    if (_imageUrls.isEmpty) return;
    setState(() {
      if (_shuffle && _imageUrls.length > 1) {
        int nextIndex;
        do {
          nextIndex = math.Random().nextInt(_imageUrls.length);
        } while (nextIndex == _index);
        _index = nextIndex;
      } else {
        _index = (_index + 1) % _imageUrls.length;
      }
      _zoomFlag = !_zoomFlag; // alternate for subtle zoom direction
    });
    _precacheNext();
  }

  void _prev() {
    if (_imageUrls.isEmpty) return;
    setState(() {
      _index = (_index - 1 + _imageUrls.length) % _imageUrls.length;
      _zoomFlag = !_zoomFlag;
    });
    _precacheNext();
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final hasImages = _imageUrls.isNotEmpty;
    final currentUrl = hasImages ? _imageUrls[_index] : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (evt) {
          if (evt is RawKeyDownEvent) {
            if (evt.logicalKey == LogicalKeyboardKey.arrowRight) _next();
            if (evt.logicalKey == LogicalKeyboardKey.arrowLeft) _prev();
            if (evt.logicalKey == LogicalKeyboardKey.space) _togglePause();
            _bumpUi();
          }
        },
        child: MouseRegion(
          onHover: (_) => _bumpUi(),
          child: GestureDetector(
            onTap: () {
              _next();
              _bumpUi();
            },
            onDoubleTap: () {
              _prev();
              _bumpUi();
            },
            child: LayoutBuilder(
              builder: (context, c) {
                final isLandscape = c.maxWidth > c.maxHeight;

                // BIG photo: nearly edge-to-edge, keep small margin at bottom for controls
                final double maxW = c.maxWidth * 0.99;
                final double maxH = c.maxHeight * 0.86;

                // Elegant ratios
                final double aspect = isLandscape ? (16 / 9) : (4 / 3);

                double frameW = maxW;
                double frameH = frameW / aspect;
                if (frameH > maxH) {
                  frameH = maxH;
                  frameW = frameH * aspect;
                }

                return Stack(
                  children: [
                    // soft gradient background + vignette
                    const _Backdrop(),
                    // centered “physical” frame with shadow
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: frameW,
                        height: frameH,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD9A5), Color(0xFFFFBA66), Color(0xFFFFD9A5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 34,
                              spreadRadius: 2,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 700),
                            switchInCurve: Curves.easeInOut,
                            switchOutCurve: Curves.easeInOut,
                            layoutBuilder: (currentChild, previousChildren) => Stack(
                              fit: StackFit.expand,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                            child: currentUrl == null
                                ? const _EmptyNotice()
                                : _ZoomFadeImage(
                                    key: ValueKey(currentUrl),
                                    url: currentUrl,
                                    zoomIn: _zoomFlag,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // dots
                    if (hasImages)
                      Positioned(
                        bottom: 96,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          opacity: _uiVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _imageUrls.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _index == i ? 16 : 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: _index == i ? const Color(0xFF6C5CE7) : Colors.grey.shade500,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // glass controls
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: _uiVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 6)),
                              ],
                              border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Previous (←)',
                                      icon: const Icon(Icons.chevron_left_rounded),
                                      iconSize: 34,
                                      onPressed: hasImages ? _prev : null,
                                    ),
                                    const SizedBox(width: 2),
                                    FilledButton.tonal(
                                      onPressed: hasImages ? _togglePause : null,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                                          const SizedBox(width: 6),
                                          Text(_paused ? 'Resume' : 'Pause'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    IconButton(
                                      tooltip: 'Next (→)',
                                      icon: const Icon(Icons.chevron_right_rounded),
                                      iconSize: 34,
                                      onPressed: hasImages ? _next : null,
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Shuffle',
                                      onPressed: hasImages ? _toggleShuffle : null,
                                      icon: Icon(
                                        Icons.shuffle_rounded,
                                        color: _shuffle ? const Color(0xFF6C5CE7) : Colors.black87,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Fullscreen',
                                      onPressed: _toggleFullscreen,
                                      icon: const Icon(Icons.fullscreen_rounded),
                                    ),
                                  ],
                                ),

                                // speed slider
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 220,
                                      child: Slider(
                                        min: 3,
                                        max: 30,
                                        divisions: 27,
                                        value: _intervalSeconds.toDouble(),
                                        label: '${_intervalSeconds}s',
                                        onChanged: (v) => _setInterval(v),
                                      ),
                                    ),
                                    Text('${_intervalSeconds}s', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// soft gradient + vignette background
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F7FB), Color(0xFFEDEFFE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Container(
        // vignette
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Colors.transparent, Colors.transparent, Color(0x1A000000)],
            radius: 1.0,
            stops: [0.6, 0.85, 1.0],
          ),
        ),
      ),
    );
  }
}

// image with fade + subtle zoom
class _ZoomFadeImage extends StatelessWidget {
  final String url;
  final bool zoomIn;
  const _ZoomFadeImage({required this.url, required this.zoomIn, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: zoomIn ? 1.02 : 1.0, end: zoomIn ? 1.0 : 1.02),
      duration: const Duration(seconds: 6),
      curve: Curves.easeInOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 350),
        fadeOutDuration: const Duration(milliseconds: 250),
        placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, _, __) =>
            const Center(child: Text('Image failed to load', style: TextStyle(fontWeight: FontWeight.bold))),
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(
        child: Text(
          'Add at least one JPG URL to _imageUrls',
          style: TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
