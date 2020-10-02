# TerraformKit

TerraformKit is a wrapper around [terraform](https://terraform.io) which provides an interface to the Swift programming 
language. 

![macOS](https://github.com/fourplusone/TerraformKit/workflows/macOS/badge.svg)
![Linux](https://github.com/fourplusone/TerraformKit/workflows/Linux/badge.svg)

## Usage

TerraformKit is distributed as a SwiftPM Package. You add it via "Add package dependency" in Xcode
or add the following code to the `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/fourplusone/TerraformKit", .upToNextMinor(from: "0.1.0")),
],
targets: [
    .target(
        /* ... */ dependencies: [ "TerraformKit" ]),
```

## API Compatibility

The API of TerraformKit has not been stabilized yet. Therefore, minor versions may have breaking
API changes

## Notice

This project is not affiliated with Hashicorp.

## License

MIT License
