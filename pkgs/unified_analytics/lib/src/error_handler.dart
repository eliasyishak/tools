// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analytics.dart';
import 'enums.dart';
import 'event.dart';

class ErrorHandler {
  /// Stores each of the events that have been sent to GA4 so that the
  /// same error doesn't get sent twice.
  final Set<Event> _sentErrorEvents = {};
  final SendFunction _sendFunction;

  /// Handles any errors encountered within package:unified_analytics.
  ErrorHandler({required SendFunction sendFunction})
      : _sendFunction = sendFunction;

  /// Sends the encountered error [Event.analyticsException] to GA4 backend.
  ///
  /// This method will not send the event to GA4 if it has already been
  /// sent before during the current process.
  void log(Event event) {
    Future<void>.delayed(Duration.zero).then((_) {
      if (event.eventName != DashEvent.analyticsException ||
          _sentErrorEvents.contains(event)) {
        return;
      }

      try {
        _sendFunction(event);
      } on Object {
        // ignore errors while sending this
        print('uh oh');
      }
      _sentErrorEvents.add(event);
    });
  }
}
