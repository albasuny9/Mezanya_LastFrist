import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/transaction_display_format.dart';

// ---------------------------------------------------------------------------
// Amount Calculator Sheet
//
// Opens as a modal bottom sheet. Returns the computed double on confirm,
// or null on cancel (swipe down / dismiss).
//
// Operator precedence: × and ÷ are evaluated before + and − (standard
// arithmetic precedence). A two-pass evaluator handles this without
// requiring a full expression parser.
// ---------------------------------------------------------------------------

Future<double?> showAmountCalculatorSheet(BuildContext context) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CalculatorSheet(),
  );
}

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet();

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  // ── Expression state ──────────────────────────────────────────────────────
  // The expression is stored as parallel lists so precedence can be applied
  // correctly on evaluation: first pass resolves × / ÷, second pass + / −.
  //
  // Example:  100 + 20 × 3
  //   _values    = [100, 20]   after typing 3
  //   _operators = ['+', '×']
  //   _currentToken = '3'
  //   → evaluate: 20×3=60, then 100+60=160  ✓
  List<double> _values = [];
  List<String> _operators = [];
  String _currentToken = ''; // digits the user is currently typing
  bool _freshAfterEquals = false; // next digit starts a new expression

  // ── Evaluator ─────────────────────────────────────────────────────────────
  /// Two-pass evaluation respecting standard operator precedence.
  /// Pass 1 resolves × and ÷ (left-to-right).
  /// Pass 2 resolves + and − (left-to-right).
  static double _evaluateExpression(
    List<double> values,
    List<String> operators,
  ) {
    if (values.isEmpty) return 0;
    if (operators.isEmpty) return values.first;

    final vals = List<double>.from(values);
    final ops = List<String>.from(operators);

    // Pass 1: × and ÷
    int i = 0;
    while (i < ops.length) {
      if (ops[i] == '×' || ops[i] == '÷') {
        final a = vals[i];
        final b = vals[i + 1];
        final result = ops[i] == '×' ? a * b : (b != 0 ? a / b : a);
        vals[i] = result;
        vals.removeAt(i + 1);
        ops.removeAt(i);
        // stay at same index to check the next operator
      } else {
        i++;
      }
    }

    // Pass 2: + and −
    double result = vals[0];
    for (int j = 0; j < ops.length; j++) {
      if (ops[j] == '+') {
        result += vals[j + 1];
      } else if (ops[j] == '−') {
        result -= vals[j + 1];
      }
    }
    return result;
  }

  // ── Display helpers ───────────────────────────────────────────────────────
  /// Compact string for showing intermediate values in the expression hint.
  String _fmt(double v) {
    final rounded = double.parse(v.toStringAsFixed(10));
    if (rounded == rounded.truncateToDouble() && rounded.abs() < 1e12) {
      return rounded.toInt().toString();
    }
    return rounded.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  String get _displayValue {
    if (_currentToken.isNotEmpty) return _currentToken;
    if (_values.isNotEmpty) return _fmt(_values.last);
    return '0';
  }

  /// Shows the accumulated expression above the current input, e.g. "100 + 20 ×"
  String get _expressionHint {
    if (_values.isEmpty) return '';
    final sb = StringBuffer();
    for (int i = 0; i < _values.length; i++) {
      sb.write(_fmt(_values[i]));
      if (i < _operators.length) {
        sb.write(' ${_operators[i]} ');
      }
    }
    return sb.toString().trimRight();
  }

  // ── Button handlers ───────────────────────────────────────────────────────
  void _onDigit(String d) {
    setState(() {
      if (_freshAfterEquals) {
        // Start a fresh expression after =
        _values = [];
        _operators = [];
        _currentToken = '';
        _freshAfterEquals = false;
      }
      if (d == '.' && _currentToken.contains('.')) return;
      if (d == '.' && _currentToken.isEmpty) {
        _currentToken = '0.';
        return;
      }
      _currentToken += d;
    });
  }

  void _onOperator(String op) {
    setState(() {
      _freshAfterEquals = false;
      final current = double.tryParse(_currentToken);
      if (current != null) {
        _values.add(current);
        _currentToken = '';
      } else if (_values.isEmpty) {
        // Nothing typed yet — treat as 0
        _values.add(0);
      }
      // Replace the last operator if the user presses two operators in a row
      if (_operators.length == _values.length) {
        _operators[_operators.length - 1] = op;
      } else {
        _operators.add(op);
      }
    });
  }

  void _onEquals() {
    setState(() {
      final current = double.tryParse(_currentToken);
      if (_operators.isEmpty) {
        // Nothing to evaluate — leave as-is
        _freshAfterEquals = true;
        return;
      }
      if (current != null) {
        _values.add(current);
        _currentToken = '';
      }
      if (_values.length > _operators.length) {
        final result = _evaluateExpression(_values, _operators);
        _values = [];
        _operators = [];
        _currentToken = _fmt(result);
        _freshAfterEquals = true;
      }
    });
  }

  void _onClear() {
    setState(() {
      _values = [];
      _operators = [];
      _currentToken = '';
      _freshAfterEquals = false;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_currentToken.isNotEmpty) {
        _currentToken = _currentToken.substring(0, _currentToken.length - 1);
      } else if (_operators.isNotEmpty) {
        // Remove the last operator; restore its left-hand value as editable
        _operators.removeLast();
        if (_values.isNotEmpty) {
          _currentToken = _fmt(_values.removeLast());
        }
      }
    });
  }

  // ── Result for confirm ────────────────────────────────────────────────────
  double get _result {
    final current = double.tryParse(_currentToken);
    if (_operators.isEmpty) return current ?? (_values.isEmpty ? 0 : _values.first);
    if (current != null) {
      return _evaluateExpression([..._values, current], _operators);
    }
    // Operator pressed but no RHS typed yet — evaluate what we have
    if (_values.length > _operators.length) {
      return _evaluateExpression(_values, _operators);
    }
    return _values.isEmpty ? 0 : _values.last;
  }

  void _handleButton(String label) {
    HapticFeedback.lightImpact();
    switch (label) {
      case 'C':
        _onClear();
      case '⌫':
        _onBackspace();
      case '=':
        _onEquals();
      case '+':
      case '−':
      case '×':
      case '÷':
        _onOperator(label);
      default:
        _onDigit(label);
    }
  }

  void _confirm() {
    // Use the canonical amount formatter — identical output to manual entry
    final formatted = formatAmountInput(_result);
    Navigator.of(context).pop(double.tryParse(formatted) ?? _result);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final sheetHeight = mq.size.height * 0.58 + mq.viewInsets.bottom;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Display
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Expression hint (small, dimmed)
                SizedBox(
                  height: 18,
                  child: Text(
                    _expressionHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                // Current value (large)
                Text(
                  _displayValue.isEmpty ? '0' : _displayValue,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 16,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),

          // Button grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  _row(['C', '⌫', '.', '÷'], theme),
                  const SizedBox(height: 6),
                  _row(['7', '8', '9', '×'], theme),
                  const SizedBox(height: 6),
                  _row(['4', '5', '6', '−'], theme),
                  const SizedBox(height: 6),
                  _row(['1', '2', '3', '+'], theme),
                  const SizedBox(height: 6),
                  // Last row: 0 (2× wide) | = | ✓ confirm
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: _btn('0', theme)),
                        const SizedBox(width: 6),
                        Expanded(child: _btn('=', theme)),
                        const SizedBox(width: 6),
                        Expanded(child: _confirmBtn(theme)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> keys, ThemeData theme) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _btn(keys[i], theme)),
          ],
        ],
      ),
    );
  }

  Widget _btn(String label, ThemeData theme) {
    final isOperator = ['+', '−', '×', '÷'].contains(label);
    final isEquals = label == '=';
    final isClear = label == 'C';
    final isBackspace = label == '⌫';

    final Color bg;
    final Color fg;

    if (isEquals) {
      bg = const Color(0xFF2F6F5E);
      fg = Colors.white;
    } else if (isOperator) {
      bg = const Color(0xFF2F6F5E).withValues(alpha: 0.10);
      fg = const Color(0xFF2F6F5E);
    } else if (isClear) {
      bg = const Color(0xFFC65D2E).withValues(alpha: 0.10);
      fg = const Color(0xFFC65D2E);
    } else {
      bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
      fg = theme.colorScheme.onSurface;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleButton(label),
        child: Center(
          child: isBackspace
              ? Icon(Icons.backspace_outlined, size: 18, color: fg)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _confirmBtn(ThemeData theme) {
    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _confirm,
        child: Center(
          child: Icon(
            Icons.check_rounded,
            color: theme.colorScheme.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
