import 'package:flutter/material.dart';

class HammerLoadingIndicator extends StatefulWidget {
  const HammerLoadingIndicator({
    super.key,
    this.size = 92,
    this.label,
    this.animate = true,
  });

  final double size;
  final String? label;
  final bool animate;

  @override
  State<HammerLoadingIndicator> createState() => _HammerLoadingIndicatorState();
}

class _HammerLoadingIndicatorState extends State<HammerLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  double _previousT = 0;
  double _nailDepthStage = 0;
  int _hitCountInSet = 0;
  var _hitRegisteredInCycle = false;

  void _onTick() {
    final t = _controller.value;
    const impactT = 0.6;

    if (t < _previousT) {
      _hitRegisteredInCycle = false;
      if (_hitCountInSet >= 3 && _nailDepthStage != 0) {
        setState(() {
          _hitCountInSet = 0;
          _nailDepthStage = 0;
        });
      }
    }
    if (!_hitRegisteredInCycle && t >= impactT) {
      _hitRegisteredInCycle = true;
      setState(() {
        if (_hitCountInSet < 3) {
          _hitCountInSet += 1;
        }
        // 1타/2타/3타 누적 깊이(과도한 관입 방지용 미세 조정).
        const depthByHit = <double>[0.0, 0.46, 0.62, 0.84];
        _nailDepthStage = depthByHit[_hitCountInSet];
      });
    }
    _previousT = t;
  }

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.addListener(_onTick);
      _controller.repeat();
    } else {
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant HammerLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate == widget.animate) return;
    if (widget.animate) {
      _controller
        ..value = 0
        ..addListener(_onTick)
        ..repeat();
      _previousT = 0;
      _nailDepthStage = 0;
      _hitCountInSet = 0;
      _hitRegisteredInCycle = false;
      return;
    }
    _controller
      ..stop()
      ..removeListener(_onTick)
      ..value = 0;
    setState(() {
      _previousT = 0;
      _nailDepthStage = 0;
      _hitCountInSet = 0;
      _hitRegisteredInCycle = false;
    });
  }

  @override
  void dispose() {
    if (widget.animate) {
      _controller.removeListener(_onTick);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boundedSize = widget.size.clamp(72.0, 220.0).toDouble();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        const impactT = 0.6;
        const recoverStartT = 0.78;
        const raiseAngle = 1.3; // upper-right ready pose
        const strikeAngle = -0.96; // down-left strike pose

        final downProgress = t < impactT
            ? Curves.easeInCubic.transform(t / impactT)
            : t < recoverStartT
                ? 1 -
                    (Curves.easeOut.transform(
                            (t - impactT) / (recoverStartT - impactT)) *
                        0.1)
                : 0.9 *
                    (1 -
                        Curves.easeInOut.transform(
                            (t - recoverStartT) / (1 - recoverStartT)));

        // Strike pulse — 타격 직후 조금 더 길게 남기며 감쇠.
        final hitWindow = (1 - ((t - impactT).abs() / 0.09)).clamp(0.0, 1.0);
        final impact = Curves.easeOutCubic.transform(hitWindow);
        final impactBurst = Curves.easeOut.transform(hitWindow);
        final progressiveSink = widget.size * 0.30 * _nailDepthStage;
        final exposureStage = _nailDepthStage.clamp(0.0, 1.0);
        final headTopOffset = widget.size * 0.225 * exposureStage;
        final shaftTopOffset = headTopOffset + (widget.size * 0.045);
        final exposedShaftHeight = (widget.size * 0.31 * (1 - exposureStage))
            .clamp(0.0, widget.size * 0.31);
        // Nail position must never rebound upward between hits.
        final nailSink = progressiveSink.clamp(0.0, widget.size * 0.185);
        final hammerAngle =
            raiseAngle + ((strikeAngle - raiseAngle) * downProgress);
        final hammerImpactDrop = widget.size * 0.028 * impact;
        final hammerFollowDrop = nailSink * 0.72;
        final hammerImpactShiftX = -widget.size * 0.06 * impact;
        const nailColor = Color(0xFF656B73);
        const sparkColor = Color(0xFFFFE066);
        const sparkHotColor = Color(0xFFFFF6C8);
        const flashColor = Color(0xFFFFFFFF);
        const plankColor = Color(0xFFC58A47);
        const plankShadowColor = Color(0xFF8D5A2B);
        const hammerHeadColor = Color(0xFF5F6368);
        const hammerHeadEdgeColor = Color(0xFFD9DDE2);
        // [판자 위치 기준]
        // - plankBottom: 판자의 y 시작점(아래 기준)
        // - plankHeight: 판자 높이
        // - plankTop: 판자 상단 y
        final plankBottom = widget.size * 0.12;
        final plankHeight = widget.size * 0.12;
        final plankTop = plankBottom + plankHeight;
        // [못 위치 기준]
        // 못의 기본 y(바닥 기준). 판자 상단에 맞춰 틈 없이 붙게 조정.
        final nailBaseBottom = plankTop - (widget.size * 0.03);
        final canvasWidth = widget.size * 1.22;
        final canvasHeight = widget.size * 1.16;

        final base = SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                // [못 X/Y 좌표]
                // left: 못의 좌우 위치
                // bottom: 못의 기본 높이(판자 상단 기준)
                left: widget.size * 0.52,
                bottom: nailBaseBottom,
                child: Transform.translate(
                  offset: Offset(0, nailSink),
                  child: SizedBox(
                    width: widget.size * 0.12,
                    height: widget.size * 0.46,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          top: shaftTopOffset,
                          child: exposedShaftHeight <= 0
                              ? const SizedBox.shrink()
                              : Container(
                                  width: widget.size * 0.044,
                                  height: exposedShaftHeight,
                                  decoration: BoxDecoration(
                                    color: nailColor,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.38),
                                      width: widget.size * 0.005,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 3.2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        Container(
                          width: widget.size * 0.13,
                          height: widget.size * 0.06,
                          margin: EdgeInsets.only(top: headTopOffset),
                          decoration: BoxDecoration(
                            color: nailColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.38),
                              width: widget.size * 0.005,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.32),
                                blurRadius: 3.2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                // [판자 X/Y 좌표]
                // left: 판자의 좌우 위치
                // bottom: 판자의 높이(아래 기준)
                left: widget.size * 0.41,
                bottom: plankBottom,
                child: Transform.scale(
                  scaleY: 1 - (impact * 0.08),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: widget.size * 0.34,
                    height: plankHeight,
                    decoration: BoxDecoration(
                      color: plankColor,
                      borderRadius: BorderRadius.circular(widget.size * 0.02),
                      border: Border.all(
                        color: plankShadowColor.withValues(alpha: 0.8),
                        width: widget.size * 0.012,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 7,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: widget.size * 0.045,
                          top: widget.size * 0.022,
                          child: Container(
                            width: widget.size * 0.25,
                            height: widget.size * 0.01,
                            color: plankShadowColor.withValues(alpha: 0.25),
                          ),
                        ),
                        Positioned(
                          left: widget.size * 0.045,
                          bottom: widget.size * 0.022,
                          child: Container(
                            width: widget.size * 0.23,
                            height: widget.size * 0.01,
                            color: plankShadowColor.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                // [타격 이펙트 — 플래시 + 충격파 + 스파크]
                left: widget.size * 0.42,
                bottom: widget.size * (0.50 - (nailSink / widget.size)),
                child: IgnorePointer(
                  child: SizedBox(
                    width: widget.size * 0.32,
                    height: widget.size * 0.28,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 중앙 플래시
                        Opacity(
                          opacity: (impact * 0.85).clamp(0.0, 1.0),
                          child: Container(
                            width: widget.size * (0.10 + 0.08 * impactBurst),
                            height: widget.size * (0.10 + 0.08 * impactBurst),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  flashColor.withValues(alpha: 0.95),
                                  sparkHotColor.withValues(alpha: 0.75),
                                  sparkColor.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.35, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: sparkColor.withValues(alpha: 0.85),
                                  blurRadius: widget.size * 0.18,
                                  spreadRadius: widget.size * 0.02,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 충격파 링
                        Opacity(
                          opacity: (impact * 0.7).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.55 + (0.9 * impactBurst),
                            child: Container(
                              width: widget.size * 0.22,
                              height: widget.size * 0.22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sparkHotColor.withValues(
                                    alpha: 0.9 * impact,
                                  ),
                                  width: widget.size * 0.018,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: sparkColor.withValues(alpha: 0.55),
                                    blurRadius: widget.size * 0.08,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 방사형 스파크
                        for (final spark in const [
                          (angle: -1.15, len: 0.15, thick: 0.028),
                          (angle: -0.55, len: 0.12, thick: 0.022),
                          (angle: 0.0, len: 0.11, thick: 0.02),
                          (angle: 0.55, len: 0.12, thick: 0.022),
                          (angle: 1.15, len: 0.15, thick: 0.028),
                          (angle: -1.65, len: 0.09, thick: 0.018),
                          (angle: 1.65, len: 0.09, thick: 0.018),
                        ])
                          Opacity(
                            opacity: (impact * 0.98).clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: spark.angle,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  -widget.size * (0.04 + 0.05 * impactBurst),
                                ),
                                child: Container(
                                  width: widget.size * spark.thick,
                                  height: widget.size *
                                      (spark.len * (0.75 + 0.55 * impactBurst)),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        flashColor.withValues(alpha: 1),
                                        sparkHotColor.withValues(alpha: 0.98),
                                        sparkColor.withValues(alpha: 0.15),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            sparkColor.withValues(alpha: 0.9),
                                        blurRadius: widget.size * 0.08,
                                        spreadRadius: widget.size * 0.004,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                // [망치 X/Y 좌표]
                // left: 망치의 좌우 시작 위치
                // bottom: 망치의 기본 높이
                left: widget.size * 0.9,
                bottom: widget.size * 0.5,
                child: Transform.translate(
                  offset: Offset(
                    hammerImpactShiftX,
                    hammerImpactDrop + hammerFollowDrop,
                  ),
                  child: Transform.rotate(
                    angle: hammerAngle,
                    alignment: const Alignment(0.55, 0.99),
                    child: Transform.scale(
                      scale: 0.95,
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: widget.size * 0.34,
                        height: widget.size * 0.56,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: widget.size * 0.1,
                                decoration: BoxDecoration(
                                  color: hammerHeadColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: hammerHeadEdgeColor.withValues(
                                        alpha: 0.9),
                                    width: widget.size * 0.005,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.28),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: widget.size * 0.08,
                              left: widget.size * 0.145,
                              child: Container(
                                width: widget.size * 0.055,
                                height: widget.size * 0.47,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8D6E63),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    width: widget.size * 0.004,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.24),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final scaledIndicator = SizedBox.square(
          dimension: boundedSize,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: base,
          ),
        );

        if (widget.label == null || widget.label!.trim().isEmpty) {
          return scaledIndicator;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            scaledIndicator,
            const SizedBox(height: 12),
            Text(
              widget.label!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        );
      },
    );
  }
}
