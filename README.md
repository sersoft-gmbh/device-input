# DeviceInput

[![GitHub release](https://img.shields.io/github/release/sersoft-gmbh/device-input.svg?style=flat)](https://github.com/sersoft-gmbh/device-input/releases/latest)
![Tests](https://github.com/sersoft-gmbh/device-input/workflows/Tests/badge.svg)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1c5dcd572904497db008ad2eb49e7a59)](https://www.codacy.com/gh/sersoft-gmbh/device-input/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=sersoft-gmbh/device-input&amp;utm_campaign=Badge_Grade)
[![codecov](https://codecov.io/gh/sersoft-gmbh/device-input/branch/master/graph/badge.svg?token=LXIl04FQV7)](https://codecov.io/gh/sersoft-gmbh/device-input)
[![Docs](https://img.shields.io/badge/-documentation-informational)](https://sersoft-gmbh.github.io/device-input)

Processes inputs read from `/dev/input` device streams.

## Installation

Add the following dependency to your `Package.swift`:
```swift
.package(url: "https://github.com/sersoft-gmbh/device-input.git", from: "7.0.0"),
```

## Compatibility

-   For Swift as of version 5.3, use DeviceInput version 4.x.y.
-   For Swift as of version 5.5, use DeviceInput version 5.x.y.
-   For Swift as of version 5.6, use DeviceInput version 6.x.y.
-   For Swift as of version 5.9, use DeviceInput version 7.x.y.

## Usage

### InputDevice

An `InputDevice` is the entry point for streaming input events. Create an input device by passing it the path to the input file. By default, an input device "grabs" its input file when it begins streaming for events. By doing so, no other process (e.g. the default system input handler) will receive the events of the input device. However, this only works on Linux. You can manually pass `false` to the `grabDevice` parameter in the initializer if you explicitly don't want to grab the device.
You then use the asynchronouse `events` sequence on the input device.

### InputEvent

Registered event consumers are passed an array of `InputEvent` structs. It represents an `input_event` from the [linux source](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/linux/input.h), but uses native swift types instead of C types. Constants help dealing with events. However, it is currently optimized for handling key state change events. Axis events and other types might need additional work (see the section below about possible features). 

## Possible Features

While not yet integrated, the following features might provide added value and could make it into DeviceInput in the future:

-   Improved `InputEvent` that is optimized for the various kinds of events sent by the [input subsystem](https://www.kernel.org/doc/html/latest/input/input_uapi.html).

## Documentation

The API is documented using header doc. If you prefer to view the documentation as a webpage, there is an [online version](https://sersoft-gmbh.github.io/device-input) available for you.

## Contributing

If you find a bug / like to see a new feature in DeviceInput there are a few ways of helping out:

-   If you can fix the bug / implement the feature yourself please do and open a PR.
-   If you know how to code (which you probably do), please add a (failing) test and open a PR. We'll try to get your test green ASAP.
-   If you can do neither, then open an issue. While this might be the easiest way, it will likely take the longest for the bug to be fixed / feature to be implemented.

## License

See [LICENSE](./LICENSE) file.
