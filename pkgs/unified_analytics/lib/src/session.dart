// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'error_handler.dart';
import 'event.dart';
import 'initializer.dart';

class Session {
  final Directory homeDirectory;
  final FileSystem fs;
  final File sessionFile;
  final ErrorHandler _errorHandler;

  Session({
    required this.homeDirectory,
    required this.fs,
    required ErrorHandler errorHandler,
  })  : sessionFile = fs.file(p.join(
            homeDirectory.path, kDartToolDirectoryName, kSessionFileName)),
        _errorHandler = errorHandler;

  int get sessionId {
    if (_sessionId != null) {
      return _sessionId!;
    }
    _sessionId = _readSessionIdFromDisk();
    return _sessionId!;
  }

  int? _sessionId;

  /// This will use the data parsed from the
  /// session file in the dart-tool directory
  /// to get the session id if the last ping was within
  /// [kSessionDurationMinutes].
  ///
  /// If time since last ping exceeds the duration, then the file
  /// will be updated with a new session id and that will be returned.
  ///
  /// Note, the file will always be updated when calling this method
  /// because the last ping variable will always need to be persisted.
  // TODO
  int getSessionId() {
    if (!sessionFile.existsSync()) {
      _errorHandler.log(Event.analyticsException(
        workflow: 'Session._refreshSessionData',
        error: 'FileSystemException',
      ));

      // TODO handle filesystemexception?
      Initializer.createSessionFile(sessionFile: sessionFile);
    }
    final lastPingDateTime = sessionFile.lastModifiedSync();

    final now = clock.now();
    if (!_longerThanSessionDuration(now, lastPingDateTime)) {
      sessionFile.setLastModifiedSync(now);
      return sessionId;
    }

    // Session file is stale
    _sessionId = now.millisecondsSinceEpoch;

    // Update the session file with the latest session id
    sessionFile.writeAsStringSync('{"session_id": $_sessionId}');
    return _sessionId!;
  }

  bool _longerThanSessionDuration(DateTime now, DateTime other) {
    return now.difference(other).inMinutes > kSessionDurationMinutes;
  }

  /// This will go to the session file within the dart-tool
  /// directory and fetch the latest data from the session file to update
  /// the class's variables. If the session file is malformed, a new
  /// session file will be recreated.
  ///
  /// This allows the session data in this class to always be up
  /// to date incase another tool is also calling this package and
  /// making updates to the session file.
  int _readSessionIdFromDisk() {
    try {
      // Failing to parse the contents will result in the current timestamp
      // being used as the session id and will get used to recreate the file
      final sessionFileContents = sessionFile.readAsStringSync();
      final sessionObj =
          jsonDecode(sessionFileContents) as Map<String, Object?>;
      return sessionObj['session_id'] as int;
    } on FormatException catch (err) {
      final now = clock.now();

      _errorHandler.log(Event.analyticsException(
        workflow: 'Session._refreshSessionData',
        error: err.runtimeType.toString(),
        description: 'message: ${err.message}\nsource: ${err.source}',
      ));

      // Fallback to setting the session id as the current time
      return now.millisecondsSinceEpoch;
    } on FileSystemException catch (err) {
      final now = clock.now();
      Initializer.createSessionFile(
        sessionFile: sessionFile,
        sessionIdOverride: now,
      );

      _errorHandler.log(Event.analyticsException(
        workflow: 'Session._refreshSessionData',
        error: err.runtimeType.toString(),
        description: err.osError?.toString(),
      ));

      // Fallback to setting the session id as the current time
      return now.millisecondsSinceEpoch;
    }
  }
}
