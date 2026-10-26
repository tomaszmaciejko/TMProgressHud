Pod::Spec.new do |s|
  s.name = 'TMProgressHudUIKit'
  s.version = File.read(File.join(__dir__, 'VERSION')).strip
  s.summary = 'Native Swift progress and status HUD for UIKit on iOS and tvOS.'
  s.description = 'A Swift UIKit HUD with progress indicators, custom content, action buttons and configurable presentation.'
  s.homepage = 'https://github.com/tomaszmaciejko/TMProgressHud'
  s.author = 'Tomasz Maciejko'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.source = { :git => 'https://github.com/tomaszmaciejko/TMProgressHud.git', :tag => "v#{s.version}" }
  s.module_name = 'TMProgressHudUIKit'
  s.swift_versions = ['6.0']
  s.cocoapods_version = '>= 1.16'
  s.ios.deployment_target = '17.0'
  s.tvos.deployment_target = '17.0'
  s.source_files = 'Sources/TMProgressHudUIKit/*.swift'
  s.resource_bundles = { 'TMProgressHudUIKit' => ['Sources/TMProgressHudUIKit/PrivacyInfo.xcprivacy', 'Sources/TMProgressHudUIKit/Resources/*'] }
  s.preserve_paths = 'LICENSE', 'THIRD_PARTY_NOTICES.md'
  s.frameworks = 'UIKit', 'Foundation', 'CoreGraphics', 'QuartzCore'
end
