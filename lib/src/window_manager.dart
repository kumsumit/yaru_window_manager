import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nativeapi/nativeapi.dart'
    as native
    show Application, Brightness, DisplayManager;
import 'package:window_manager/window_manager.dart';
import 'package:yaru_window_platform_interface/yaru_window_platform_interface.dart';

class YaruWindowManager extends YaruWindowPlatform {
  YaruWindowManager([@visibleForTesting this.__window]);

  static void registerWith() {
    YaruWindowPlatform.instance = YaruWindowManager();
  }

  final _statesListeners = <int, _YaruWindowStatesListener>{};
  _YaruWindowStatesListener _listener(int id) =>
      _statesListeners[id] ??= _YaruWindowStatesListener(_w(id));

  final _closeListeners = <int, _YaruWindowOnCloseListener>{};
  _YaruWindowOnCloseListener _closeListener(int id) =>
      _closeListeners[id] ??= _YaruWindowOnCloseListener(_w(id));

  final Window? __window;

  /// Resolves the native window for the given [id]. Id 0 is the app's current
  /// window; any other id is looked up among the native windows.
  Window? _w(int id) {
    if (__window != null) return __window;
    return _guard<Window?>(
      () => id == 0
          ? WindowManager.instance.getCurrent()
          : WindowManager.instance.get(id),
    );
  }

  @override
  Future<void> init(int id) async {}

  @override
  Future<void> close(int id) async => _w(id)?.invokeMethod((w) => w.close());
  @override
  Future<void> drag(int id) async =>
      _w(id)?.invokeMethod((w) => w.startDragging());
  @override
  Future<void> fullscreen(int id) async =>
      _w(id)?.invokeMethod((w) => w.isFullScreen = true);
  @override
  Future<void> hide(int id) async => _w(id)?.invokeMethod((w) => w.hide());
  @override
  Future<void> hideTitle(int id) async => _w(id)?.invokeMethod(
    (w) => w.titleBarStyle = TitleBarStyle.hidden,
  );
  @override
  Future<void> maximize(int id) async =>
      _w(id)?.invokeMethod((w) => w.maximize());
  @override
  Future<void> minimize(int id) async =>
      _w(id)?.invokeMethod((w) => w.minimize());
  @override
  Future<void> restore(int id) async {
    final w = _w(id);
    if (w == null) return;
    if (w.invokeGetter(() => w.isFullScreen, orElse: false)) {
      w.invokeMethod((w) => w.isFullScreen = false);
    } else if (w.invokeGetter(() => w.isMaximized, orElse: false)) {
      w.invokeMethod((w) => w.unmaximize());
    } else if (w.invokeGetter(() => w.isMinimized, orElse: false)) {
      w.invokeMethod((w) => w.restore());
    }
  }

  @override
  Future<void> show(int id) async => _w(id)?.invokeMethod((w) => w.show());
  @override
  Future<void> showMenu(int id) async {
    final w = _w(id);
    if (w == null) return;
    _guard(() {
      if (!Window.isSystemMenuSupported()) return;
      final cursor = native.DisplayManager.instance
          .getCursorPosition()
          .toOffset();
      final content = w.contentBounds.toRect();
      w.showSystemMenu((cursor - content.topLeft).toNative());
    });
  }

  @override
  Future<void> showTitle(int id) async => _w(id)?.invokeMethod(
    (w) => w.titleBarStyle = TitleBarStyle.normal,
  );

  @override
  Future<void> setBackground(int id, Color color) async =>
      _w(id)?.invokeMethod((w) => w.backgroundColor = color.toNative());
  @override
  Future<void> setBrightness(int id, Brightness brightness) async {
    _guard(
      () => native.Application.instance.setBrightness(switch (brightness) {
        Brightness.light => native.Brightness.light,
        Brightness.dark => native.Brightness.dark,
      }),
    );
  }

  @override
  Future<void> setTitle(int id, String title) async {
    _w(id)?.invokeMethod((w) => w.title = title);
    await _listener(id)._updateState();
  }

  @override
  Future<void> setMinimizable(int id, bool minimizable) async {
    _w(id)?.invokeMethod((w) => w.isMinimizable = minimizable);
    await _listener(id)._updateState();
  }

  @override
  Future<void> setMaximizable(int id, bool maximizable) async {
    _w(id)?.invokeMethod((w) => w.isMaximizable = maximizable);
    await _listener(id)._updateState();
  }

  @override
  Future<void> setClosable(int id, bool closable) async {
    _w(id)?.invokeMethod((w) => w.isClosable = closable);
    await _listener(id)._updateState();
  }

