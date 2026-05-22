Pod::Spec.new do |s|
  s.name             = 'SimulaMiniGameSDK'
  s.version          = '0.1.0'
  s.summary          = 'Simula native mini-game Swift SDK'
  s.description      = <<-DESC
    SwiftUI MiniGameMenu + MiniGameProvider for RN bridging (Swift Package sources copied as pod source).
  DESC
  s.homepage         = 'https://github.com/Simula-AI-SDK'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Simula' => 'dev@simula.ai' }
  s.platform         = :ios, '16.0'
  s.swift_versions   = ['5.9']

  # When installed via `:path` to repo root, this resolves to monorepo root.
  s.source           = { :path => '.' }
  s.source_files     = 'Sources/SimulaMiniGameSDK/**/*.{swift}'
  s.exclude_files    = 'Sources/SimulaMiniGameSDK/Demo/**/*'

  s.requires_arc     = true
  s.module_name      = 'SimulaMiniGameSDK'
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
end
