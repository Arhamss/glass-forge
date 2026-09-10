#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint glass_forge_platform.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'glass_forge_platform'
  s.version          = '0.0.1'
  s.summary          = 'Native accessibility and thermal signals for glass_forge — Reduce Transparency, thermal status, low-power mode.'
  s.description      = <<-DESC
Native accessibility and thermal signals for glass_forge — Reduce Transparency, thermal status, low-power mode.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'glass_forge_platform/Sources/glass_forge_platform/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'glass_forge_platform_privacy' => ['glass_forge_platform/Sources/glass_forge_platform/PrivacyInfo.xcprivacy']}
end
