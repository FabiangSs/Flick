import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/models/nav_bar_config.dart';

class FlickNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showMiniPlayer;
  final Widget? miniPlayerWidget;
  final NavBarConfig config;

  const FlickNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.config,
    this.showMiniPlayer = false,
    this.miniPlayerWidget,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = config.orderedButtons;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final horizontalPadding = context.scaleSize(AppConstants.spacingLg);
    final verticalPadding = context.scaleSize(AppConstants.spacingSm);

    return Container(
      margin: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        bottomPadding + verticalPadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.92),
            AppColors.surface.withValues(alpha: 0.97),
          ],
        ),
        borderRadius: BorderRadius.circular(context.scaleSize(20)),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.03),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMiniPlayer && miniPlayerWidget != null) miniPlayerWidget!,
          _buildNavigationRow(context, buttons),
        ],
      ),
    );
  }

  Widget _buildNavigationRow(BuildContext context, List<NavBarButton> buttons) {
    final spacingFactor = config.buttonSpacingFactor;
    final baseItemPadding = context.scaleSize(AppConstants.spacingMd);
    final itemPadding = baseItemPadding * spacingFactor;

    const minTapTargetSize = 48.0;

    final missingEssentials = config.missingEssentials;
    final isOnMissingEssential = missingEssentials.any((b) => b.pageIndex == currentIndex);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: itemPadding,
        vertical: context.scaleSize(AppConstants.spacingXs) * config.barSizeFactor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...List.generate(
            buttons.length,
            (index) {
              final button = buttons[index];
              return Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: minTapTargetSize),
                  child: _FlickNavItem(
                    button: button,
                    isSelected: currentIndex == button.pageIndex,
                    config: config,
                    onTap: () => onTap(button.pageIndex),
                  ),
                ),
              );
            },
          ),
          if (missingEssentials.isNotEmpty)
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minTapTargetSize),
                child: _OverflowNavItem(
                  isSelected: isOnMissingEssential,
                  config: config,
                  missingButtons: missingEssentials,
                  onSelect: (button) => onTap(button.pageIndex),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverflowNavItem extends StatelessWidget {
  final bool isSelected;
  final NavBarConfig config;
  final List<NavBarButton> missingButtons;
  final ValueChanged<NavBarButton> onSelect;

  const _OverflowNavItem({
    required this.isSelected,
    required this.config,
    required this.missingButtons,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final iconFactor = config.iconSizeFactor;
    final barSizeFactor = config.barSizeFactor;

    final iconSize = context.responsiveIcon(AppConstants.iconSizeSm) * iconFactor;
    final fontSize = context.responsiveText(8.0) * barSizeFactor;
    final horizontalPadding = context.scaleSize(AppConstants.spacingMd) * config.buttonSpacingFactor;
    final verticalPadding = context.scaleSize(AppConstants.spacingXs) * barSizeFactor;
    final spacing = context.scaleSize(2.0) * config.buttonSpacingFactor;

    final color = isSelected ? AppColors.activeState : AppColors.inactiveState;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.tap();
        _showOverflowMenu(context);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.ellipsis,
              color: color,
              size: iconSize,
            ),
            SizedBox(height: spacing),
            if (config.showLabels)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'More',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: fontSize,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: color,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOverflowMenu(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final menuWidth = 180.0;
    final itemHeight = 48.0;
    final totalHeight = itemHeight * missingButtons.length + 8.0;

    final left = (offset.dx + size.width / 2 - menuWidth / 2).clamp(8.0, MediaQuery.of(context).size.width - menuWidth - 8.0);
    final top = offset.dy - totalHeight - 8.0;

    entry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => entry.remove(),
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceLight.withValues(alpha: 0.95),
                        AppColors.surface.withValues(alpha: 0.98),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: missingButtons.map((button) {
                      return InkWell(
                        onTap: () {
                          entry.remove();
                          onSelect(button);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Icon(button.icon, size: 20, color: AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  button.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'ProductSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(entry);
  }
}

class _FlickNavItem extends StatefulWidget {
  final NavBarButton button;
  final bool isSelected;
  final NavBarConfig config;
  final VoidCallback onTap;

  const _FlickNavItem({
    required this.button,
    required this.isSelected,
    required this.config,
    required this.onTap,
  });

  @override
  State<_FlickNavItem> createState() => _FlickNavItemState();
}

class _FlickNavItemState extends State<_FlickNavItem>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _selectionController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _selectionAnimation;
  late final Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: AppConstants.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );

    _selectionController = AnimationController(
      duration: AppConstants.animationNormal,
      vsync: this,
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _selectionAnimation = CurvedAnimation(
      parent: _selectionController,
      curve: Curves.easeOutQuart,
    );

    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _selectionController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(_FlickNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _selectionController.forward();
      } else {
        _selectionController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
    FocusScope.of(context).unfocus();
    AppHaptics.tap();
    widget.onTap();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final iconFactor = widget.config.iconSizeFactor;
    final spacerFactor = widget.config.buttonSpacingFactor;
    final horizontalPaddingFactor = widget.config.buttonSpacingFactor;
    final barSizeFactor = widget.config.barSizeFactor;

    final iconSize = context.responsiveIcon(AppConstants.iconSizeSm) * iconFactor;
    final fontSize = context.responsiveText(8.0) * barSizeFactor;
    final horizontalPadding = context.scaleSize(AppConstants.spacingMd) * horizontalPaddingFactor;
    final verticalPadding = context.scaleSize(AppConstants.spacingXs) * barSizeFactor;
    final spacing = context.scaleSize(2.0) * spacerFactor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _selectionAnimation]),
        builder: (context, child) {
          final lerpColor = Color.lerp(
            AppColors.inactiveState,
            AppColors.activeState,
            _selectionAnimation.value,
          );

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: _iconScaleAnimation.value,
                    child: Icon(
                      widget.button.icon,
                      color: lerpColor,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(height: spacing),
                  if (widget.config.showLabels)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.button.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: fontSize,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: lerpColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
