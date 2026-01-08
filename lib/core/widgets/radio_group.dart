import 'package:flutter/widgets.dart';

/// A widget that manages a group of Radio widgets with a shared value.
class CustomRadioGroup<T> extends StatefulWidget {
  /// The currently selected value in the group.
  final T? groupValue;

  /// Called when the selected value changes.
  final ValueChanged<T?> onChanged;

  /// The widget below this widget in the tree.
  final Widget child;

  const CustomRadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.child,
  });

  @override
  State<CustomRadioGroup<T>> createState() => _CustomRadioGroupState<T>();

  /// Returns the inherited CustomRadioGroupState from the closest CustomRadioGroup ancestor.
  static _CustomRadioGroupState<T> of<T>(BuildContext context) {
    final _CustomRadioGroupScope<T>? scope = context
        .dependOnInheritedWidgetOfExactType<_CustomRadioGroupScope<T>>();
    assert(scope != null, 'No CustomRadioGroup found in context');
    return scope!.state;
  }
}

class _CustomRadioGroupState<T> extends State<CustomRadioGroup<T>> {
  T? get groupValue => widget.groupValue;

  void onChanged(T? value) => widget.onChanged(value);

  @override
  Widget build(BuildContext context) {
    return _CustomRadioGroupScope<T>(state: this, child: widget.child);
  }
}

class _CustomRadioGroupScope<T> extends InheritedWidget {
  final _CustomRadioGroupState<T> state;

  const _CustomRadioGroupScope({required this.state, required super.child});

  @override
  bool updateShouldNotify(_CustomRadioGroupScope<T> oldWidget) =>
      state.groupValue != oldWidget.state.groupValue;
}
