platform :ios, '10.0'
inhibit_all_warnings!

def common_pods
  pod 'SwiftLint', '~> 0.24'
end

target 'spaceTube' do
  use_frameworks!
  common_pods

  target 'spaceTubeTests' do
    inherit! :search_paths

  end
end