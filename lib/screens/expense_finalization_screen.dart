import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/expense_finalization.dart';
import '../services/expense_finalization_service.dart';
import '../services/auth_service.dart';
import '../widgets/expense_finalization_button.dart';

class ExpenseFinalizationScreen extends StatefulWidget {
  final Group group;

  const ExpenseFinalizationScreen({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  State<ExpenseFinalizationScreen> createState() =>
      _ExpenseFinalizationScreenState();
}

class _ExpenseFinalizationScreenState extends State<ExpenseFinalizationScreen> {
  List<ExpenseFinalization> _finalizations = [];
  bool _isLoading = true;
  String? _error;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadFinalizations();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      setState(() {
        _currentUserId = user?.id ?? '';
      });
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadFinalizations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final finalizations =
          await ExpenseFinalizationService.getGroupFinalizations(
              widget.group.id);

      setState(() {
        _finalizations = finalizations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tất toán - ${widget.group.name}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Finalization button (chỉ hiện với trưởng nhóm)
          ExpenseFinalizationButton(
            group: widget.group,
            currentUserId: _currentUserId,
            existingFinalizations: _finalizations,
            onFinalizationInitiated: _loadFinalizations,
          ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Lỗi tải dữ liệu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFinalizations,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_finalizations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Chưa có tất toán nào',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Trưởng nhóm có thể khởi tạo tất toán để khóa chi phí',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFinalizations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _finalizations.length,
        itemBuilder: (context, index) {
          final finalization = _finalizations[index];
          return ExpenseFinalizationCard(
            finalization: finalization,
            onTap: () => _showFinalizationDetails(finalization),
          );
        },
      ),
    );
  }

  void _showFinalizationDetails(ExpenseFinalization finalization) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ExpenseFinalizationDetailsSheet(
        finalization: finalization,
        onUpdate: _loadFinalizations,
      ),
    );
  }
}

class ExpenseFinalizationCard extends StatelessWidget {
  final ExpenseFinalization finalization;
  final VoidCallback? onTap;

  const ExpenseFinalizationCard({
    Key? key,
    required this.finalization,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon =
        ExpenseFinalizationService.getStatusIcon(finalization.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: statusColor,
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    statusIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      finalization.statusDisplayText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Text(
                    'ID: ${finalization.id}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              if (finalization.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  finalization.description!,
                  style: const TextStyle(fontSize: 14),
                ),
              ],

              const SizedBox(height: 12),

              // Progress and deadline info
              if (finalization.isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            finalization.progressText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: ExpenseFinalizationService
                                .calculateResponseProgress(finalization),
                            backgroundColor: Colors.grey.shade300,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Còn lại:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          ExpenseFinalizationService.formatTimeUntilDeadline(
                              finalization),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: finalization.isDeadlinePassed
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              // Footer info
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Khởi tạo: ${finalization.initiatedByName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(finalization.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (finalization.status) {
      case FinalizationStatus.pending:
        return Colors.orange;
      case FinalizationStatus.approved:
        return Colors.green;
      case FinalizationStatus.rejected:
        return Colors.red;
      case FinalizationStatus.expired:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class ExpenseFinalizationDetailsSheet extends StatelessWidget {
  final ExpenseFinalization finalization;
  final VoidCallback? onUpdate;

  const ExpenseFinalizationDetailsSheet({
    Key? key,
    required this.finalization,
    this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chi tiết tất toán #${finalization.id}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  _buildInfoCard(
                    title: 'Trạng thái',
                    content: finalization.statusDisplayText,
                    icon: Icons.info_outline,
                  ),

                  if (finalization.description?.isNotEmpty == true)
                    _buildInfoCard(
                      title: 'Lý do',
                      content: finalization.description!,
                      icon: Icons.description,
                    ),

                  // Timeline
                  _buildInfoCard(
                    title: 'Thời gian',
                    content:
                        'Khởi tạo: ${_formatDateTime(finalization.createdAt)}\n'
                        'Deadline: ${_formatDateTime(finalization.deadline)}',
                    icon: Icons.schedule,
                  ),

                  // Responses
                  _buildResponsesSection(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsesSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Phản hồi thành viên',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  '${finalization.approvedResponsesCount}/${finalization.memberResponses.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...finalization.memberResponses
                .map((response) => _buildResponseItem(response)),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseItem(FinalizationRequestInfo response) {
    Color statusColor;
    IconData statusIcon;

    if (response.isAccepted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (response.isDeclined) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              response.participantName,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            response.statusDisplayText,
            style: TextStyle(
              fontSize: 14,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
