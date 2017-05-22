Pod::Spec.new do |s|
  s.name         = "Einlass"
  s.version      = "1.0.0"
  s.summary      = "One click user authentication solution via iOS social media system accounts. (Twitter & Facebook)"
  s.authors      = "Markus Wanke"
  s.homepage     = "https://github.com/mw99/Einlass"
  s.license      = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.source       = { :git => "https://github.com/mw99/Einlass.git", :tag => s.version }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.dependency 'OhhAuth', '~> 1.0'

  s.source_files = 'Sources/*.swift'
end
