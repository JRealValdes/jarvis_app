import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/widgets/chat_list_scroll.dart';

void main() {
  group('isChatNearBottom', () {
    test('reversed list treats offset near 0 as bottom', () {
      expect(
        isChatNearBottom(
          pixels: 0,
          maxScrollExtent: 400,
          reverse: true,
        ),
        isTrue,
      );
      expect(
        isChatNearBottom(
          pixels: 40,
          maxScrollExtent: 400,
          reverse: true,
        ),
        isTrue,
      );
      expect(
        isChatNearBottom(
          pixels: 120,
          maxScrollExtent: 400,
          reverse: true,
        ),
        isFalse,
      );
    });

    test('forward list treats offset near max as bottom', () {
      expect(
        isChatNearBottom(
          pixels: 400,
          maxScrollExtent: 400,
          reverse: false,
        ),
        isTrue,
      );
      expect(
        isChatNearBottom(
          pixels: 360,
          maxScrollExtent: 400,
          reverse: false,
        ),
        isTrue,
      );
      expect(
        isChatNearBottom(
          pixels: 100,
          maxScrollExtent: 400,
          reverse: false,
        ),
        isFalse,
      );
    });
  });

  group('chatBottomScrollOffset', () {
    test('reversed bottom is 0; forward bottom is max', () {
      expect(
        chatBottomScrollOffset(maxScrollExtent: 250, reverse: true),
        0,
      );
      expect(
        chatBottomScrollOffset(maxScrollExtent: 250, reverse: false),
        250,
      );
    });
  });

  group('shouldKeepBottomAnchorOnKeyboard', () {
    test('only when already at bottom and inset actually changes', () {
      expect(
        shouldKeepBottomAnchorOnKeyboard(
          wasAtBottom: true,
          previousBottomInset: 0,
          nextBottomInset: 300,
        ),
        isTrue,
      );
      expect(
        shouldKeepBottomAnchorOnKeyboard(
          wasAtBottom: true,
          previousBottomInset: 300,
          nextBottomInset: 0,
        ),
        isTrue,
      );
      expect(
        shouldKeepBottomAnchorOnKeyboard(
          wasAtBottom: false,
          previousBottomInset: 0,
          nextBottomInset: 300,
        ),
        isFalse,
      );
      expect(
        shouldKeepBottomAnchorOnKeyboard(
          wasAtBottom: true,
          previousBottomInset: 300,
          nextBottomInset: 300.5,
        ),
        isFalse,
      );
    });
  });
}
