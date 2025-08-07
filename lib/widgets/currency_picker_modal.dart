import 'dart:async';
import 'package:flutter/material.dart';
import '../models/currency.dart';
import '../utils/currency_utils.dart';

class CurrencyPickerModal extends StatefulWidget {
  final List<Currency> currencies;
  final Currency? selectedCurrency;
  final String? defaultCurrencyCode;
  final String title;
  final bool showPopularOnly;

  const CurrencyPickerModal({
    Key? key,
    required this.currencies,
    this.selectedCurrency,
    this.defaultCurrencyCode,
    this.title = 'Chọn tiền tệ',
    this.showPopularOnly = false,
  }) : super(key: key);

  @override
  State<CurrencyPickerModal> createState() => _CurrencyPickerModalState();

  /// Show short list modal with popular currencies
  static Future<Currency?> showShortList({
    required BuildContext context,
    required List<Currency> currencies,
    Currency? selectedCurrency,
    String? defaultCurrencyCode,
  }) async {
    // Sort currencies by priority first, then take 5
    final sortedCurrencies = CurrencyUtils.sortCurrenciesByPriority(
      currencies,
      (currency) => currency.code,
      defaultCurrencyCode,
    );
    
    final popularCurrencies = sortedCurrencies.take(5).toList();

    final result = await showModalBottomSheet<dynamic>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 16, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Popular currencies (no scroll needed)
                ...popularCurrencies.map((currency) => _buildCurrencyTile(
                  currency: currency,
                  isSelected: selectedCurrency?.code == currency.code,
                  isDefault: defaultCurrencyCode == currency.code,
                  onTap: () => Navigator.pop(ctx, currency),
                )),
                
                const Divider(height: 1),
                
                // Show all button
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.expand_more, color: Colors.blue),
                  ),
                  title: const Text(
                    'Hiển thị tất cả tiền tệ',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop('__SHOW_ALL__'); // Return special value
                  },
                ),
                
                // Bottom padding to prevent overflow
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Handle result
    if (result == '__SHOW_ALL__') {
      // Show full list
      return await showFullList(
        context: context,
        currencies: currencies,
        selectedCurrency: selectedCurrency,
        defaultCurrencyCode: defaultCurrencyCode,
      );
    } else if (result is Currency) {
      return result;
    }
    
    return null;
  }

  /// Show full list modal with search
  static Future<Currency?> showFullList({
    required BuildContext context,
    required List<Currency> currencies,
    Currency? selectedCurrency,
    String? defaultCurrencyCode,
  }) {
    return showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: CurrencyPickerModal(
          currencies: currencies,
          selectedCurrency: selectedCurrency,
          defaultCurrencyCode: defaultCurrencyCode,
        ),
      ),
    );
  }

  static Widget _buildCurrencyTile({
    required Currency currency,
    required bool isSelected,
    required bool isDefault,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDefault 
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: isDefault 
              ? Border.all(color: Colors.green.withOpacity(0.3))
              : null,
        ),
        child: Center(
          child: Text(
            CurrencyUtils.getFlag(currency.code),
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${currency.name} (${currency.symbol})',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
            ),
          ),
          if (isDefault) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Mặc định',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      subtitle: Text(
        currency.code,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      onTap: onTap,
    );
  }
}



class _CurrencyPickerModalState extends State<CurrencyPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<Currency> _filteredCurrencies = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeCurrencies();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _initializeCurrencies() {
    // Sort currencies by priority
    final sortedCurrencies = CurrencyUtils.sortCurrenciesByPriority(
      widget.currencies,
      (currency) => currency.code,
      widget.defaultCurrencyCode,
    );

    setState(() {
      _filteredCurrencies = sortedCurrencies;
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _initializeCurrencies();
      } else {
        _filteredCurrencies = CurrencyUtils.filterCurrencies(
          widget.currencies,
          query,
          (currency) => currency.code,
          (currency) => currency.name,
          (currency) => currency.symbol,
        );
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header with drag indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Title and close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),
          
          // Search bar - Fixed position
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tiền tệ...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear, color: Colors.grey),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          
          // Currency list - Scrollable
          Expanded(
            child: _filteredCurrencies.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredCurrencies.length,
                    itemBuilder: (context, index) {
                      final currency = _filteredCurrencies[index];
                      final isSelected = widget.selectedCurrency?.code == currency.code;
                      final isDefault = widget.defaultCurrencyCode == currency.code;
                      
                      return CurrencyPickerModal._buildCurrencyTile(
                        currency: currency,
                        isSelected: isSelected,
                        isDefault: isDefault,
                        onTap: () {
                          Navigator.of(context).pop(currency);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy tiền tệ',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử tìm kiếm với từ khóa khác',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
} 