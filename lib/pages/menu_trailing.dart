import 'package:desktop/desktop.dart';

import 'settings.dart';

typedef ViewTypeCallback = void Function(ViewType);

class TrailingMenuPage extends StatefulWidget {
  TrailingMenuPage({
    required this.onThemeChanged,
    required this.onViewTypeChanged,
    Key? key,
  }) : super(key: key);

  final VoidCallback onThemeChanged;
  final ViewTypeCallback onViewTypeChanged;

  @override
  _TrailingMenuPageState createState() => _TrailingMenuPageState();
}

enum ViewType {
  comfy,
  compact,
}

class _TrailingMenuPageState extends State<TrailingMenuPage> {
  ViewType get viewType => SettingsScope.of(context).viewType;

  bool settings = false;

  @override
  Widget build(BuildContext context) {
    HSLColor? overrideSettingsColor =
        settings ? Theme.of(context).colorScheme.primary : null;

    return Row(
      children: [
        ToggleButton<ViewType>(
          onSelected: (value) {
            setState(() => widget.onViewTypeChanged(value));
          },
          value: viewType,
          items: [
            ToggleItem(
              builder: (context) => Icon(Icons.view_comfy),
              value: ViewType.comfy,
            ),
            ToggleItem(
              builder: (context) => Icon(Icons.view_compact),
              value: ViewType.compact,
            ),
          ],
        ),
        Builder(
          builder: (context) => ButtonTheme.merge(
            data: ButtonThemeData(
              hoverColor: overrideSettingsColor,
              highlightColor: overrideSettingsColor,
            ),
            child: Button(
              body: Icon(Icons.settings),
              color: settings ? Theme.of(context).colorScheme.primary : null,
              onPressed: () async {
                if (!settings) {
                  final route = createDialogRoute(
                    barrierDismissible: false,
                    context: context,
                    builder: (context) => Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        color:
                            Theme.of(context).colorScheme.background.toColor(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Theme'),
                                ),
                                ThemeToggle(onPressed: widget.onThemeChanged),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                  NavigationScope.of(context)!.navigatorState!.push(route);
                } else {
                  NavigationScope.of(context)!.navigatorState!.pop();
                }

                setState(() => settings = !settings);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ThemeToggle extends StatefulWidget {
  ThemeToggle({
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final VoidCallback onPressed;

  @override
  _ThemeToggleState createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle> {
  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final iconForeground = themeData.textTheme.textHigh;
    switch (themeData.brightness) {
      case Brightness.dark:
        return Button(
          onPressed: widget.onPressed,
          body: Icon(
            IconData(0x61, fontFamily: 'mode'),
            color: iconForeground.toColor(),
          ),
        );
      case Brightness.light:
        return Button(
          onPressed: widget.onPressed,
          body: Icon(
            IconData(0x62, fontFamily: 'mode'),
            color: iconForeground.toColor(),
          ),
        );
    }
  }
}
