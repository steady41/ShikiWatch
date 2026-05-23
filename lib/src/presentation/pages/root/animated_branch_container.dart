import 'package:flutter/material.dart';

class FadeThroughIndexedStack extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;
  final Duration duration;

  const FadeThroughIndexedStack({
    super.key,
    required this.currentIndex,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeThroughIndexedStack> createState() =>
      _FadeThroughIndexedStackState();
}

class _FadeThroughIndexedStackState extends State<FadeThroughIndexedStack>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  int? _previousIndex;

  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _controller.addStatusListener(_onAnimationStatusChanged);
    _setupAnimations();
  }

  @override
  void didUpdateWidget(FadeThroughIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.currentIndex != _currentIndex) {
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = widget.currentIndex;
      });
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousIndex != null) {
      setState(() {
        _previousIndex = null;
      });
    }
  }

  void _setupAnimations() {
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 1.0, curve: Easing.legacy),
    );
    _scaleIn = Tween<double>(begin: 0.94, end: 1.0).animate(_fadeIn);
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Easing.legacy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(
        widget.children.length,
        (index) {
          final child = widget.children[index];
          final isCurrent = index == _currentIndex;
          final isPrevious = index == _previousIndex;

          if (isCurrent) {
            return FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: TickerMode(
                  enabled: true,
                  child: child,
                ),
              ),
            );
          }

          if (isPrevious) {
            return FadeTransition(
              opacity: _fadeOut,
              child: IgnorePointer(
                child: TickerMode(
                  enabled: true,
                  child: child,
                ),
              ),
            );
          }

          return Offstage(
            offstage: true,
            child: TickerMode(
              enabled: false,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class AnimatedBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _currentIndex;
  int? _previousIndex;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;
  late final Animation<double> _fadeOut;
  late final Animation<Offset> _slideOut;
  // late final Animation<double> _scaleIn;
  // late final Animation<double> _scaleOut;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1.0,
    );

    _setupAnimations();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _previousIndex != null) {
        setState(() {
          _previousIndex = null;
        });
      }
    });

    // _controller.forward();
  }

  void _setupAnimations() {
    final curveIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(curveIn);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(curveIn);

    final curveOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInCubic),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(curveOut);
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.01),
    ).animate(curveOut);

    // _scaleIn = Tween<double>(begin: 0.97, end: 1.0).animate(curveIn);
    // _scaleOut = Tween<double>(begin: 1.0, end: 1.05).animate(curveIn);
  }

  @override
  void didUpdateWidget(covariant AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _currentIndex) {
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = widget.currentIndex;
      });
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(
        widget.children.length,
        (index) {
          final child = widget.children[index];

          if (index == _currentIndex) {
            return _buildIncomingTransition(child);
          }

          if (index == _previousIndex) {
            return _buildOutgoingTransition(child);
          }

          return Offstage(
            offstage: true,
            child: TickerMode(
              enabled: false,
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncomingTransition(Widget child) {
    // return FadeTransition(
    //   opacity: _fadeIn,
    //   child: ScaleTransition(
    //     scale: _scaleIn,
    //     child: child,
    //   ),
    // );

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: child,
      ),
    );
  }

  Widget _buildOutgoingTransition(Widget child) {
    // return FadeTransition(
    //   opacity: _fadeOut,
    //   child: ScaleTransition(
    //     scale: _scaleOut,
    //     child: child,
    //   ),
    // );

    return FadeTransition(
      opacity: _fadeOut,
      child: SlideTransition(
        position: _slideOut,
        child: child,
      ),
    );
  }
}

/// Custom branch Navigator container that provides animated transitions
/// when switching branches.
// class AnimatedBranchContainer extends StatelessWidget {
//   /// Creates a AnimatedBranchContainer
//   const AnimatedBranchContainer({
//     super.key,
//     required this.currentIndex,
//     required this.children,
//   });

//   /// The index (in [children]) of the branch Navigator to display.
//   final int currentIndex;

//   /// The children (branch Navigators) to display in this container.
//   final List<Widget> children;

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: children.mapIndexed(
//         (int index, Widget navigator) {
//           return TweenAnimationBuilder<double>(
//             tween: Tween<double>(
//               begin: 0.0,
//               end: index == currentIndex ? 1.0 : 0.0,
//             ),
//             builder: (context, value, child) {
//               // return Transform.translate(
//               //   offset: Offset(0, 20 - (value * 20)),
//               //   child: Opacity(
//               //     opacity: value,
//               //     child: child,
//               //   ),
//               // );

//               return Opacity(
//                 opacity: value,
//                 child: Transform.translate(
//                   offset: Offset(0.0, 16.0 - (value * 16.0)),
//                   child: child,
//                 ),
//               );
//             },
//             curve: Curves.fastOutSlowIn, // fastOutSlowIn
//             duration: const Duration(milliseconds: 400),
//             //duration: const Duration(seconds: 1),
//             child: _branchNavigatorWrapper(index, navigator),
//           );
//         },
//       ).toList(),
//     );

//     // return Stack(
//     //   children: children.mapIndexed(
//     //     (int index, Widget navigator) {
//     //       return AnimatedOpacity(
//     //         opacity: index == currentIndex ? 1 : 0,
//     //         duration: const Duration(milliseconds: 300),
//     //         curve: Curves.fastOutSlowIn,
//     //         child: _branchNavigatorWrapper(index, navigator),
//     //       );
//     //     },
//     //   ).toList(),
//     // );
//   }

//   Widget _branchNavigatorWrapper(int index, Widget navigator) {
//     return IgnorePointer(
//       ignoring: index != currentIndex,
//       child: TickerMode(
//         enabled: index == currentIndex,
//         child: navigator,
//       ),
//     );
//   }
// }