  @override
  Future<void> setControlButtonsVisible(int id, bool visible) async =>
      _w(id)?.invokeMethod((w) => w.isWindowControlButtonsVisible = visible);
  @override
  Future<void> setResizable(int id, bool resizable) async =>
      _w(id)?.invokeMethod((w) => w.isResizable = resizable);
  @override
  Future<void> setMinimumSize(int id, Size size) async =>
      _w(id)?.invokeMethod((w) => w.minimumSize = size.toNative());
  @override
  Future<void> setMaximumSize(int id, Size size) async =>
      _w(id)?.invokeMethod((w) => w.maximumSize = size.toNative());
  @override
  Future<void> setSize(int id, Size size) async =>
      _w(id)?.invokeMethod((w) => w.setSize(size.toNative(), false));
  @override
  Future<void> setPosition(int id, Offset position) async =>
      _w(id)?.invokeMethod((w) => w.position = position.toNative());
  @override
  Future<void> center(int id) async => _w(id)?.invokeMethod((w) => w.center());
  @override
  Future<void> setAlwaysOnTop(int id, bool alwaysOnTop) async =>
      _w(id)?.invokeMethod((w) => w.isAlwaysOnTop = alwaysOnTop);
  @override
  Future<void> setSkipTaskbar(int id, bool skip) async =>
      _w(id)?.invokeMethod((w) => w.isVisibleInTaskbar = !skip);

  @override
  Future<YaruWindowState> state(int id) async => _w(id).state();
  @override
  Stream<YaruWindowState> states(int id) => _listener(id).states();

  @override
  Future<void> onClose(int id, FutureOr<bool> Function() handler) async {
    _closeListener(id).addCloseHandler(handler);
  }
}

/// Runs [body], answering null when the native library is not available.
T? _guard<T>(T Function() body) {
  try {
    return body();
  } on ArgumentError {
    return null;
  } on MissingPluginException {
    return null;
  }
}

extension _YaruWindowX on Window? {
  T invokeGetter<T>(T Function() getter, {required T orElse}) =>
      _guard(getter) ?? orElse;

  void invokeMethod(void Function(Window window) method) {
    final window = this;
    if (window != null) _guard(() => method(window));
  }

  YaruWindowState state() {
    final active = invokeGetter(() => this!.isFocused, orElse: true);
    final closable = invokeGetter(() => this!.isClosable, orElse: true);
    final fullscreen = invokeGetter(() => this!.isFullScreen, orElse: false);
    final maximizable = invokeGetter(() => this!.isMaximizable, orElse: true);
    final maximized = invokeGetter(() => this!.isMaximized, orElse: false);
    final minimizable = invokeGetter(() => this!.isMinimizable, orElse: true);
    final minimized = invokeGetter(() => this!.isMinimized, orElse: false);
    final movable = invokeGetter(() => this!.isMovable, orElse: true);
    final title = invokeGetter(() => this!.title, orElse: '');
    final visible = invokeGetter(() => this!.isVisible, orElse: true);
    return YaruWindowState(
      isActive: active,
      isClosable: closable,
      isFullscreen: fullscreen,
      isMaximizable: maximizable && !maximized,
      isMaximized: maximized,
      isMinimizable: minimizable && !minimized,
      isMinimized: minimized,
      isMovable: movable && !kIsWeb,
      isRestorable: fullscreen || maximized || minimized,
      title: title,
      isVisible: visible,
    );
  }
}

class _YaruWindowStatesListener {
  _YaruWindowStatesListener(this._window);

  final Window? _window;
  StreamController<YaruWindowState>? _controller;
  ListenerId? _listenerId;

  Stream<YaruWindowState> states() async* {
    _controller ??= StreamController<YaruWindowState>.broadcast(
      onListen: () => _listenerId = _guard<ListenerId?>(
        () => _window?.addListener(_onEvent),
      ),
      onCancel: () {
        final id = _listenerId;
        if (id != null) _guard(() => _window?.removeListener(id));
        _listenerId = null;
      },
    );
    yield* _controller!.stream;
  }

  Future<void> close() async => await _controller?.close();

  Future<void> _updateState() async {
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.add(_window.state());
    }
  }

  void _onEvent(WindowEvent event) {
    switch (event) {
      case WindowBlurredEvent():
      case WindowFocusedEvent():
      case WindowEnteredFullScreenEvent():
      case WindowExitedFullScreenEvent():
      case WindowMaximizedEvent():
      case WindowMinimizedEvent():
      case WindowRestoredEvent():
      case WindowPropertyChangedEvent():
        _updateState();
      default:
        break;
    }
  }
}

class _YaruWindowOnCloseListener {
  _YaruWindowOnCloseListener(this._window) {
    _guard<ListenerId?>(() => _window?.addListener(_onEvent));
  }

  final Window? _window;
  final _onCloseHandlers = <FutureOr<bool> Function()>[];

  void addCloseHandler(FutureOr<bool> Function() handler) {
    _onCloseHandlers.add(handler);
  }

  Future<void> _onEvent(WindowEvent event) async {
    if (event is! WindowCloseRequestedEvent || _onCloseHandlers.isEmpty) {
      return;
    }
    // Hold the close request open while the handlers decide.
    final decision = event.request.defer();
    var allow = true;
    for (final handler in _onCloseHandlers) {
      if (!await handler()) {
        allow = false;
        break;
      }
    }
    if (decision != null) {
      allow ? decision.accept() : decision.cancel();
    } else if (!allow) {
      event.request.cancel();
    }
  }
}
