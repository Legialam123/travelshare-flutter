import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/expense_finalization.dart';
import '../services/expense_finalization_service.dart';


class ExpenseFinalizationButton extends StatefulWidget {
  final Group group;
  final String currentUserId;
  final List<ExpenseFinalization> existingFinalizations;
  final VoidCallback? onFinalizationInitiated;

  const ExpenseFinalizationButton({
    Key? key,
    required this.group,
    required this.currentUserId,
    required this.existingFinalizations,
    this.onFinalizationInitiated,
  }) : super(key: key);

  @override
  State<ExpenseFinalizationButton> createState() => _ExpenseFinalizationButtonState();
}

class _ExpenseFinalizationButtonState extends State<ExpenseFinalizationButton> {
  bool _isLoading = false;

  bool get _canInitiate => ExpenseFinalizationService.canInitiateFinalization(
    currentUserId: widget.currentUserId,
    groupCreatorId: widget.group.createdBy.id ?? '',
    existingFinalizations: widget.existingFinalizations,
  );

  @override
  Widget build(BuildContext context) {
    if (!_canInitiate) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _showFinalizationDialog,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_outline),
        label: const Text('Tất toán chi phí'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _showFinalizationDialog() {
    final TextEditingController descriptionController = TextEditingController();
    int selectedDays = 7;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tất toán chi phí'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tính năng này sẽ khóa tất cả chi phí hiện tại và gửi yêu cầu xác nhận đến tất cả thành viên.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Lý do tất toán',
                  hintText: 'VD: Kết thúc chuyến đi, hoàn thành dự án...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Deadline: '),
                  DropdownButton<int>(
                    value: selectedDays,
                    items: [3, 5, 7, 14, 30].map((days) {
                      return DropdownMenuItem(
                        value: days,
                        child: Text('$days ngày'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDays = value ?? 7;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initiateFinalization(
                  descriptionController.text.trim(),
                  selectedDays,
                );
              },
              child: const Text('Khởi tạo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initiateFinalization(String description, int deadlineDays) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ExpenseFinalizationService.initiateFinalization(
        groupId: widget.group.id,
        description: description.isEmpty ? 'Tất toán chi phí nhóm' : description,
        deadlineDays: deadlineDays,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã khởi tạo tất toán thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onFinalizationInitiated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khởi tạo tất toán: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
