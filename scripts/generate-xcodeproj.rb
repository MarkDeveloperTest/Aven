#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"
require "xcodeproj"

REPOSITORY_ROOT = Pathname.new(__dir__).join("..").expand_path.cleanpath
PROJECT_PATH = REPOSITORY_ROOT.join("Aven.xcodeproj")
PROJECT_NAME = "Aven"
OBJECT_VERSION = 77
TOOLS_VERSION = "27.0"
DEPLOYMENT_TARGET = "26.0"
FIREBASE_PACKAGE_URL = "https://github.com/firebase/firebase-ios-sdk.git"
FIREBASE_PACKAGE_VERSION = "12.16.0"
FIREBASE_PRODUCTS = %w[
  FirebaseCore
  FirebaseAuth
  FirebaseFirestore
  FirebaseStorage
  FirebaseFunctions
  FirebaseRemoteConfig
  FirebaseAppCheck
  FirebaseMessaging
  FirebaseAnalytics
].freeze

CONFIGURATION_FILES = {
  "Debug" => "Development.xcconfig",
  "Staging" => "Staging.xcconfig",
  "Release" => "Production.xcconfig",
}.freeze

CONFIGURATION_TYPES = {
  "Debug" => :debug,
  "Staging" => :release,
  "Release" => :release,
}.freeze

def add_synchronized_group(project, path, *targets)
  group = project.new(
    Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup,
  )
  group.path = path
  group.source_tree = "<group>"
  group.explicit_file_types = {}
  group.explicit_folders = []

  project.main_group.children << group
  targets.each do |target|
    target.file_system_synchronized_groups << group
  end
  group
end

def ensure_configurations(owner)
  CONFIGURATION_FILES.each_key do |name|
    next if owner.build_configurations.any? { |configuration| configuration.name == name }

    owner.add_build_configuration(name, CONFIGURATION_TYPES.fetch(name))
  end
end

def configure_target(target, configuration_references, settings)
  ensure_configurations(target)

  target.build_configurations.each do |configuration|
    configuration.base_configuration_reference =
      configuration_references.fetch(configuration.name)
    configuration.build_settings = settings.dup
  end
end

def add_target_dependency(source_target, destination_target)
  source_target.add_dependency(destination_target)
  source_target.dependencies.find do |candidate|
    candidate.target == destination_target
  end
end

def assign_stable_uuid(project, object, label)
  uuid = Digest::MD5.hexdigest("#{PROJECT_NAME}.xcodeproj/#{label}").upcase
  existing = project.objects_by_uuid[uuid]
  abort "Stable UUID collision for #{label}" if existing && existing != object

  project.objects_by_uuid.delete(object.uuid)
  object.instance_variable_set(:@uuid, uuid)
  project.objects_by_uuid[uuid] = object
end

def write_scheme(
  project_path,
  name,
  app_target,
  unit_test_target,
  ui_test_target,
  run_configuration,
  archive_configuration
)
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(app_target, unit_test_target, launch_target: true)
  scheme.add_build_target(ui_test_target, false)
  scheme.add_test_target(ui_test_target)

  scheme.test_action.build_configuration = run_configuration
  scheme.launch_action.build_configuration = run_configuration
  scheme.analyze_action.build_configuration = run_configuration
  scheme.profile_action.build_configuration = archive_configuration
  scheme.archive_action.build_configuration = archive_configuration
  scheme.save_as(project_path, name, true)
end

unless PROJECT_PATH.basename.to_s == "#{PROJECT_NAME}.xcodeproj" &&
       PROJECT_PATH.parent == REPOSITORY_ROOT
  abort "Refusing to replace an unexpected project path: #{PROJECT_PATH}"
end

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH, false, OBJECT_VERSION)
project.root_object.compatibility_version = "Xcode 16.0"
project.root_object.preferred_project_object_version = OBJECT_VERSION.to_s
project.root_object.development_region = "en"
project.root_object.has_scanned_for_encodings = "0"
project.root_object.known_regions.clear
project.root_object.known_regions.concat(%w[en uk Base])
project.root_object.attributes = {
  "BuildIndependentTargetsInParallel" => "1",
  "LastSwiftUpdateCheck" => "2700",
  "LastUpgradeCheck" => "2700",
}

config_group = project.main_group.new_group("Config", "Config")
configuration_references = CONFIGURATION_FILES.transform_values do |filename|
  config_group.new_file(filename)
