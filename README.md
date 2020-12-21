<p align="center">
<a href="https://github.com/yonaskolb/XcodeGen">
<img src="Assets/Logo_animated.gif" alt="XcodeGen" />
</a>
</p>
<p align="center">
  <a href="https://github.com/yonaskolb/XcodeGen/releases">
    <img src="https://img.shields.io/github/release/yonaskolb/xcodegen.svg"/>
  </a>
  <a href="https://swiftpackageindex.com/yonaskolb/XcodeGen">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fyonaskolb%2FXcodeGen%2Fbadge%3Ftype%3Dplatforms" alt="Swift Package Manager Platforms" />
  </a>
  <a href="https://swiftpackageindex.com/yonaskolb/XcodeGen">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fyonaskolb%2FXcodeGen%2Fbadge%3Ftype%3Dswift-versions" alt="Swift Versions" />
  </a>
  <a href="https://github.com/yonaskolb/XcodeGen/blob/master/LICENSE">
    <img src="https://img.shields.io/github/license/yonaskolb/XcodeGen.svg"/>
  </a>
</p>

# XcodeGen

XcodeGen is a command line tool written in Swift that generates your Xcode project using your folder structure and a project spec.

The project spec is a YAML or JSON file that defines your targets, configurations, schemes, custom build settings and many other options. All your source directories are automatically parsed and referenced appropriately while preserving your folder structure. Sensible defaults are used in many places, so you only need to customize what is needed. Very complex projects can also be defined using more advanced features.

