import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import XcodeProj
import Yams

extension Project {

    public func getProjectBuildSettings(config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = [:]

        // set project SDKROOT is a single platform
        if targets.count > 0 {
            let platforms = Dictionary(grouping: targets) { $0.platform }
            if platforms.count == 1 {
                let platform = platforms.first!.key
                buildSettings["SDKROOT"] = platform.sdkRoot
            }
        }

        if let type = config.type, options.settingPresets.applyProject {
            buildSettings += SettingsPresetFile.base.getBuildSettings()
            buildSettings += SettingsPresetFile.config(type).getBuildSettings()
        }

        // apply custom platform version
        for platform in Platform.allCases {
            if let version = options.deploymentTarget.version(for: platform) {
                buildSettings[platform.deploymentTargetSetting] = version.deploymentTarget
            }
        }

        // Prevent setting presets from overrwriting settings in project xcconfig files
        if let configPath = configFiles[config.name] {
            buildSettings = removeConfigFileSettings(from: buildSettings, configPath: configPath)
        }

        buildSettings += getBuildSettings(settings: settings, config: config)

        return buildSettings
    }

    public func getTargetBuildSettings(target: Target, config: Config) -> BuildSettings {
        var buildSettings = BuildSettings()

        if options.settingPresets.applyTarget {
            buildSettings += SettingsPresetFile.platform(target.platform).getBuildSettings()
            buildSettings += SettingsPresetFile.product(target.type).getBuildSettings()
            buildSettings += SettingsPresetFile.productPlatform(target.type, target.platform).getBuildSettings()
        }

        // apply custom platform version
        if let version = target.deploymentTarget {
            buildSettings[target.platform.deploymentTargetSetting] = version.deploymentTarget
        }

        // Prevent setting presets from overrwriting settings in target xcconfig files
        if let configPath = target.configFiles[config.name] {
            buildSettings = removeConfigFileSettings(from: buildSettings, configPath: configPath)
        }
        // Prevent setting presets from overrwriting settings in project xcconfig files
        if let configPath = configFiles[config.name] {
            buildSettings = removeConfigFileSettings(from: buildSettings, configPath: configPath)
        }

        buildSettings += getBuildSettings(settings: target.settings, config: config)

        return buildSettings
    }

    public func getBuildSettings(settings: Settings, config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = [:]

        for group in settings.groups {
            if let settings = settingGroups[group] {
                buildSettings += getBuildSettings(settings: settings, config: config)
            }
        }

        buildSettings += settings.buildSettings

        for (configVariant, settings) in settings.configSettings {
            let isPartialMatch = config.name.lowercased().contains(configVariant.lowercased())
            if isPartialMatch {
                let exactConfig = getConfig(configVariant)
                let matchesExactlyToOtherConfig = exactConfig != nil && exactConfig?.name != config.name
                if !matchesExactlyToOtherConfig {
                    buildSettings += getBuildSettings(settings: settings, config: config)
                }
            }
        }

        return buildSettings
    }

    // combines all levels of a target's settings: target, target config, project, project config
    public func getCombinedBuildSetting(_ setting: String, target: ProjectTarget, config: Config) -> Any? {
        if let target = target as? Target,
            let value = getTargetBuildSettings(target: target, config: config)[setting] {
            return value
        }
        if let configFilePath = target.configFiles[config.name],
            let value = loadConfigFileBuildSettings(path: configFilePath)?[setting] {
            return value
        }
        if let value = getProjectBuildSettings(config: config)[setting] {
            return value
        }
        if let configFilePath = configFiles[config.name],
            let value = loadConfigFileBuildSettings(path: configFilePath)?[setting] {
            return value
        }
        return nil
    }

    public func getBoolBuildSetting(_ setting: String, target: ProjectTarget, config: Config) -> Bool? {
        guard let value = getCombinedBuildSetting(setting, target: target, config: config) else { return nil }

        if let boolValue = value as? Bool {
            return boolValue
        } else if let stringValue = value as? String {
            return stringValue == "YES"
        }

        return nil
    }