end
config_group.new_file("Common.xcconfig")
config_group.new_file("Secrets.xcconfig.example")
config_group.new_file("README.md")

ensure_configurations(project)
project.build_configurations.each do |configuration|
  configuration.base_configuration_reference =
    configuration_references.fetch(configuration.name)
  configuration.build_settings = {}
end

app_target = project.new_target(
  :application,
  PROJECT_NAME,
  :ios,
  DEPLOYMENT_TARGET,
  nil,
  :swift,
)
widget_target = project.new_target(
  :app_extension,
  "AvenWidgets",
  :ios,
  DEPLOYMENT_TARGET,
  nil,
  :swift,
)
unit_test_target = project.new_target(
  :unit_test_bundle,
  "AvenTests",
  :ios,
  DEPLOYMENT_TARGET,
  nil,
  :swift,
)
ui_test_target = project.new_target(
  :ui_test_bundle,
  "AvenUITests",
  :ios,
  DEPLOYMENT_TARGET,
  nil,
  :swift,
)

app_group = add_synchronized_group(project, "Aven", app_target)
add_synchronized_group(project, "AvenIntents", app_target, widget_target)
widget_group = project.main_group.new_group("AvenWidgets", "AvenWidgets")
widget_source = widget_group.new_file("AvenPrivacyWidget.swift")
widget_target.source_build_phase.add_file_reference(widget_source, true)
widget_privacy_manifest = widget_group.new_file("PrivacyInfo.xcprivacy")
widget_target.resources_build_phase.add_file_reference(
  widget_privacy_manifest,
  true,
)
widget_group.new_file("Info.plist")
widget_group.new_file("AvenWidgets.entitlements")
add_synchronized_group(project, "AvenTests", unit_test_target)
add_synchronized_group(project, "AvenUITests", ui_test_target)

firebase_config_reference = project.main_group.new_file(
  "Aven/Resources/GoogleService-Info.plist",
)
firebase_config_build_file =
  app_target.resources_build_phase.add_file_reference(
    firebase_config_reference,
    true,
  )

firebase_package = project.new(
  Xcodeproj::Project::Object::XCRemoteSwiftPackageReference,
)
firebase_package.repositoryURL = FIREBASE_PACKAGE_URL
firebase_package.requirement = {
  "kind" => "exactVersion",
  "version" => FIREBASE_PACKAGE_VERSION,
}
project.root_object.package_references << firebase_package

firebase_product_dependencies = FIREBASE_PRODUCTS.to_h do |product_name|
  dependency = project.new(
    Xcodeproj::Project::Object::XCSwiftPackageProductDependency,
  )
  dependency.package = firebase_package
  dependency.product_name = product_name
  app_target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  app_target.frameworks_build_phase.files << build_file

  [product_name, [dependency, build_file]]
end

widget_dependency = add_target_dependency(app_target, widget_target)
unit_test_dependency = add_target_dependency(unit_test_target, app_target)
ui_test_dependency = add_target_dependency(ui_test_target, app_target)

app_settings = {
  "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
  "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME" => "AccentColor",
  "CODE_SIGN_ENTITLEMENTS" => "Aven/Aven.entitlements",
  "DEVELOPMENT_TEAM" => "",
  "EMBEDDED_CONTENT_CONTAINS_SWIFT" => "YES",
  "GENERATE_INFOPLIST_FILE" => "YES",
  "INFOPLIST_KEY_CFBundleDisplayName" => "$(AVEN_DISPLAY_NAME)",
  "INFOPLIST_KEY_AvenEnvironment" => "$(AVEN_ENVIRONMENT)",
  "INFOPLIST_KEY_AvenExpectedFirebaseProjectID" =>
    "$(AVEN_FIREBASE_PROJECT_ID)",
  "INFOPLIST_KEY_LSApplicationCategoryType" => "public.app-category.lifestyle",
  "INFOPLIST_KEY_LSRequiresIPhoneOS" => "YES",
  # Base usage descriptions are localized by Aven/Resources/InfoPlist.xcstrings.
  "INFOPLIST_KEY_NSCalendarsWriteOnlyAccessUsageDescription" =>
    "Aven can add plans you explicitly choose to your selected calendar.",
  "INFOPLIST_KEY_NSCameraUsageDescription" =>
    "Aven uses the camera only to scan your partner's private pairing QR code.",
  "INFOPLIST_KEY_NSFaceIDUsageDescription" =>
    "Use Face ID to protect private relationship content in Aven.",
  "INFOPLIST_KEY_NSLocationWhenInUseUsageDescription" =>
    "Aven uses location only for moments you explicitly choose to share.",
  "INFOPLIST_KEY_NSMicrophoneUsageDescription" =>
    "Aven uses the microphone when you choose to record a voice message or journal.",
  "INFOPLIST_KEY_NSPhotoLibraryUsageDescription" =>
    "Choose individual photos and videos to add to your shared memories.",
  "INFOPLIST_KEY_UIApplicationSceneManifest_Generation" => "YES",
  "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents" => "YES",
  "INFOPLIST_KEY_UILaunchScreen_Generation" => "YES",
  "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone" =>
    "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
  "LD_RUNPATH_SEARCH_PATHS" => "$(inherited) @executable_path/Frameworks",
  "PRODUCT_BUNDLE_IDENTIFIER" => "$(AVEN_BUNDLE_IDENTIFIER)",
  "PRODUCT_NAME" => "$(TARGET_NAME)",
  "SKIP_INSTALL" => "NO",
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "$(inherited) AVEN_APP_TARGET",
  "TARGETED_DEVICE_FAMILY" => "1",
}

