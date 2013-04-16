Pod::Spec.new do |s|
  s.name         = "AttributedMarkdown"
  s.version      = "0.9.0"
  s.summary      = "A short description of AttributedMarkdown."
  s.homepage     = "https://github.com/dreamwieber/AttributedMarkdown"
  s.screenshots  = "http://gregorywieber.com/work/attributed_markdown.html"
  s.license      = { :type => 'MIT / GPL', :file => 'LICENSE' }
  s.author       = 'Gregory Wieber', 'Jim Radford'
  s.source       = { :git => "https://github.com/dreamwieber/AttributedMarkdown", :tag => "0.9.0" }
  s.platform     = :ios
  s.source_files = '*.{h,m}'
  s.ios.exclude_files = 'parsing_functions.m', 'utility_functions.m'
  s.public_header_files = '*.h'
  s.frameworks = 'CoreText', 'UIKit', 'Foundation'
end
