# Podfile for Systems Inspector
# Firebase Analytics and Crashlytics Integration

platform :ios, '15.0'

target 'Systems Inspector' do
  use_frameworks!

  # Firebase Analytics and Crashlytics
  pod 'Firebase/Analytics'
  # Inhibit Clang VLA-folded warnings in FIRCLS*.m (Firebase SDK source, not app code).
  pod 'Firebase/Crashlytics', :inhibit_warnings => true
  
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
  # xcodeproj supports object version up to 77. There is no object_version= setter; pin before save.
  installer.pods_project.instance_variable_set(:@object_version, '77')
  pods_root_obj = installer.pods_project.root_object
  pods_root_obj.preferred_project_object_version = '77'
  pods_root_obj.compatibility_version = Xcodeproj::Constants::COMPATIBILITY_VERSION_BY_OBJECT_VERSION[77]

  quoted_include_suppression = '-Wno-quoted-include-in-framework-header'

  # Reduce Xcode 'Update to recommended settings' on Pods.xcodeproj (bump Last* if Xcode nags after upgrade).
  installer.pods_project.root_object.attributes['LastUpgradeCheck'] = '2640'
  installer.pods_project.root_object.attributes['LastSwiftUpdateCheck'] = '2640'

  dedupe_ldflags = lambda do |config|
    ld = config.build_settings['OTHER_LDFLAGS']
    if ld.is_a?(Array)
      config.build_settings['OTHER_LDFLAGS'] = ld.uniq
    elsif ld.is_a?(String)
      config.build_settings['OTHER_LDFLAGS'] = ld.split(/\s+/).uniq.join(' ')
    end
  end

  # Pods project defaults set CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES (Xcode 15+).
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    dedupe_ldflags.call(config)
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Xcode 27 supports 15.0–27.0 only; 14.0 is a hard error, not a warning.
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      # Clang/Swift explicit modules scan Firebase.h before pod frameworks exist.
      config.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'NO'
      config.build_settings['CLANG_ENABLE_EXPLICIT_MODULES'] = 'NO'

      # Xcode's Module Verifier still validates framework headers with strict rules; Firebase/Google
      # pods use quoted includes in umbrellas. Disabling avoids verifier failures independent of CLANG_WARN_*.
      config.build_settings['ENABLE_MODULE_VERIFIER'] = 'NO'

      # FIRCLSFile.m / FIRCLSUUID.m: VLA-folded warnings (third-party SDK).
      if target.name == 'FirebaseCrashlytics'
        config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
      end

      # Explicit suppression for any compile path (verifier, indexer, or future defaults).
      %w[OTHER_CFLAGS OTHER_CPLUSPLUSFLAGS].each do |key|
        val = config.build_settings[key]
        if val.nil?
          config.build_settings[key] = "$(inherited) #{quoted_include_suppression}"
        elsif val.is_a?(Array)
          unless val.any? { |f| f.to_s.include?('quoted-include') }
            config.build_settings[key] = val + [quoted_include_suppression]
          end
        else
          s = val.to_s
          config.build_settings[key] = "#{s} #{quoted_include_suppression}" unless s.include?('quoted-include')
        end
      end

      dedupe_ldflags.call(config)
    end
  end

  # Some Xcode versions still diagnose quoted #imports in pod framework headers even with
  # CLANG_WARN_* / -Wno* / module verifier off. Rewrite to framework-style includes after CocoaPods
  # finishes generating the Pods project (re-run on every `pod install`).
  pods_root = installer.sandbox.root.to_s

  make_writable = lambda do |path|
    File.chmod(File.stat(path).mode | 0o200, path)
  rescue StandardError
    nil
  end

  gdt_public = File.join(pods_root, 'GoogleDataTransport/GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport')
  if Dir.exist?(gdt_public)
    Dir.glob(File.join(gdt_public, '*.h')).each do |path|
      text = File.read(path)
      patched = text.gsub(/^(#(?:import|include))\s+"((?:GDTCOR\w+|GoogleDataTransport)\.h)"/) { "#{$1} <GoogleDataTransport/#{$2}>" }
      next if patched == text

      make_writable.call(path)
      File.write(path, patched)
    end
  end

  gdt_umbrella = File.join(pods_root, 'Target Support Files/GoogleDataTransport/GoogleDataTransport-umbrella.h')
  if File.exist?(gdt_umbrella)
    text = File.read(gdt_umbrella)
    patched = text.gsub(/^(#(?:import|include))\s+"((?:GDTCOR\w+|GoogleDataTransport)\.h)"/) { "#{$1} <GoogleDataTransport/#{$2}>" }
    if patched != text
      make_writable.call(gdt_umbrella)
      File.write(gdt_umbrella, patched)
    end
  end

  nanopb_dir = File.join(pods_root, 'nanopb')
  if Dir.exist?(nanopb_dir)
    %w[pb_common.h pb_decode.h pb_encode.h].each do |name|
      path = File.join(nanopb_dir, name)
      next unless File.exist?(path)

      text = File.read(path)
      patched = text.gsub(/^(#include)\s+"(pb\.h)"/) { "#{$1} <nanopb/#{$2}>" }
      next if patched == text

      make_writable.call(path)
      File.write(path, patched)
    end

    nb_umbrella = File.join(pods_root, 'Target Support Files/nanopb/nanopb-umbrella.h')
    if File.exist?(nb_umbrella)
      text = File.read(nb_umbrella)
      patched = text.gsub(/^(#import)\s+"(pb(?:_[a-z]+)?\.h)"/) { "#{$1} <nanopb/#{$2}>" }
      if patched != text
        make_writable.call(nb_umbrella)
        File.write(nb_umbrella, patched)
      end
    end
  end

  # FirebaseCore — public headers + umbrella (module name FirebaseCore).
  fc_public = File.join(pods_root, 'FirebaseCore/FirebaseCore/Sources/Public/FirebaseCore')
  if Dir.exist?(fc_public)
    Dir.glob(File.join(fc_public, '*.h')).each do |path|
      text = File.read(path)
      patched = text.gsub(/^(#(?:import|include))\s+"((?:FIR\w+|FirebaseCore)\.h)"/) { "#{$1} <FirebaseCore/#{$2}>" }
      next if patched == text

      make_writable.call(path)
      File.write(path, patched)
    end
  end

  fc_umbrella = File.join(pods_root, 'Target Support Files/FirebaseCore/FirebaseCore-umbrella.h')
  if File.exist?(fc_umbrella)
    text = File.read(fc_umbrella)
    patched = text.gsub(/^(#(?:import|include))\s+"((?:FIR\w+|FirebaseCore)\.h)"/) { "#{$1} <FirebaseCore/#{$2}>" }
    if patched != text
      make_writable.call(fc_umbrella)
      File.write(fc_umbrella, patched)
    end
  end

  # PromisesObjC — framework module is FBLPromises (see PromisesObjC.modulemap).
  fbl_include = File.join(pods_root, 'PromisesObjC/Sources/FBLPromises/include')
  if Dir.exist?(fbl_include)
    Dir.glob(File.join(fbl_include, '*.h')).each do |path|
      text = File.read(path)
      patched = text.gsub(/^(#(?:import|include))\s+"(FBL[^"]+\.h)"/) { "#{$1} <FBLPromises/#{$2}>" }
      next if patched == text

      make_writable.call(path)
      File.write(path, patched)
    end
  end

  po_umbrella = File.join(pods_root, 'Target Support Files/PromisesObjC/PromisesObjC-umbrella.h')
  if File.exist?(po_umbrella)
    text = File.read(po_umbrella)
    patched = text.gsub(/^(#(?:import|include))\s+"(FBL[^"]+\.h)"/) { "#{$1} <FBLPromises/#{$2}>" }
    if patched != text
      make_writable.call(po_umbrella)
      File.write(po_umbrella, patched)
    end
  end

  # Xcode 26 sets TOOLCHAIN_DIR to the Metal shader toolchain, which has no Swift stdlib
  # (usr/lib/swift/iphoneos). CocoaPods still injects that path into LIBRARY_SEARCH_PATHS,
  # producing ld "search path ... not found" warnings. Point at XcodeDefault via DEVELOPER_DIR instead.
  Dir.glob(File.join(pods_root, 'Target Support Files', '**', '*.xcconfig')).each do |path|
    text = File.read(path)
    patched = text.gsub(
      '"${TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"',
      '"${DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/${PLATFORM_NAME}"'
    )
    next if patched == text

    make_writable.call(path)
    File.write(path, patched)
  end

  # Clang explicit-module scanning resolves <FirebaseCore/FirebaseCore.h> from source, not
  # only from the built framework (which does not exist yet during the scan).
  Dir.glob(File.join(pods_root, 'Target Support Files', 'Pods-Systems Inspector', '*.xcconfig')).each do |path|
    text = File.read(path)
    extras = [
      '"${PODS_ROOT}/FirebaseCore/FirebaseCore/Sources/Public"',
      '"${PODS_ROOT}/FirebaseCrashlytics/Crashlytics/Crashlytics/Public"'
    ]
    extras.each do |extra|
      next if text.include?(extra)
      text = text.sub(/^(HEADER_SEARCH_PATHS = .*)$/, "\\1 #{extra}")
    end
    next if text == File.read(path)

    make_writable.call(path)
    File.write(path, text)
  end

  # FirebaseCrashlytics lists -lc++ in OTHER_LDFLAGS and also compiles C++ sources, so the
  # driver passes -lc++ twice. Xcode 15+ ld warns "Ignoring duplicate libraries: '-lc++'".
  Dir.glob(File.join(pods_root, 'Target Support Files', 'FirebaseCrashlytics', '*.xcconfig')).each do |path|
    text = File.read(path)
    next if text.include?('-no_warn_duplicate_libraries')
    next unless text.include?('OTHER_LDFLAGS')

    patched = text.sub(/^(OTHER_LDFLAGS = .*)$/, '\1 -Wl,-no_warn_duplicate_libraries')
    next if patched == text

    make_writable.call(path)
    File.write(path, patched)
  end
end