- ✅ Generate projects on demand and remove your `.xcodeproj` from git, which means **no more merge conflicts**!
- ✅ Groups and files in Xcode are always **synced** to your directories on disk
- ✅ Easy **configuration** of projects which is human readable and git friendly
- ✅ Easily copy and paste **files and directories** without having to edit anything in Xcode
- ✅ Share build settings across multiple targets with **build setting groups**
- ✅ Automatically generate Schemes for **different environments** like test and production
- ✅ Easily **create new projects** with complicated setups on demand without messing around with Xcode
- ✅ Generate from anywhere including on **CI**
- ✅ Distribute your spec amongst multiple files for easy **sharing** and overriding
- ✅ Easily create **multi-platform** frameworks
- ✅ Integrate **Carthage** frameworks without any work
- ✅ Export **Dependency Diagrams** to view in [Graphviz](https://www.graphviz.org)

Given an example project spec:

```yaml
name: MyProject
include:
  - base_spec.yml
options:
  bundleIdPrefix: com.myapp
packages:
  Yams:
    url: https://github.com/jpsim/Yams
    from: 2.0.0
targets:
  MyApp:
    type: application
    platform: iOS
    deploymentTarget: "10.0"
    sources: [MyApp]
    settings:
      configs:
        debug:
          CUSTOM_BUILD_SETTING: my_debug_value
        release:
          CUSTOM_BUILD_SETTING: my_release_value
    dependencies:
      - target: MyFramework
      - carthage: Alamofire
      - framework: Vendor/MyFramework.framework
      - sdk: Contacts.framework
      - sdk: libc++.tbd
      - package: Yams
  MyFramework:
    type: framework
    platform: iOS
    sources: [MyFramework]
```
A project would be created with 2 connected targets, with all the required configurations and build settings. See the [Project Spec](Docs/ProjectSpec.md) documentation for all the options you can specify, and [Usage](Docs/Usage.md) for more general documentation.

## Installing

Make sure Xcode 11 is installed first.

### [Mint](https://github.com/yonaskolb/mint)
```sh
mint install yonaskolb/xcodegen
```

### Make

```shell
git clone https://github.com/yonaskolb/XcodeGen.git
cd XcodeGen
make install
```

### Homebrew

```shell
brew install xcodegen
```

### Swift Package Manager

**Use as CLI**

```shell
git clone https://github.com/yonaskolb/XcodeGen.git
cd XcodeGen
swift run xcodegen
```

**Use as dependency**

Add the following to your Package.swift file's dependencies:

```swift
.package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "2.18.0"),
```

And then import wherever needed: `import XcodeGenKit`

## Usage

Simply run:

```shell
xcodegen generate
```

This will look for a project spec in the current directory called `project.yml` and generate an Xcode project with the name defined in the spec.

Options:

- **--spec**: An optional path to a `.yml` or `.json` project spec. Defaults to `project.yml`
- **--project**: An optional path to a directory where the project will be generated. By default this is the directory the spec lives in.
- **--quiet**: Suppress informational and success messages.
- **--use-cache**: Used to prevent unnecessarily generating the project. If this is set, then a cache file will be written to when a project is generated. If `xcodegen` is later run but the spec and all the files it contains are the same, the project won't be generated.
- **--cache-path**: A custom path to use for your cache file. This defaults to `~/.xcodegen/cache/{PROJECT_SPEC_PATH_HASH}`

Optional Environment Variables:

`XCODEGEN_SETTINGS_PRESETS_PARENT_DIR`: When certain build systems (i.e Bazel) use `xcodegen` as a dependency, the `SettingsPresets` directory can sometimes be placed in surprising locations.  Setting this environment variables gives users of these build systems a way to provide a custom path to the parent directory of  the `SettingsPresets` directory that overrides the defaults lookup locations if it is found, and proceeds to the default lookup locations if it is not found.

There are other commands as well such as `xcodegen dump` which lets out output the resolved spec in many different formats, or write it to a file. Use `xcodegen help` to see more detailed usage information.

## Dependency Diagrams
<details>
  <summary>Click to expand!</summary>

#### How to export dependency diagrams:

To stdout:

```
xcodegen dump --type graphviz
```

To a file:

```
xcodegen dump --type graphviz --file Graph.viz
```

During implementation, `graphviz` formatting was validated using [GraphvizOnline](https://dreampuf.github.io/GraphvizOnline/), [WebGraphviz](http://www.webgraphviz.com), and [Graphviz on MacOS](graphviz.org).
</details>

## Editing
```shell
git clone https://github.com/yonaskolb/XcodeGen.git
cd XcodeGen
swift package generate-xcodeproj
```
This use Swift Project Manager to create an `xcodeproj` file that you can open, edit and run in Xcode, which makes editing any code easier.

If you want to pass any required arguments when running in Xcode, you can edit the scheme to include launch arguments.

## Documentation
- See [Project Spec](Docs/ProjectSpec.md) documentation for all the various properties and options that can be set
- See [Usage](Docs/Usage.md) for more specific usage and use case documentation
- See [FAQ](Docs/FAQ.md) for a list of some frequently asked questions
- See [Examples](Docs/Examples.md) for some real world XcodeGen project specs out in the wild

## Alternatives
If XcodeGen doesn't meet your needs try these great alternatives:
- [Tuist](https://github.com/tuist/tuist)
- [Xcake](https://github.com/igor-makarov/xcake)
- [struct](https://github.com/workshop/struct)

## Attributions
This tool is powered by:

- [XcodeProj](https://github.com/tuist/XcodeProj)
- [JSONUtilities](https://github.com/yonaskolb/JSONUtilities)
- [Spectre](https://github.com/kylef/Spectre)
- [PathKit](https://github.com/kylef/PathKit)
- [Yams](https://github.com/jpsim/Yams)
- [SwiftCLI](https://github.com/jakeheis/SwiftCLI)

Inspiration for this tool came from:

- [struct](https://github.com/workshop/struct)
- [Xcake](https://github.com/igor-makarov/xcake)
- [CocoaPods Xcodeproj](https://github.com/CocoaPods/Xcodeproj)

## Contributions
Pull requests and issues are always welcome. Please open any issues and PRs for bugs, features, or documentation.

[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/0)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/0)[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/1)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/1)[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/2)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/2)[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/3)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/3)[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/4)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/4)[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/5)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/5)[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/6)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/6)[![](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/images/7)](https://sourcerer.io/fame/yonaskolb/yonaskolb/XcodeGen/links/7)

## License

XcodeGen is licensed under the MIT license. See [LICENSE](LICENSE) for more info.
