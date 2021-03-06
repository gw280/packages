// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:fuchsia_ctl/fuchsia_ctl.dart';
import 'package:fuchsia_ctl/src/image_paver.dart';
import 'package:fuchsia_ctl/src/operation_result.dart';
import 'package:fuchsia_ctl/src/ssh_key_manager.dart';
import 'package:fuchsia_ctl/src/tar.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  const String deviceName = 'some-name-to-use';

  test('Tar fails', () async {
    const FakeSshKeyManager sshKeyManager = FakeSshKeyManager(true);
    final MemoryFileSystem fs = MemoryFileSystem(style: FileSystemStyle.posix);
    final FakeTar tar = FakeTar(false, fs);
    final MockProcessManager processManager = MockProcessManager();

    when(processManager.start(any)).thenAnswer((_) async {
      return FakeProcess(0, <String>['Good job'], <String>['']);
    });

    final ImagePaver paver = ImagePaver(
      tar: tar,
      sshKeyManager: sshKeyManager,
      fs: fs,
      processManager: processManager,
    );

    final OperationResult result = await paver.pave(
      'generic-x64.tgz',
      deviceName,
      verbose: false,
    );

    verifyNever(processManager.start(any));
    expect(result.success, false);
    expect(result.error, 'tar failed');
  });

  test('Ssh fails', () async {
    const FakeSshKeyManager sshKeyManager = FakeSshKeyManager(false);
    final MemoryFileSystem fs = MemoryFileSystem(style: FileSystemStyle.posix);
    final FakeTar tar = FakeTar(true, fs);
    final MockProcessManager processManager = MockProcessManager();

    when(processManager.start(any)).thenAnswer((_) async {
      return FakeProcess(0, <String>['Good job'], <String>['']);
    });

    final ImagePaver paver = ImagePaver(
      tar: tar,
      sshKeyManager: sshKeyManager,
      fs: fs,
      processManager: processManager,
    );

    final OperationResult result = await paver.pave(
      'generic-x64.tgz',
      deviceName,
      verbose: false,
    );

    verifyNever(processManager.start(any));
    expect(result.success, false);
    expect(result.error, 'ssh failed');
  });

  test('Happy path', () async {
    const FakeSshKeyManager sshKeyManager = FakeSshKeyManager(true);
    final MemoryFileSystem fs = MemoryFileSystem(style: FileSystemStyle.posix);
    final FakeTar tar = FakeTar(true, fs);
    final MockProcessManager processManager = MockProcessManager();

    when(processManager.start(any)).thenAnswer((_) async {
      return FakeProcess(0, <String>['Good job'], <String>['']);
    });

    final ImagePaver paver = ImagePaver(
      tar: tar,
      sshKeyManager: sshKeyManager,
      fs: fs,
      processManager: processManager,
    );

    final OperationResult result = await paver.pave(
      'generic-x64.tgz',
      deviceName,
      verbose: false,
    );

    final List<String> capturedStartArgs = verify(
      processManager.start(captureAny),
    ).captured.cast<List<String>>().single;
    expect(capturedStartArgs.first, endsWith('/pave.sh'));
    expect(capturedStartArgs.skip(1).toList(), <String>[
      '--fail-fast',
      '-1',
      '--allow-zedboot-version-mismatch',
      '-n', deviceName, //
      '--authorized-keys', '.ssh/authorized_keys',
    ]);
    expect(result.success, true);
  });
}

class FakeTar implements Tar {
  const FakeTar(this.passes, this.fs)
      : assert(passes != null),
        assert(fs != null);

  final bool passes;
  final MemoryFileSystem fs;

  @override
  Future<OperationResult> untar(String src, String destination) async {
    if (passes) {
      final Directory dir = fs.directory(destination)
        ..createSync(recursive: true);
      dir.childFile('pave.sh')..createSync();
      return OperationResult.success();
    }
    return OperationResult.error('tar failed');
  }
}

class FakeSshKeyManager implements SshKeyManager {
  const FakeSshKeyManager(this.passes);

  final bool passes;

  @override
  Future<OperationResult> createKeys({
    String destinationPath = '.ssh',
    bool force = false,
  }) async {
    if (passes) {
      return OperationResult.success();
    }
    return OperationResult.error('ssh failed');
  }
}

class MockProcessManager extends Mock implements ProcessManager {}
