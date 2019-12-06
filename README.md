# Doer

A shortcut for executing subprocesses (like your everyday Terminal commands) in Swift for MacOS.

## Installation

On Xcode go to **File > Swift Packages > Add Package Dependencies** and enter this repository's URL.

## Examples

### Getting output as a `String`

```swift
let hello = Doer.task("/bin/echo", "Hello World").output // "Hello World\n"
```

### Ignoring output

```swift
Doer.task("/bin/echo", "This echo will be ignored").run()
```

### Launching in the background (not waiting for result)

```swift
Doer.task("/bin/echo", "Scream into the void").run(wait: false)
```

### Everything else

It is possible to pass any number of `String` arguments to the process. You may specify a directory where the task must run. You may also launch it synchronously or asynchronously on any queue, and you may provide a closure to be notified of successive batches of data:

```swift
let queue = DispatchQueue(label: "some.queue.label")

Doer.task("/some/process", "Any", "Number", "Of", "Parameters")
.at(directory: "/some/directory")
.output {
  partialData in
  // Do something with `partialData`
}
.run(on: queue.asynchronously)

```
