//
//  Doer.swift
//

import Foundation

// MARK: - Classes

public final class Doer {
  public final class Task {
    public let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    var observers: [AnyObject] = []
    let observerQueue = DispatchQueue(label: "com.doer.observers")
    var ran = false
    var waited = false
    init() {
      process.standardOutput = outputPipe
      process.standardError = errorPipe
    }
  }
}

// MARK: - Creating tasks

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

// MARK: - Customizing tasks

public extension Doer.Task {
  func at(directory: String) -> Doer.Task {
    process.currentDirectoryPath = directory
    return self
  }
  
  func output(progress: @escaping (_ availableData: Data) -> Void) -> Doer.Task {
    let handle = outputPipe.fileHandleForReading
    let callProgressAndReturnIfDone = { () -> Bool in
      let data = handle.availableData
      guard data.count > 0 else { return true }
      progress(data)
      return false
    }
    observe(name: .NSFileHandleDataAvailable, object: handle, queue: nil, closure: callProgressAndReturnIfDone)
    observe(name: Process.didTerminateNotification, object: process, queue: nil) {
      _ = callProgressAndReturnIfDone()
      return true
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

// MARK: - Getting output, launching and ending tasks

public extension Doer.Task {
  var output: String? {
    run(wait: true)
    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)
  }
  
  @discardableResult func run(on context: ((@escaping () -> Void) -> Void)? = nil, wait: Bool = true) -> Doer.Task {
    guard let context = context else {
      _run(wait: wait)
      return self
    }
    context { self._run(wait: wait) }
    return self
  }
  
  func end() {
     clearObservers()
     process.terminate()
   }
}

// MARK: - `run()` helpers

public extension Doer.Task {
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
}

// MARK: - Observer helpers

public extension Doer.Task {
  private func add(observer: AnyObject?) {
    guard let observer = observer else { return }
    observerQueue.sync { observers.append(observer) }
  }
  
  private func remove(observer: AnyObject) {
    observerQueue.sync {
      NotificationCenter.default.removeObserver(observer)
      observers.removeAll { $0 === observer }
    }
  }
  
  private func clearObservers() {
    observerQueue.sync {
      for observer in observers {
        NotificationCenter.default.removeObserver(observer)
      }
      observers = []
    }
  }
  
  private func observe(name: Notification.Name, object: AnyObject, queue: OperationQueue?, closure: @escaping () -> Bool) {
    var observer: AnyObject? = nil
    observer = NotificationCenter.default.addObserver(forName: name, object: object, queue: queue) {
      _ in
      guard let observer = observer else { fatalError("Observer released before notification.") }
      guard closure() else { return }
      self.remove(observer: observer)
    }
    add(observer: observer)
  }
}

// MARK: - DispatchQueue extension

public extension DispatchQueue {
  var synchronously: (() -> Void) -> Void { return sync }
  var asynchronously: (@escaping () -> Void) -> Void { return { self.async(execute: $0) } }
}

