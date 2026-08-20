// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void openLemonSqueezyCheckout(String url) {
  if (js.context.hasProperty('openLemonSqueezyOverlay')) {
    js.context.callMethod('openLemonSqueezyOverlay', [url]);
  } else {
    js.context.callMethod('open', [url, '_blank']);
  }
}
