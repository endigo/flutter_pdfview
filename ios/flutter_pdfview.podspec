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
  s.source_files = 'flutter_pdfview/Sources/flutter_pdfview/**/*.{h,m}'
  s.public_header_files = 'flutter_pdfview/Sources/flutter_pdfview/include/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS' => 'armv7 arm64 x86_64' }
end

