import 'package:flutter/material.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

// popover: 0.3.0
// import 'package:popover/popover.dart';

import '../../../services/secure_storage/secure_storage_service.dart';
import '../anime_soures/anime365/anime365_provider.dart';
import '../../../services/updater/update_service.dart';
import '../../widgets/mouse_back_button_wrapper.dart';
import '../../../utils/extensions/buildcontext.dart';
import '../../widgets/app_update_bottom_sheet.dart';
import '../../../domain/enums/library_state.dart';
import '../../providers/settings_provider.dart';
import '../library/library_page_appbar.dart';
import '../../widgets/cached_image.dart';
import '../../../utils/app_utils.dart';
import '../../../../kodik/kodik.dart';
import '../player/pip_provider.dart';

import 'animated_branch_container.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const ScaffoldWithNavBar({
    required this.navigationShell,
    required this.children,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    const breakpoint = 600.0;
    const expandedBreakpoint = 1200.0;

    ref.watch(anime365UserProvider);

    ref.listen(kodikWorkaroundProvider, (_, __) {});
    ref.listen(pipAvailabilityProvider, (_, __) {});

    ref.listen(
      appReleaseProvider,
      (_, state) => state.whenOrNull(
        data: (data) {
          if (data == null) {
            return;
          }
          AppUpdateBottomSheet.show(context: context, release: data);
        },
        // error: (error, stackTrace) {
        //   showErrorSnackBar(
        //     ctx: context,
        //     msg: 'Произошла ошибка при проверке обновлений приложения',
        //     dur: const Duration(seconds: 5),
        //   );
        // },
      ),
    );

    final NavigationDestinationLabelBehavior navDestLabelBehavior = ref.watch(
        settingsProvider.select((settings) => settings.navDestLabelBehavior));

    if (screenWidth >= breakpoint) {
      return MouseBackButtonWrapper(
        child: Scaffold(
          body: SafeArea(
            top: false,
            bottom: false,
            child: Row(
              children: [
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: IntrinsicHeight(
                      child: Theme(
                        data: context.theme.copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: NavigationRail(
                          extended: AppUtils.instance.isDesktop
                              ? screenWidth > 1600
                              : screenWidth > expandedBreakpoint,
                          groupAlignment: -1.0,
                          selectedIndex: navigationShell.currentIndex,
                          onDestinationSelected: _onDestinationSelected,
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.book_outlined),
                              selectedIcon: Icon(Icons.book),
                              label: Text('Библиотека'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.explore_outlined),
                              selectedIcon: Icon(Icons.explore_rounded),
                              label: Text('Обзор'),
                            ),
                            // NavigationRailDestination(
                            //   icon: Icon(Icons.forum_outlined),
                            //   selectedIcon: Icon(Icons.forum_rounded),
                            //   label: Text('Топики'),
                            // ),
                            NavigationRailDestination(
                              icon: Icon(Icons.person_outline),
                              selectedIcon: Icon(Icons.person),
                              label: Text('Профиль'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: AnimatedBranchContainer(
                    currentIndex: navigationShell.currentIndex,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AnimatedBranchContainer(
        currentIndex: navigationShell.currentIndex,
        children: children,
      ),
      bottomNavigationBar: Theme(
        data: context.theme.copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: NavigationBar(
          height: navDestLabelBehavior ==
                  NavigationDestinationLabelBehavior.alwaysHide
              ? 60
              : null,
          labelBehavior: navDestLabelBehavior,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: 'Библиотека',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Обзор',
            ),
            // NavigationDestination(
            //   icon: Icon(Icons.forum_outlined),
            //   selectedIcon: Icon(Icons.forum_rounded),
            //   label: 'Топики',
            // ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Профиль',
            ),
          ],
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );

    // return Scaffold(
    //   extendBody: true,
    //   body: AnimatedBranchContainer(
    //     currentIndex: navigationShell.currentIndex,
    //     children: children,
    //   ),
    //   bottomNavigationBar: FloatingNavigationBar(
    //     destinations: [
    //       FloatingNavigationDestination(
    //         label: 'Библиотека',
    //         icon: const Icon(Icons.book_outlined),
    //         selectedIcon: const Icon(Icons.book),
    //         onLongPress: (itemContext) => showPopover(
    //           context: itemContext,
    //           backgroundColor: context.colorScheme.background,
    //           direction: PopoverDirection.top,
    //           transition: PopoverTransition.other,
    //           radius: 16,
    //           width: 240,
    //           // height: 120,
    //           arrowHeight: 12,
    //           arrowWidth: 0,
    //           bodyBuilder: (context) => const LibraryContentPopup()
    //               .animate()
    //               .slideY(
    //                 begin: 0.025,
    //                 end: 0,
    //                 duration: const Duration(milliseconds: 250),
    //                 curve: Curves.easeOutCubic,
    //               )
    //               .fade(),
    //         ),
    //       ),
    //       const FloatingNavigationDestination(
    //         label: 'Обзор',
    //         icon: Icon(Icons.explore_outlined),
    //         selectedIcon: Icon(Icons.explore_rounded),
    //       ),
    //       const FloatingNavigationDestination(
    //         label: 'Ещё',
    //         icon: Icon(Icons.more_horiz),
    //         // selectedIcon: CircleAvatar(
    //         //   radius: 10,
    //         // ),
    //       ),
    //       // CircleAvatar(
    //       //   radius: 12,
    //       // ),
    //     ],
    //     selectedIndex: navigationShell.currentIndex,
    //     onDestinationSelected: _onDestinationSelected,
    //     labelBehavior: navDestLabelBehavior,
    //   ),
    // );
  }

  _onDestinationSelected(int tappedIndex) {
    navigationShell.goBranch(
      tappedIndex,
      initialLocation: tappedIndex == navigationShell.currentIndex,
    );
  }

  // _onDestinationSelected(BuildContext context, int tappedIndex) {
  //   if (tappedIndex == navigationShell.currentIndex &&
  //       GoRouterState.of(context).uri.toString() == '/explore') {
  //     context.push('/explore/search');
  //     return;
  //   }

  //   navigationShell.goBranch(
  //     tappedIndex,
  //     initialLocation: tappedIndex == navigationShell.currentIndex,
  //   );

  //   // if (navigationShell.currentIndex == tappedIndex) {
  //   //   navigationShell.shellRouteContext.navigatorKey.currentState
  //   //       ?.popUntil((r) => r.isFirst);
  //   // } else {
  //   //   navigationShell.goBranch(tappedIndex);
  //   // }
  // }
}

class LibraryContentPopup extends ConsumerWidget {
  const LibraryContentPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryStateProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            visualDensity: VisualDensity.comfortable,
            leading: CachedCircleImage(
              SecureStorageService.instance.userProfileImage,
              clipBehavior: Clip.antiAlias,
            ),
            title: Text(
              SecureStorageService.instance.userNickname,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          RadioListTile<LibraryFragmentMode>(
            visualDensity: VisualDensity.comfortable,
            title: const Text('Аниме'),
            value: LibraryFragmentMode.anime,
            groupValue: state,
            onChanged: (value) {
              ref.read(libraryStateProvider.notifier).state =
                  LibraryFragmentMode.anime;
              Navigator.of(context).pop();
            },
          ),
          RadioListTile<LibraryFragmentMode>(
            visualDensity: VisualDensity.comfortable,
            title: const Text('Манга и ранобе'),
            value: LibraryFragmentMode.manga,
            groupValue: state,
            onChanged: (value) {
              ref.read(libraryStateProvider.notifier).state =
                  LibraryFragmentMode.manga;
              Navigator.of(context).pop();
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.movie_rounded),
          //   title: const Text('Аниме'),
          //   onTap: () => Navigator.of(context).pop(),
          // ),
          // ListTile(
          //   leading: const Icon(Icons.menu_book_rounded),
          //   title: const Text('Манга и ранобе'),
          //   onTap: () => Navigator.of(context).pop(),
          // ),
        ],
      ),
    );
  }
}
