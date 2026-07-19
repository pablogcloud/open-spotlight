import Foundation
import XCTest

@testable import OpenLauncher

final class ProcessRunnerTests: XCTestCase {
  func testCapturesStandardOutputAndTermination() async throws {
    let invocation = try ProcessInvocation(
      executableURL: URL(fileURLWithPath: "/bin/echo"),
      arguments: ["hello"]
    )

    let session = try await FoundationProcessRunner().start(invocation)
    var output = Data()
    var termination: ProcessOutputEvent?

    for try await event in session.events {
      switch event {
      case .standardOutput(let data): output.append(data)
      case .terminated: termination = event
      case .standardError: break
      }
    }

    XCTAssertEqual(String(decoding: output, as: UTF8.self), "hello\n")
    XCTAssertEqual(termination, .terminated(exitCode: 0, reason: .exit))
    XCTAssertFalse(session.isRunning)
  }

  func testDrainsBurstOutputFromBothPipesBeforeTermination() async throws {
    let invocation = try ProcessInvocation(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "/usr/bin/jot 4000; /usr/bin/jot 3000 >&2"]
    )
    let session = try await FoundationProcessRunner().start(invocation)
    var stdout = Data()
    var stderr = Data()
    var sawTermination = false

    for try await event in session.events {
      switch event {
      case .standardOutput(let data):
        XCTAssertFalse(sawTermination)
        stdout.append(data)
      case .standardError(let data):
        XCTAssertFalse(sawTermination)
        stderr.append(data)
      case .terminated:
        sawTermination = true
      }
    }

    XCTAssertEqual(String(decoding: stdout, as: UTF8.self).split(separator: "\n").count, 4_000)
    XCTAssertEqual(String(decoding: stderr, as: UTF8.self).split(separator: "\n").count, 3_000)
    XCTAssertTrue(sawTermination)
  }

  func testCancellationTerminatesLongRunningExecutable() async throws {
    let invocation = try ProcessInvocation(
      executableURL: URL(fileURLWithPath: "/bin/sleep"),
      arguments: ["30"],
      terminationGracePeriod: .milliseconds(100)
    )
    let session = try await FoundationProcessRunner().start(invocation)

    XCTAssertTrue(session.isRunning)
    session.cancel()

    var termination: ProcessOutputEvent?
    for try await event in session.events {
      if case .terminated = event {
        termination = event
      }
    }

    guard case .terminated(let exitCode, let reason) = termination else {
      return XCTFail("Expected a terminal process event")
    }
    XCTAssertNotEqual(exitCode, 0)
    XCTAssertEqual(reason, .uncaughtSignal)
    XCTAssertFalse(session.isRunning)
  }

  func testCancellationTerminatesDescendantProcess() async throws {
    let invocation = try ProcessInvocation(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "/bin/sleep 30 & echo $!; wait"],
      terminationGracePeriod: .milliseconds(100)
    )
    let session = try await FoundationProcessRunner().start(invocation)
    var childPID: pid_t?

    for try await event in session.events {
      if case .standardOutput(let data) = event,
        let pid = pid_t(
          String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
      {
        childPID = pid
        session.cancel()
      }
    }

    guard let childPID else { return XCTFail("Expected the child PID") }
    XCTAssertEqual(Darwin.kill(childPID, 0), -1, "Descendant should not survive cancellation")
    XCTAssertEqual(errno, ESRCH)
  }

  func testRejectsRelativeExecutableURL() {
    XCTAssertThrowsError(
      try ProcessInvocation(executableURL: URL(string: "relative/tool")!)
    ) { error in
      XCTAssertEqual(error as? ProcessRunnerError, .executableMustBeAnAbsoluteFileURL)
    }
  }
}
