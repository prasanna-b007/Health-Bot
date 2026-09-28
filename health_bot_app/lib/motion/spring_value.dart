import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'apple_spring.dart';
import 'motion_query.dart';

/// Animates a single double toward [value] using a real spring simulation.
///
/// Unlike [TweenAnimationBuilder]/[AnimatedContainer], a retarget mid-flight
/// starts from the *current on-screen value and velocity* — never a jump —
/// so it can be interrupted and reversed at any instant. This is the
/// primitive every gesture-adjacent animation in the app builds on.
///
/// When the OS "Reduce Motion" setting is on, retargets jump instantly
/// instead of springing.
class SpringBuilder extends StatefulWidget {
  final double value;
  final double? from;
  final AppleSpring spring;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  const SpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.spring = AppleSpring.standard,
    this.from,
    this.child,
  });

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _ranEntrance = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.from ?? widget.value,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ranEntrance) {
      _ranEntrance = true;
      if (widget.from != null && widget.from != widget.value) {
        _runSpring(widget.value);
      }
    }
  }

  @override
  void didUpdateWidget(covariant SpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.value) {
      _runSpring(widget.value);
    }
  }

  void _runSpring(double target) {
    if (MotionQuery.reduceMotion(context)) {
      _controller.value = target;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        widget.spring.description,
        _controller.value,
        target,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          widget.builder(context, _controller.value, child),
      child: widget.child,
    );
  }
}
