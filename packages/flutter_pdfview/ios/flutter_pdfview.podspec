#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_pdfview'
  s.version          = '1.0.2'
  s.summary          = 'Flutter plugin that display a pdf using PDFkit.'
  s.description      = <<-DESC
  A Flutter plugin for display pdf from the library as well as from url
  Downloaded by pub (not CocoaPods).
                       DESC
  s.homepage         = 'https://github.com/endigo/flutter_pdfview'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'endigo' => 'endigo.18@gmail.com' }
  s.source           = { :http => 'https://github.com/endigo/flutter_pdfview' }
  s.documentation_url = 'https://pub.dev/packages/flutter_pdfview'
  # CocoaPods, unlike SwiftPM, allows one target to mix Swift with the small
  # Objective-C exception shim, so both source trees compile into this pod.
  s.source_files = 'flutter_pdfview/Sources/flutter_pdfview/**/*.swift',
                   'flutter_pdfview/Sources/flutter_pdfview_objc/**/*.{h,m}'
  s.public_header_files = 'flutter_pdfview/Sources/flutter_pdfview_objc/include/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS' => 'armv7 arm64 x86_64' }
  s.resource_bundles = { 'flutter_pdfview_privacy' => ['flutter_pdfview/Sources/flutter_pdfview/PrivacyInfo.xcprivacy'] }
end

