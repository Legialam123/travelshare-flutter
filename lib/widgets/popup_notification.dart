import 'package:flutter/material.dart';
import '../models/notification.dart';

class PopupNotification {
  static OverlayEntry? _currentOverlay;
  
  /// Hiển thị popup notification
  static void show(
    BuildContext context,
    NotificationModel notification, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    // Đóng popup hiện tại nếu có
    hide();
    
    _currentOverlay = OverlayEntry(
      builder: (context) => _PopupNotificationWidget(
        notification: notification,
        onTap: onTap,
        onDismiss: hide,
      ),
    );
    
    Overlay.of(context).insert(_currentOverlay!);
    
    // Tự động ẩn sau duration
    Future.delayed(duration, () {
      hide();
    });
  }
  
  /// Ẩn popup notification
  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _PopupNotificationWidget extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  
  const _PopupNotificationWidget({
    required this.notification,
    this.onTap,
    this.onDismiss,
  });
  
  @override
  State<_PopupNotificationWidget> createState() => _PopupNotificationWidgetState();
}

class _PopupNotificationWidgetState extends State<_PopupNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  IconData _getIconForType(String type) {
    switch (type) {
      case 'EXPENSE_CREATED':
        return Icons.attach_money_rounded;
      case 'EXPENSE_UPDATED':
        return Icons.edit_rounded;
      case 'EXPENSE_DELETED':
        return Icons.delete_rounded;
      case 'GROUP_UPDATED':
        return Icons.group_rounded;
      case 'MEMBER_JOINED':
        return Icons.person_add_alt_1_rounded;
      case 'MEDIA_UPLOADED':
        return Icons.photo_library_rounded;
      case 'CATEGORY_CREATED':
        return Icons.category_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
  
  Color _getColorForType(String type) {
    switch (type) {
      case 'EXPENSE_CREATED':
        return Colors.green;
      case 'EXPENSE_UPDATED':
        return Colors.orange;
      case 'EXPENSE_DELETED':
        return Colors.red;
      case 'GROUP_UPDATED':
        return Colors.purple;
      case 'MEMBER_JOINED':
        return Colors.blue;
      case 'MEDIA_UPLOADED':
        return Colors.teal;
      case 'CATEGORY_CREATED':
        return Colors.indigo;
      default:
        return Colors.deepPurple;
    }
  }
  
  void _handleDismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final iconData = _getIconForType(widget.notification.type);
    final iconColor = _getColorForType(widget.notification.type);
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: iconColor.withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _handleDismiss();
                    widget.onTap?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Icon với gradient background
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                iconColor.withOpacity(0.8),
                                iconColor.withOpacity(0.6)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            iconData,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active,
                                    size: 16,
                                    color: iconColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Thông báo mới',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: iconColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.notification.content,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.notification.group.name.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.notification.group.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: iconColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Close button
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _handleDismiss,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 