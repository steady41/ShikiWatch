import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/extensions/buildcontext.dart';

class FloatingNavigationDestination {
  final String label;
  final Widget icon;
  final Widget? selectedIcon;
  // final void Function(BuildContext context, LongPressStartDetails details)?
  //     onLongPress;
  final void Function(BuildContext context)? onLongPress;

  const FloatingNavigationDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.onLongPress,
  });
}

class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.labelBehavior = NavigationDestinationLabelBehavior.alwaysShow,
  });

  final List<FloatingNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final NavigationDestinationLabelBehavior labelBehavior;

  static const double _barHeight = 62.0; // 72
  static const double _horizontalPadding = 16.0;
  static const double _blurSigma = 6.0;
  static const double _borderRadius = 32.0;
  static const double _itemBorderRadius = 32.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPadding = (bottom == 0 ? 16.0 : bottom + 8);

    final itemWidth = (MediaQuery.sizeOf(context).width / destinations.length) -
        _horizontalPadding * 3;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _barHeight + bottomPadding,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Colors.black,
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ColoredBox(color: context.theme.scaffoldBackgroundColor),
          ),
        ),
        SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _horizontalPadding,
              0,
              _horizontalPadding,
              bottomPadding,
            ),
            child: UnconstrainedBox(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_borderRadius),
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
                  child: Container(
                    height: _barHeight,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      // color: context.colorScheme.surface.withOpacity(0.8),
                      color: context.theme.scaffoldBackgroundColor
                          .withOpacity(0.8),
                      // border: Border.all(
                      //   color: context.colorScheme.outlineVariant,
                      //   width: 2,
                      // ),
                      borderRadius: BorderRadius.circular(_borderRadius),
                      boxShadow: [
                        BoxShadow(
                          // color:
                          //     context.colorScheme.onInverseSurface.withOpacity(0.5),
                          // color: context.colorScheme.surface,
                          color: context.colorScheme.onInverseSurface,
                          // color:
                          //     context.colorScheme.surfaceTint.withOpacity(0.25),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        children: List.generate(
                          destinations.length,
                          (index) {
                            return _FloatingNavigationBarItem(
                              destination: destinations[index],
                              isSelected: selectedIndex == index,
                              labelBehavior: labelBehavior,
                              onTap: () => onDestinationSelected(index),
                              borderRadius: _itemBorderRadius,
                              width: itemWidth,
                            );
                          },
                        ),
                      ),
                    ),
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

class _FloatingNavigationBarItem extends StatelessWidget {
  const _FloatingNavigationBarItem({
    required this.destination,
    required this.isSelected,
    required this.labelBehavior,
    required this.onTap,
    required this.borderRadius,
    required this.width,
  });

  final FloatingNavigationDestination destination;
  final bool isSelected;
  final NavigationDestinationLabelBehavior labelBehavior;
  final VoidCallback onTap;
  final double borderRadius;
  final double width;

  @override
  Widget build(BuildContext context) {
    final bool showLabel = labelBehavior ==
            NavigationDestinationLabelBehavior.alwaysShow ||
        (labelBehavior == NavigationDestinationLabelBehavior.onlyShowSelected &&
            isSelected);

    final Widget icon = destination.selectedIcon != null
        ? AnimatedCrossFade(
            firstChild: destination.selectedIcon!,
            secondChild: destination.icon,
            crossFadeState: isSelected
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            firstCurve: Curves.fastOutSlowIn,
            secondCurve: Curves.fastOutSlowIn,
          )
        : destination.icon;

    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(borderRadius),
      child: GestureDetector(
        // HapticFeedback.lightImpact();
        // onLongPressStart: destination.onLongPress != null
        //     ? (details) => destination.onLongPress!(context, details)
        //     : null,

        child: InkWell(
          // onLongPress: destination.onLongPress != null
          //     ? () => destination.onLongPress!(context)
          //     : null,
          onLongPress: destination.onLongPress != null
              ? () {
                  HapticFeedback.lightImpact();
                  destination.onLongPress!(context);
                }
              : null,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colorScheme.primary.withOpacity(0.25)
                  : null,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            width: width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: 20,
                    color: isSelected
                        ? context.colorScheme.onSecondaryContainer
                        : context.colorScheme.onSurfaceVariant,
                  ),
                  child: icon,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.fastOutSlowIn,
                  alignment: Alignment.center,
                  child: showLabel
                      ? Padding(
                          padding:
                              const EdgeInsets.fromLTRB(6.0, 2.0, 6.0, 0.0),
                          child: Text(
                            destination.label,
                            style: context.textTheme.titleSmall?.copyWith(
                              fontSize: 12,
                              // color: context.colorScheme.onSurface,
                              color: isSelected
                                  ? context.colorScheme.onSecondaryContainer
                                  : context.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