widget_settings = {
  "APPLICATION_EXTENSION_API_ONLY" => "YES",
  "CODE_SIGN_ENTITLEMENTS" => "AvenWidgets/AvenWidgets.entitlements",
  "DEVELOPMENT_TEAM" => "",
  "GENERATE_INFOPLIST_FILE" => "NO",
  "INFOPLIST_FILE" => "AvenWidgets/Info.plist",
  "LD_RUNPATH_SEARCH_PATHS" =>
    "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
  "PRODUCT_BUNDLE_IDENTIFIER" => "$(AVEN_BUNDLE_IDENTIFIER).widgets",
  "PRODUCT_NAME" => "$(TARGET_NAME)",
  "SKIP_INSTALL" => "YES",
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS" =>
    "$(inherited) AVEN_WIDGET_EXTENSION",
  "TARGETED_DEVICE_FAMILY" => "1",
}

unit_test_settings = {
  "BUNDLE_LOADER" => "$(TEST_HOST)",
  "GENERATE_INFOPLIST_FILE" => "YES",
  "PRODUCT_BUNDLE_IDENTIFIER" => "$(AVEN_BUNDLE_IDENTIFIER).tests",
  "PRODUCT_NAME" => "$(TARGET_NAME)",
  "SKIP_INSTALL" => "YES",
  "TARGETED_DEVICE_FAMILY" => "1",
  "TEST_HOST" =>
    "$(BUILT_PRODUCTS_DIR)/Aven.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Aven",
}

ui_test_settings = {
  "GENERATE_INFOPLIST_FILE" => "YES",
  "PRODUCT_BUNDLE_IDENTIFIER" => "$(AVEN_BUNDLE_IDENTIFIER).uitests",
  "PRODUCT_NAME" => "$(TARGET_NAME)",
  "SKIP_INSTALL" => "YES",
  "TARGETED_DEVICE_FAMILY" => "1",
  "TEST_TARGET_NAME" => PROJECT_NAME,
}

configure_target(app_target, configuration_references, app_settings)
configure_target(widget_target, configuration_references, widget_settings)
configure_target(unit_test_target, configuration_references, unit_test_settings)
configure_target(ui_test_target, configuration_references, ui_test_settings)

embed_extensions_phase = app_target.new_copy_files_build_phase("Embed App Extensions")
embed_extensions_phase.symbol_dst_subfolder_spec = :plug_ins
widget_build_file = embed_extensions_phase.add_file_reference(
  widget_target.product_reference,
  true,
)
widget_build_file.settings = {
  "ATTRIBUTES" => %w[CodeSignOnCopy RemoveHeadersOnCopy],
}

project.sort
[project, app_target, widget_target, unit_test_target, ui_test_target].each do |owner|
  owner.build_configuration_list.build_configurations.sort_by! do |configuration|
    CONFIGURATION_FILES.keys.index(configuration.name)
  end
end
project.predictabilize_uuids

# A local Firebase plist is intentionally ignored by Git. Xcode's synchronized
# groups otherwise add every file automatically, so exclude it from implicit
# membership and rely on the explicit resource reference above. Attach the
# target-referencing exception after xcodeproj's recursive sort/UUID passes to
# avoid a cycle in xcodeproj 1.27.
firebase_membership_exceptions = project.new(
  Xcodeproj::Project::Object::PBXFileSystemSynchronizedBuildFileExceptionSet,
)
firebase_membership_exceptions.target = app_target
firebase_membership_exceptions.membership_exceptions = [
  "Resources/GoogleService-Info.plist",
]
app_group.exceptions << firebase_membership_exceptions

