# ``DeviceInput``

Process inputs read from `/dev/input` device streams.

## Installation

Add the following dependency to your `Package.swift`:
```swift
.package(url: "https://github.com/sersoft-gmbh/device-input.git", from: "8.0.0"),
```

## Compatibility

-   For Swift as of version 5.3, use DeviceInput version 4.x.y.
-   For Swift as of version 5.5, use DeviceInput version 5.x.y.
-   For Swift as of version 5.6, use DeviceInput version 6.x.y.
-   For Swift as of version 5.9, use DeviceInput version 7.x.y.
-   For Swift as of version 6.0, use DeviceInput version 8.x.y.

## Usage

### Input Device

An ``InputDevice`` is the entry point for streaming input events. Create an input device by passing it the path to the input file. By default, an input device "grabs" its input file when it begins streaming for events. By doing so, no other process (e.g. the default system input handler) will receive the events of the input device. However, this only works on Linux. You can manually pass `false` to the `grabDevice` parameter in the initializer if you explicitly don't want to grab the device.
You then use the asynchronouse ``InputDevice/events`` sequence on the input device.

### Input Event

The ``InputDevice/Events`` sequence emits ``InputEvent`` structs over time. It represents an `input_event` from the [linux source](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/linux/input.h), but uses native Swift types instead of C types. Constants help dealing with events. However, it is currently optimized for handling key state change events. Axis events and other kinds of events sent by the [input subsystem](https://www.kernel.org/doc/html/latest/input/input_uapi.html) might need additional work. 
