part of 'shell.dart';

/// The debug panel itself: the modal sheet the floating button opens, its app
/// bar and its bottom bar.
///
/// Split from `borealis_overlay.dart`, which had grown to hold the host
/// widget, the drag, the button, the page stack and all of this at once.
class DebugPanel extends StatefulWidget {
  const DebugPanel._({
    required this.pages,
    required this.onDismiss,
    required this.currentPage,
    required this.onPageChange,
    required this.outerTheme,
  });

  final List<BorealisPage> pages;
  final VoidCallback onDismiss;
  final int currentPage;
  final ValueChanged<int> onPageChange;
  final ThemeData outerTheme;

  static void show(
    BuildContext context, {
    required List<BorealisPage> pages,
    required VoidCallback onDismiss,
    int currentPage = 0,
    required ValueChanged<int> onPageChange,
  }) {
    final outerTheme = Theme.of(context);
    OverlayNestedNavigation.show(
      context,
      builder: (context) => DebugPanel._(
        pages: pages,
        onDismiss: onDismiss,
        currentPage: currentPage,
        onPageChange: onPageChange,
        outerTheme: outerTheme,
      ),
    );
  }

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late final PageController _pageController = PageController(initialPage: widget.currentPage);

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageControllerChange);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageControllerChange);
    _pageController.dispose();
    // Notify of dismiss after the current frame completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDismiss());
    super.dispose();
  }

  void _onPageControllerChange() {
    if (!mounted) return;
    if (_pageController.hasClients) {
      widget.onPageChange(_pageController.page?.round() ?? 0);
    }
  }

  double get _currentPage => _pageController.hasClients
      ? (_pageController.page ?? widget.currentPage.toDouble())
      : widget.currentPage.toDouble();

  BorealisPage get _activePage => widget.pages[_currentPage.round().clamp(0, widget.pages.length - 1)];

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          centerTitle: true,
          // Rebuilds the title/clear action as the active page changes.
          title: ListenableBuilder(
            listenable: _pageController,
            builder: (context, _) => Text(
              _activePage.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
          actions: [
            ListenableBuilder(
              listenable: _pageController,
              builder: (context, _) {
                final onClearTap = _activePage.onClearTap;
                if (onClearTap == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(icon: Icon(Icons.delete_sweep_rounded), onPressed: onClearTap),
                );
              },
            ),
          ],
        ),
        // Builder, not `children`: the list form constructed every tab the
        // moment the panel opened — both list pages and the device-info
        // futures included — whichever one the user actually wanted.
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.pages.length,
          itemBuilder: (context, index) {
            final page = widget.pages[index];
            return Theme(
              data: page.useAppTheme ? widget.outerTheme : Theme.of(context),
              // Builder so the page reads the theme installed just above it.
              child: Builder(builder: page.build),
            );
          },
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            // Rebuilds to move the selection highlight as the page scrolls.
            child: ListenableBuilder(
              listenable: _pageController,
              builder: (context, _) {
                final currentPage = _currentPage;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < widget.pages.length; i++)
                      _BottomNavItem(
                        icon: widget.pages[i].icon,
                        page: i,
                        currentPage: currentPage,
                        onPageChange: (page) {
                          _pageController.animateToPage(
                            page,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        badge: widget.pages[i].badgeListenable,
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

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.page,
    required this.currentPage,
    required this.onPageChange,
    this.badge,
  });

  final IconData icon;
  final int page;
  final double currentPage;
  final ValueChanged<int> onPageChange;

  final ValueListenable<int>? badge;

  @override
  Widget build(BuildContext context) {
    final child = IconButton(
      visualDensity: VisualDensity.comfortable,
      icon: Icon(icon),
      onPressed: () => onPageChange(page),
      isSelected: (currentPage - page).abs() < 0.5,
    );

    final badge = this.badge;
    if (badge == null) {
      return child;
    }

    return ValueListenableBuilder<int>(
      valueListenable: badge,
      builder: (context, count, _) {
        return Badge(
          label: Text(count.toString()),
          isLabelVisible: count > 0,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          textColor: Theme.of(context).colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
          textStyle: Theme.of(context).textTheme.labelSmall,
          child: child,
        );
      },
    );
  }
}
