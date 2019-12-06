//
//  Doer.swift
//

import Foundation

public final class Doer {
  public final class Task {
    public let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    var ran = false
    var waited = false
    init() {
      process.standardOutput = outputPipe
      process.standardError = errorPipe
    }
  }
}

public extension Doer {
  static func task(_ launchPath: String, _ arguments: [String]) -> Task {
    let task = Task()
    task.process.launchPath = launchPath
    task.process.arguments = arguments
    return task
  }
  
  static func task(_ launchPath: String, _ arguments: String...) -> Task  {
    return task(launchPath, arguments)
  }
}

public extension Doer.Task {
  func at(directory: String) -> Doer.Task {
    process.currentDirectoryPath = directory
    return self
  }
  
  private func _run() {
    guard !ran else { return }
    ran = true
    process.launch()
  }
  
  private func _wait() {
    guard ran && !waited else { return }
    waited = true
    process.waitUntilExit()
  }
  
  private func _run(wait: Bool) {
    _run()
    if (wait) { _wait() }
  }
  
  @discardableResult func run(on context: ((@escaping () -> Void) -> Void)? = nil, wait: Bool = true) -> Doer.Task {
    guard let context = context else {
      _run(wait: wait)
      return self
    }
    context { self._run(wait: wait) }
    return self
  }
  
  var output: String? {
    run(wait: true)
    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)
  }
  
  func output(progress: @escaping (_ availableData: Data) -> Void) -> Doer.Task {
    let handle = outputPipe.fileHandleForReading
    var dataObserver: AnyObject? = nil
    var terminationObserver: AnyObject? = nil
    let callProgressAndReturnIfDone = { () -> Bool in
      let data = handle.availableData
      guard data.count > 0 else { return true }
      progress(data)
      return false
    }
    dataObserver = NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable, object: handle, queue: nil) {
      _ in
      guard let dataObserver = dataObserver else { fatalError("Observer released before notification.") }
      guard callProgressAndReturnIfDone() else { return }
      NotificationCenter.default.removeObserver(dataObserver)
    }
    terminationObserver = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification, object: process, queue: nil) {
      _ in
      guard let terminationObserver = terminationObserver else { fatalError("Observer released before notification.") }
      _ = callProgressAndReturnIfDone()
      NotificationCenter.default.removeObserver(terminationObserver)
    }
    return self
  }
  
  func printingOutput() -> Doer.Task {
    return output {
      data in
      guard let string = String(data: data, encoding: .utf8) else { return }
      print(string)
    }
  }
}

public extension DispatchQueue {
  var synchronous: (() -> Void) -> Void { return sync }
  var asynchronous: (@escaping () -> Void) -> Void { return { self.async(execute: $0) } }
}

