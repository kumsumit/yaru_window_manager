import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nativeapi/nativeapi.dart' as native show Color;
import 'package:window_manager/window_manager.dart';
import 'package:yaru_window_manager/src/window_manager.dart';
import 'package:yaru_window_platform_interface/yaru_window_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const native.Color(r: 0, g: 0, b: 0, a: 255));
    registerFallbackValue((WindowEvent _) {});
    registerFallbackValue(TitleBarStyle.normal);
  });

  test('register', () {
    YaruWindowManager.registerWith();
    expect(YaruWindowPlatform.instance, isA<YaruWindowManager>());
  });

  test('methods', () async {
    final window = mockWindow();
    YaruWindowPlatform.instance = YaruWindowManager(window);

    await YaruWindowPlatform.instance.close(0);
    verify(window.close).called(1);

    await YaruWindowPlatform.instance.drag(0);
    verify(window.startDragging).called(1);

    await YaruWindowPlatform.instance.fullscreen(0);
    verify(() => window.isFullScreen = true).called(1);

    await YaruWindowPlatform.instance.hide(0);
    verify(window.hide).called(1);

    await YaruWindowPlatform.instance.hideTitle(0);
    verify(() => window.titleBarStyle = TitleBarStyle.hidden).called(1);

    await YaruWindowPlatform.instance.maximize(0);
    verify(window.maximize).called(1);

    await YaruWindowPlatform.instance.minimize(0);
    verify(window.minimize).called(1);

    await YaruWindowPlatform.instance.show(0);
    verify(window.show).called(1);

    await YaruWindowPlatform.instance.showTitle(0);
    verify(() => window.titleBarStyle = TitleBarStyle.normal).called(1);

    await YaruWindowPlatform.instance.setBackground(0, Colors.black);
    verify(() => window.backgroundColor = any()).called(1);

    await YaruWindowPlatform.instance.setTitle(0, 'foo bar');
    verify(() => window.title = 'foo bar').called(1);

    await YaruWindowPlatform.instance.setMinimizable(0, true);
    verify(() => window.isMinimizable = true).called(1);

    await YaruWindowPlatform.instance.setMaximizable(0, true);
    verify(() => window.isMaximizable = true).called(1);

    await YaruWindowPlatform.instance.setClosable(0, true);
    verify(() => window.isClosable = true).called(1);
  });

  test('restore', () async {
    final window = mockWindow(isFullscreen: true);
    YaruWindowPlatform.instance = YaruWindowManager(window);
    await YaruWindowPlatform.instance.restore(0);
    verify(() => window.isFullScreen = false).called(1);

    final maximized = mockWindow(isMaximized: true);
    YaruWindowPlatform.instance = YaruWindowManager(maximized);
    await YaruWindowPlatform.instance.restore(0);
    verify(maximized.unmaximize).called(1);

    final minimized = mockWindow(isMinimized: true);
    YaruWindowPlatform.instance = YaruWindowManager(minimized);
    await YaruWindowPlatform.instance.restore(0);
    verify(minimized.restore).called(1);
  });

  test('state', () async {
    YaruWindowPlatform.instance = YaruWindowManager(
      mockWindow(title: 'foo bar'),
    );

    final state = await YaruWindowPlatform.instance.state(0);
    expect(state.isActive, isTrue);
    expect(state.isClosable, isTrue);
    expect(state.isFullscreen, isFalse);
    expect(state.isMaximizable, isTrue);
    expect(state.isMaximized, isFalse);
    expect(state.isMinimized, isFalse);
    expect(state.isMovable, isTrue);
    expect(state.title, 'foo bar');
    expect(state.isVisible, isTrue);
  });

  test('registers a window listener for close handlers', () async {
    final window = mockWindow();
    YaruWindowPlatform.instance = YaruWindowManager(window);

    await YaruWindowPlatform.instance.onClose(0, () => true);
    verify(() => window.addListener(any())).called(1);
  });
}

class MockWindow extends Mock implements Window {}

MockWindow mockWindow({
  bool isActive = true,
  bool isClosable = true,
  bool isFullscreen = false,
  bool isMaximizable = true,
  bool isMaximized = false,
  bool isMinimizable = true,
  bool isMinimized = false,
  bool isMovable = true,
  String title = '',
  bool isVisible = true,
}) {
  final window = MockWindow();
  when(() => window.isClosable).thenReturn(isClosable);
  when(() => window.isFocused).thenReturn(isActive);
  when(() => window.isFullScreen).thenReturn(isFullscreen);
  when(() => window.isMaximizable).thenReturn(isMaximizable);
  when(() => window.isMaximized).thenReturn(isMaximized);
  when(() => window.isMinimizable).thenReturn(isMinimizable);
  when(() => window.isMinimized).thenReturn(isMinimized);
  when(() => window.isMovable).thenReturn(isMovable);
  when(() => window.title).thenReturn(title);
  when(() => window.isVisible).thenReturn(isVisible);
  when(() => window.close()).thenReturn(true);
  when(() => window.addListener(any())).thenReturn(1);
  return window;
}
