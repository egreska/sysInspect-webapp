# Podfile for Systems Inspector
# Firebase Analytics and Crashlytics Integration

platform :ios, '14.0'

target 'Systems Inspector' do
  use_frameworks!

  # Firebase Analytics and Crashlytics
  pod 'Firebase/Analytics'
  pod 'Firebase/Crashlytics'
  
  # Optional: Additional Firebase features
  # pod 'Firebase/Performance'  # Performance monitoring
  # pod 'Firebase/RemoteConfig'  # Remote configuration
  # pod 'Firebase/Messaging'     # Push notifications

end

target 'Systems InspectorTests' do
  inherit! :search_paths
  # Pods for testing
end

target 'Systems InspectorUITests' do
  # Pods for UI testing
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
