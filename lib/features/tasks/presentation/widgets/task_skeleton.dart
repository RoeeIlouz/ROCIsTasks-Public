import 'package:flutter/material.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';

class TaskTileSkeleton extends StatefulWidget {
  const TaskTileSkeleton({super.key});

  @override
  State<TaskTileSkeleton> createState() => _TaskTileSkeletonState();
}

class _TaskTileSkeletonState extends State<TaskTileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        final baseColor = isDark
            ? Colors.white.withValues(alpha: _opacityAnimation.value * 0.15)
            : Colors.black.withValues(alpha: _opacityAnimation.value * 0.1);

        return GlassContainer(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox skeleton
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: baseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                // Content lines skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title line
                      Container(
                        width: 160,
                        height: 16,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Tag placeholder
                          Container(
                            width: 60,
                            height: 12,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Date placeholder
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TaskListSkeleton extends StatelessWidget {
  final int itemCount;

  const TaskListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemCount: itemCount,
      itemBuilder: (context, index) => const TaskTileSkeleton(),
    );
  }
}
