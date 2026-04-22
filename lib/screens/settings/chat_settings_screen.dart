import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_settings_controller.dart';
import '../../core/theme/app_theme.dart';

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key});

  static const List<Map<String, dynamic>> _wallpapers = [
    {'id': 'default', 'label': 'Default', 'color': 0xFFF0F2F5},
    {'id': 'blue',    'label': 'Blue',    'color': 0xFFDCEEFF},
    {'id': 'green',   'label': 'Green',   'color': 0xFFDCF8C6},
    {'id': 'purple',  'label': 'Purple',  'color': 0xFFF3E5F5},
    {'id': 'pink',    'label': 'Pink',    'color': 0xFFFCE4EC},
    {'id': 'dark',    'label': 'Dark',    'color': 0xFF1A1A2E},
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<ChatSettingsController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Settings',
          style: TextStyle(
              color: AppTheme.lightTextPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Font size ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Font size',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ctrl.fontSize.round()} sp',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.lightTextSecondary),
                ),
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: ctrl.fontSize,
                        min: 12,
                        max: 22,
                        divisions: 10,
                        activeColor: AppTheme.lightPrimaryColor,
                        label: '${ctrl.fontSize.round()}',
                        onChanged: (v) => ctrl.setFontSize(v),
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 22)),
                  ],
                ),
                // Live preview bubble
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF8C6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'This is how your messages will look',
                      style: TextStyle(fontSize: ctrl.fontSize),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Wallpaper ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat wallpaper',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextSecondary),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _wallpapers.length,
                  itemBuilder: (_, i) {
                    final w = _wallpapers[i];
                    final id = w['id'] as String;
                    final selected = ctrl.wallpaperId == id;
                    final bgColor = Color(w['color'] as int);
                    final isDark = bgColor.computeLuminance() < 0.3;

                    return GestureDetector(
                      onTap: () => ctrl.setWallpaper(id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppTheme.lightPrimaryColor
                                : Colors.grey.shade300,
                            width: selected ? 3 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              w['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (selected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.lightPrimaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Wallpaper preview
                const Text(
                  'Preview',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: ctrl.wallpaperColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Incoming bubble
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Hello!',
                                style: TextStyle(fontSize: ctrl.fontSize)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Outgoing bubble
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.lightPrimaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Hi there!',
                                style: TextStyle(
                                    fontSize: ctrl.fontSize,
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
