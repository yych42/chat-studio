import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _isMaximized = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = isMaximized);
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: _isHovering ? Colors.black.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WindowButton(
              color: const Color(0xFFFF5F57),
              hoverColor: const Color(0xFFFF5F57),
              icon: Icons.close,
              onPressed: () => windowManager.close(),
              isHovering: _isHovering,
            ),
            const SizedBox(width: 8),
            _WindowButton(
              color: const Color(0xFFFFBD2E),
              hoverColor: const Color(0xFFFFBD2E),
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
              isHovering: _isHovering,
            ),
            const SizedBox(width: 8),
            _WindowButton(
              color: const Color(0xFF28C840),
              hoverColor: const Color(0xFF28C840),
              icon: _isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              isHovering: _isHovering,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final Color color;
  final Color hoverColor;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isHovering;

  const _WindowButton({
    required this.color,
    required this.hoverColor,
    required this.icon,
    required this.onPressed,
    required this.isHovering,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isButtonHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isButtonHovering = true),
      onExit: (_) => setState(() => _isButtonHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: widget.isHovering || _isButtonHovering
              ? Center(
                  child: Icon(
                    widget.icon,
                    size: 8,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
