Pod::Spec.new do |s|
  s.name             = 'SimulaAdBridge'
  s.version          = '0.1.0'
  s.summary          = 'React Native native module bridging SimulaMiniGame SDK'
  s.homepage         = 'https://github.com/Simula-AI-SDK'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Simula' => 'dev@simula.ai' }
  s.platform         = :ios, '16.0'
  s.swift_versions   = ['5.0']

  s.source           = { :path => '.' }
  s.source_files     = 'Bridge/**/*.{swift,m,mm}'
  s.requires_arc     = true

  # Swift static pod — matches default React-Core static linkage in this template.
  s.static_framework = true

  s.dependency 'React-Core'
  s.dependency 'SimulaMiniGameSDK'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
  }
end
