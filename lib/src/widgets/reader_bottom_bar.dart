import 'package:flutter/material.dart';

import '../models/reader_settings.dart';

/// Default bottom overlay: page slider + current page display.
///
/// Dragging updates only the local display; navigation fires once on
/// drag end via [onPageSelected].
class ReaderBottomBar extends StatefulWidget {
  final ReaderSettings settings;
  final int pageIndex;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  const ReaderBottomBar({
    super.key,
    required this.settings,
    required this.pageIndex,
    required this.totalPages,
    required this.onPageSelected,
  });

  @override
  State<ReaderBottomBar> createState() => _ReaderBottomBarState();
}

class _ReaderBottomBarState extends State<ReaderBottomBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final maxPage =
        widget.totalPages > 1 ? (widget.totalPages - 1).toDouble() : 0.0;
    final value =
        (_dragValue ?? widget.pageIndex.toDouble()).clamp(0.0, maxPage);
    final displayPage = widget.totalPages == 0 ? 0 : value.round() + 1;

    return Material(
      color: settings.surfaceColor.withValues(alpha: 0.96),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: settings.dividerColor)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.totalPages > 1)
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: settings.accentColor,
                  inactiveTrackColor: settings.dividerColor,
                  thumbColor: settings.accentColor,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: value,
                  max: maxPage,
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    widget.onPageSelected(v.round());
                    setState(() => _dragValue = null);
                  },
                  semanticFormatterCallback: (double v) =>
                      '${v.round() + 1} / ${widget.totalPages}',
                ),
              ),
            Text(
              '$displayPage / ${widget.totalPages}',
              style: TextStyle(color: settings.mutedColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
