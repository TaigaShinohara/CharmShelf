#!/usr/bin/env ruby
# Load the known Fastfile through the real Fastlane DSL and action definitions.
# No lane is run. The Ruby API guards below catch common process/socket calls
# during this check; they are not an OS sandbox for arbitrary or hostile code.
require "socket"
require "open3"

ENV["FASTLANE_SKIP_UPDATE_CHECK"] = "1"
ENV["FASTLANE_HIDE_CHANGELOG"] = "1"
ENV["FASTLANE_OPT_OUT_USAGE"] = "1"
ENV["FASTLANE_DISABLE_COLORS"] = "1"

module OfflineDefinitionCheck
  ATTEMPTS = []

  def self.reject(kind)
    origins = caller_locations(2, 12).map { |origin| "#{File.basename(origin.path)}:#{origin.lineno}" }
    ATTEMPTS << "#{kind} at #{origins.join(' <- ')}"
    raise "Offline Fastlane definition check forbids #{kind}"
  end
end

module NoDefinitionProcesses
  def system(*) = OfflineDefinitionCheck.reject("child process")
  def exec(*) = OfflineDefinitionCheck.reject("child process")
  def spawn(*) = OfflineDefinitionCheck.reject("child process")
  def fork(*) = OfflineDefinitionCheck.reject("child process")
  define_method(:`) { |*| OfflineDefinitionCheck.reject("child process") }
end

module NoDefinitionSockets
  def connect(*) = OfflineDefinitionCheck.reject("network")
  def connect_nonblock(*) = OfflineDefinitionCheck.reject("network")
end

Kernel.prepend(NoDefinitionProcesses)
Process.singleton_class.prepend(Module.new do
  def spawn(*) = OfflineDefinitionCheck.reject("child process")
  def fork(*) = OfflineDefinitionCheck.reject("child process")
end)
Socket.prepend(NoDefinitionSockets)
Socket.singleton_class.prepend(Module.new do
  def tcp(*) = OfflineDefinitionCheck.reject("network")
end)
TCPSocket.singleton_class.prepend(Module.new do
  def new(*) = OfflineDefinitionCheck.reject("network")
  def open(*) = OfflineDefinitionCheck.reject("network")
end)
UDPSocket.prepend(NoDefinitionSockets)

require "bundler/setup"
# google-apis-core queries the OS version at require-time. Its value is only
# HTTP user-agent metadata; use Ruby's platform here so even that probe stays
# inside this process. Other calls through the guarded APIs still fail below.
module DefinitionOsMetadata
  def capture2(*arguments, **options, &block)
    if OfflineDefinitionCheck.const_defined?(:LOADING_GOOGLE_APIS) &&
       OfflineDefinitionCheck::LOADING_GOOGLE_APIS &&
       [%w[sw_vers -productVersion], %w[uname -sr], %w[ver]].include?(arguments)
      return [RUBY_PLATFORM, nil]
    end
    super
  end
end
Open3.singleton_class.prepend(DefinitionOsMetadata)
OfflineDefinitionCheck::LOADING_GOOGLE_APIS = true
require "google/apis"
OfflineDefinitionCheck.send(:remove_const, :LOADING_GOOGLE_APIS)
require "fastlane"
require "fastlane/actions/default_platform"

root = File.expand_path("..", __dir__)
expected_ruby = File.read(File.join(root, ".ruby-version")).strip
raise "Unexpected Ruby runtime" unless RUBY_VERSION == expected_ruby
expected_fastlane = File.read(File.join(root, "Gemfile")).match(/gem "fastlane", "([^"]+)"/)[1]
raise "Unexpected Fastlane runtime" unless Fastlane::VERSION == expected_fastlane

definition = Fastlane::FastFile.new
definition.parse(File.read(File.join(root, "fastlane/Fastfile")), File.join(root, "fastlane/Fastfile"))
expected_lanes = { android: %i[internal beta release firebase], ios: %i[beta release firebase] }
actual_lanes = definition.runner.lanes.transform_values { |lanes| lanes.keys.sort }
raise "Unexpected Fastlane lanes" unless actual_lanes == expected_lanes.transform_values(&:sort)

{
  "upload_to_play_store" => %i[json_key package_name track aab],
  "upload_to_testflight" => %i[api_key ipa app_identifier skip_waiting_for_build_processing localized_build_info],
  "upload_to_app_store" => %i[api_key ipa app_identifier skip_metadata skip_screenshots submit_for_review automatic_release],
  "app_store_connect_api_key" => %i[key_id issuer_id key_content is_key_content_base64],
  "latest_testflight_build_number" => %i[api_key app_identifier initial_build_number],
}.each do |name, used_options|
  require "fastlane/actions/#{name}"
  action = Fastlane::Actions.const_get(name.split("_").map(&:capitalize).join + "Action")
  supported = action.available_options.map(&:key)
  raise "Unsupported #{name} options" unless (used_options - supported).empty?
end

raise "Offline check attempted #{OfflineDefinitionCheck::ATTEMPTS.join(', ')}" unless OfflineDefinitionCheck::ATTEMPTS.empty?
puts "Ruby #{RUBY_VERSION}; Fastlane #{Fastlane::VERSION}; Android 4 / iOS 3 lane definitions and action options verified offline. No lanes executed."
