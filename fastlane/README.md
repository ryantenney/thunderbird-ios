fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests on the iOS simulator

### ios lint

```sh
[bundle exec] fastlane ios lint
```

Run swift-format lint check

### ios build

```sh
[bundle exec] fastlane ios build
```

Clean build without signing (compilation check)

### ios signing

```sh
[bundle exec] fastlane ios signing
```

Set up App IDs and provisioning profiles via match

### ios device

```sh
[bundle exec] fastlane ios device
```

Build and run on a connected iOS device

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build for App Store release

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
