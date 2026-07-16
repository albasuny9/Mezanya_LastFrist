import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Amount Calculator Sheet
//
// Opens as a modal bottom sheet. Returns the computed double on confirm,
// or null on cancel (swipe down / dismiss).
// No scientific functions — basic arithmetic only.
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
  // ── Calculator state ─────────────────────────────────────────────────────
  String _currentToken = ''; // digits being typed right now
  double _accumulated = 0;
  String? _pendingOp; // +  −  ×  ÷
  bool _freshAfterEquals = false; // next digit starts a new token after =

  // ── Display helpers ───────────────────────────────────────────────────────
  String _fmt(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e12) {
      return v.toInt().toString();
    }
    // Strip floating-point dust, remove trailing zeros
    final s = double.parse(v.toStringAsFixed(10)).toString();
    return s.endsWith('.0') ? s.replaceAll('.0', '') : s;
  }

  String get _displayValue {
    if (_currentToken.isNotEmpty) return _currentToken;
    return _fmt(_accumulated);
  }

  String get _expressionHint {
    if (_pendingOp == null) return '';
    final lhs = _fmt(_accumulated);
    final rhs = _currentToken.isNotEmpty ? ' $_currentToken' : '';
    return '$lhs $_pendingOp$rhs';
  }

  // ── Button handlers ───────────────────────────────────────────────────────
  void _onDigit(String d) {
    setState(() {
      if (_freshAfterEquals) {
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
      final current = double.tryParse(_currentToken);
      if (current != null) {
        if (_pendingOp != null) {
          _accumulated = _compute(_accumulated, _pendingOp!, current);
        } else {
          _accumulated = current;
        }
        _currentToken = '';
      }
      _pendingOp = op;
      _freshAfterEquals = false;
    });
  }

  void _onEquals() {
    setState(() {
      final current = double.tryParse(_currentToken);
      if (_pendingOp != null && current != null) {
        _accumulated = _compute(_accumulated, _pendingOp!, current);
        _currentToken = '';
        _pendingOp = null;
        _freshAfterEquals = true;
      }
    });
  }

  void _onClear() {
    setState(() {
      _currentToken = '';
      _accumulated = 0;
      _pendingOp = null;
      _freshAfterEquals = false;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_currentToken.isNotEmpty) {
        _currentToken = _currentToken.substring(0, _currentToken.length - 1);
      } else if (_pendingOp != null) {
        // Cancel pending operator, restore accumulated as editable token
        _currentToken = _fmt(_accumulated);
        _accumulated = 0;
        _pendingOp = null;
      }
    });
  }

  double _compute(double a, String op, double b) {
    return switch (op) {
      '+' => a + b,
      '−' => a - b,
      '×' => a * b,
      '÷' => b != 0 ? a / b : a,
      _ => b,
    };
  }

  double get _result {
    final current = double.tryParse(_currentToken);
    if (current != null && _pendingOp != null) {
      return _compute(_accumulated, _pendingOp!, current);
    }
    if (current != null) return current;
    return _accumulated;
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
    Navigator.of(context).pop(_result);
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