[
  [project, "Project"],
  [app_target, "Aven"],
  [widget_target, "AvenWidgets"],
  [unit_test_target, "AvenTests"],
  [ui_test_target, "AvenUITests"],
].each do |owner, label|
  unless owner == project
    assign_stable_uuid(project, owner, "#{label}/PBXNativeTarget")
    assign_stable_uuid(
      project,
      owner.product_reference,
      "#{label}/PBXFileReference/Product",
    )

    owner.build_phases.each do |phase|
      phase_label = phase.display_name
      assign_stable_uuid(
        project,
        phase,
        "#{label}/#{phase.isa}/#{phase_label}",
      )
      phase.files.each_with_index do |build_file, index|
        file_label =
          build_file.file_ref&.path ||
          build_file.product_ref&.display_name ||
          index.to_s
        assign_stable_uuid(
          project,
          build_file,
          "#{label}/#{phase.isa}/#{phase_label}/#{file_label}/#{index}",
        )
      end
    end
  end

  assign_stable_uuid(
    project,
    owner.build_configuration_list,
    "#{label}/XCConfigurationList",
  )
  owner.build_configurations.each do |configuration|
    assign_stable_uuid(
      project,
      configuration,
      "#{label}/XCBuildConfiguration/#{configuration.name}",
    )
  end
end

{
  widget_dependency =>
    "Aven/PBXTargetDependency/AvenWidgets",
  widget_dependency.target_proxy =>
    "Aven/PBXContainerItemProxy/AvenWidgets",
  unit_test_dependency =>
    "AvenTests/PBXTargetDependency/Aven",
  unit_test_dependency.target_proxy =>
    "AvenTests/PBXContainerItemProxy/Aven",
  ui_test_dependency =>
    "AvenUITests/PBXTargetDependency/Aven",
  ui_test_dependency.target_proxy =>
    "AvenUITests/PBXContainerItemProxy/Aven",
}.each do |object, label|
  assign_stable_uuid(project, object, label)
end
assign_stable_uuid(
  project,
  firebase_membership_exceptions,
  "Aven/PBXFileSystemSynchronizedBuildFileExceptionSet/FirebaseConfig",
)
assign_stable_uuid(
  project,
  firebase_config_reference,
  "Aven/PBXFileReference/GoogleService-Info.plist",
)
assign_stable_uuid(
  project,
  firebase_config_build_file,
  "Aven/PBXResourcesBuildPhase/GoogleService-Info.plist",
)
assign_stable_uuid(
  project,
  firebase_package,
  "Project/XCRemoteSwiftPackageReference/firebase-ios-sdk",
)
firebase_product_dependencies.each do |product_name, objects|
  dependency, build_file = objects
  assign_stable_uuid(
    project,
    dependency,
    "Aven/XCSwiftPackageProductDependency/#{product_name}",
  )
  assign_stable_uuid(
    project,
    build_file,
    "Aven/PBXFrameworksBuildPhase/#{product_name}",
  )
end
widget_dependency.target_proxy.remote_global_id_string = widget_target.uuid
unit_test_dependency.target_proxy.remote_global_id_string = app_target.uuid
ui_test_dependency.target_proxy.remote_global_id_string = app_target.uuid

project.root_object.attributes["TargetAttributes"] = {
  app_target.uuid => {
    "CreatedOnToolsVersion" => TOOLS_VERSION,
  },
  widget_target.uuid => {
    "CreatedOnToolsVersion" => TOOLS_VERSION,
  },
  unit_test_target.uuid => {
    "CreatedOnToolsVersion" => TOOLS_VERSION,
    "TestTargetID" => app_target.uuid,
  },
  ui_test_target.uuid => {
    "CreatedOnToolsVersion" => TOOLS_VERSION,
    "TestTargetID" => app_target.uuid,
  },
}
project.save

write_scheme(
  PROJECT_PATH,
  "Aven",
  app_target,
  unit_test_target,
  ui_test_target,
  "Debug",
  "Release",
)
write_scheme(
  PROJECT_PATH,
  "Aven-Staging",
  app_target,
  unit_test_target,
  ui_test_target,
  "Staging",
  "Staging",
)

puts "Generated #{PROJECT_PATH}"