    public func targetHasBuildSetting(_ setting: String, target: Target, config: Config) -> Bool {
        getCombinedBuildSetting(setting, target: target, config: config) != nil
    }

    /// Removes values from build settings if they are defined in an xcconfig file
    private func removeConfigFileSettings(from buildSettings: BuildSettings, configPath: String) -> BuildSettings {
        var buildSettings = buildSettings

        if let configSettings = loadConfigFileBuildSettings(path: configPath) {
            for key in configSettings.keys {
                // FIXME: Catch platform specifier. e.g. LD_RUNPATH_SEARCH_PATHS[sdk=iphone*]
                buildSettings.removeValue(forKey: key)
                buildSettings.removeValue(forKey: key.quoted)
            }
        }

        return buildSettings
    }

    /// Returns cached build settings from a config file
    private func loadConfigFileBuildSettings(path: String) -> BuildSettings? {
        let configFilePath = basePath + path
        if let cached = configFileSettings[configFilePath.string] {
            return cached.value
        } else {
            guard let configFile = try? XCConfig(path: configFilePath) else {
                configFileSettings[configFilePath.string] = .nothing
                return nil
            }
            let settings = configFile.flattenedBuildSettings()
            configFileSettings[configFilePath.string] = .cached(settings)
            return settings
        }
    }
}

private enum Cached<T> {
    case cached(T)
    case nothing

    var value: T? {
        switch self {
        case let .cached(value): return value
        case .nothing: return nil
        }
    }
}

// cached flattened xcconfig file settings
private var configFileSettings: [String: Cached<BuildSettings>] = [:]

// cached setting preset settings
private var settingPresetSettings: [String: Cached<BuildSettings>] = [:]

extension SettingsPresetFile {

    public func getBuildSettings() -> BuildSettings? {
        if let cached = settingPresetSettings[path] {
            return cached.value
        }

        let bundlePath = Path(Bundle.main.bundlePath)
        let relativeSettingsPresetsPath = Path("SettingPresets/\(path).yml")

        var possibleSettingsPresetsPaths: [Path] = []

        // Allow users to optionally specify the location of the `SettingPresets`
        // parent directory as an environment variable.
        //
        // If the user goes out of their way to specify this environment variable,
        // we assume they _really_ want to look for it here, so we give it first
        // priority over the usual places we look for it.  If it is not found,
        // we just proceed to look for it in the normal locations as usual.
        //
        if let settingsPresetsParentDirectory: String = ProcessInfo.processInfo.environment["XCODEGEN_SETTINGS_PRESETS_PARENT_DIR"] {
            possibleSettingsPresetsPaths.append(Path(settingsPresetsParentDirectory) + relativeSettingsPresetsPath)
        }

        // These are the places that we look for the `SettingPresets` directory if
        // the user hasn't gone out of their way to look for it in another place
        // by specifying an environment variable - or if it can't be found at the
        // location the user specified in the environment variable.
        //
        possibleSettingsPresetsPaths.append(relativeSettingsPresetsPath)
        possibleSettingsPresetsPaths.append(bundlePath + relativeSettingsPresetsPath)
        possibleSettingsPresetsPaths.append(bundlePath + "../share/xcodegen/\(relativeSettingsPresetsPath)")
        possibleSettingsPresetsPaths.append(Path(#file).parent().parent().parent() + relativeSettingsPresetsPath)

        if let symlink = try? (bundlePath + "xcodegen").symlinkDestination() {
            possibleSettingsPresetsPaths = [
                symlink.parent() + relativeSettingsPresetsPath,
            ] + possibleSettingsPresetsPaths
        }

        guard let settingsPresetsPath = possibleSettingsPresetsPaths.first(where: { $0.exists }) else {
            switch self {
            case .base, .config, .platform:
                print("No \"\(name)\" settings found")
            case .product, .productPlatform:
                break
            }
            settingPresetSettings[path] = .nothing
            return nil
        }

        guard let buildSettings = try? loadYamlDictionary(path: settingsPresetsPath) else {
            print("Error parsing \"\(name)\" settings")
            return nil
        }
        settingPresetSettings[path] = .cached(buildSettings)
        return buildSettings
    }
}
