import 'package:desktop/desktop.dart';
import 'menu_trailing.dart';

class SettingsScope extends InheritedWidget {
  SettingsScope({
    Key? key,
    required Widget child,
    required this.viewType,
  }) : super(key: key, child: child);

  final ViewType viewType;

  @override
  bool updateShouldNotify(SettingsScope old) => old.viewType != viewType;

  static SettingsScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!;
}