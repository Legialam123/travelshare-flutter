import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/amount_parser.dart';

/// Standardized amount input field với format-on-blur behavior
class AmountTextField extends StatefulWidget {
  final String currencyCode;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? labelText;
  final String? errorText;
  final bool enabled;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;

  const AmountTextField({
    Key? key,
    required this.currencyCode,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.labelText,
    this.errorText,
    this.enabled = true,
    this.controller,
    this.focusNode,
    this.decoration,
  }) : super(key: key);

  @override
  State<AmountTextField> createState() => _AmountTextFieldState();
}

class _AmountTextFieldState extends State<AmountTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownController = false;
  bool _ownFocusNode = false;

  @override
  void initState() {
    super.initState();
    
    // Setup controller
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue ?? '');
      _ownController = true;
    }
    
    // Setup focus node
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownFocusNode = true;
    }
    
    // Setup focus listeners
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    
    if (_ownController) {
      _controller.dispose();
    }
    if (_ownFocusNode) {
      _focusNode.dispose();
    }
    
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      // On focus: Prepare for editing
      final currentText = _controller.text;
      final currentSelection = _controller.selection;
      final editableText = CurrencyInputFormatter.prepareForEdit(
        currentText, 
        widget.currencyCode
      );
      
      if (editableText != currentText) {
        // 🔧 Tính toán cursor position mapping từ formatted sang raw text
        int newCursorPosition = _mapCursorPosition(
          currentText, 
          editableText, 
          currentSelection.baseOffset,
          widget.currencyCode
        );
        
        _controller.value = TextEditingValue(
          text: editableText,
          selection: TextSelection.collapsed(offset: newCursorPosition),
        );
      }
    } else {
      // On blur: Format the text
      final rawText = _controller.text;
      final formattedText = CurrencyInputFormatter.formatOnBlur(
        rawText, 
        widget.currencyCode
      );
      
      if (formattedText != rawText) {
        _controller.value = TextEditingValue(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }
      
      // Notify parent about change
      if (widget.onChanged != null) {
        widget.onChanged!(formattedText);
      }
    }
  }

  /// Map cursor position từ formatted text sang raw text
  int _mapCursorPosition(String formattedText, String rawText, int cursorPos, String currencyCode) {
    if (cursorPos >= formattedText.length) {
      return rawText.length;
    }
    
    // Đếm số ký tự digit trước cursor position
    int digitCount = 0;
    for (int i = 0; i < cursorPos && i < formattedText.length; i++) {
      if (RegExp(r'\d').hasMatch(formattedText[i])) {
        digitCount++;
      }
    }
    
    // Tìm vị trí tương ứng trong raw text
    return digitCount.clamp(0, rawText.length);
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số tiền';
    }
    
    // Validate after formatting
    final isValid = AmountParser.isValidAmount(value, widget.currencyCode);
    if (!isValid) {
      return 'Số tiền không hợp lệ';
    }
    
    final parsedAmount = AmountParser.getPureDouble(value, widget.currencyCode);
    if (parsedAmount == null || parsedAmount <= 0) {
      return 'Số tiền phải lớn hơn 0';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hintText = CurrencyInputFormatter.getHintText(widget.currencyCode);
    
    // Merge default decoration với custom decoration
    final defaultDecoration = InputDecoration(
      labelText: widget.labelText ?? 'Số tiền',
      hintText: hintText,
      errorText: widget.errorText,
    );
    
    final finalDecoration = widget.decoration != null 
        ? defaultDecoration.copyWith(
            labelText: widget.decoration!.labelText ?? defaultDecoration.labelText,
            hintText: widget.decoration!.hintText ?? defaultDecoration.hintText,
            errorText: widget.decoration!.errorText ?? defaultDecoration.errorText,
            border: widget.decoration!.border,
            prefixIcon: widget.decoration!.prefixIcon,
          )
        : defaultDecoration;

    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        CurrencyInputFormatter(currencyCode: widget.currencyCode),
      ],
      validator: widget.validator ?? _defaultValidator,
      decoration: finalDecoration,
      onChanged: (value) {
        // Only notify on change when not focused (to avoid conflicts with formatting)
        if (!_focusNode.hasFocus && widget.onChanged != null) {
          widget.onChanged!(value);
        }
      },
    );
  }

  /// Get current amount as pure number for API submission
  double? get pureAmount {
    return AmountParser.getPureDouble(_controller.text, widget.currencyCode);
  }

  /// Get current parsed amount với currency context
  ParsedAmount? get parsedAmount {
    return AmountParser.parseAmount(_controller.text, widget.currencyCode);
  }

  /// Set formatted value (useful for initial values)
  void setFormattedValue(String formattedValue) {
    _controller.text = formattedValue;
  }

  /// Set raw value và format it
  void setRawValue(double value) {
    final formatted = CurrencyInputFormatter.formatCurrency(value, widget.currencyCode);
    _controller.text = formatted;
  }
} 