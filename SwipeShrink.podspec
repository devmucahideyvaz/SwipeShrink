Pod::Spec.new do |s|
  s.name             = 'SwipeShrink'
  s.version          = '1.0.0'
  s.summary          = 'Swipe to shrink a view like the YouTube video player.'
  s.description      = <<-DESC
    SwipeShrink drives a swipe-down-to-shrink transition on any UIView, moving it
    between a full-size resting position and a mini player docked in the
    bottom-trailing corner, with a tap to restore it.
  DESC
  s.homepage         = 'https://github.com/devmucahideyvaz/SwipeShrink'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Mücahid Eyvaz' => 'mchd.eyvz@gmail.com' }
  s.source           = { :git => 'https://github.com/devmucahideyvaz/SwipeShrink.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.swift_versions   = ['6.0']
  s.source_files     = 'Sources/SwipeShrink/**/*.swift'
  s.frameworks       = 'UIKit'
end
