# frozen_string_literal: true

# Devium namespace
module Devium
  # Builds a page by including the correct modules
  #
  # @attr_reader [String] app the app name corresponding to +apps/+
  # @attr_reader [Devium::Page] page the app page to get constants from
  # @attr_reader [String] app_version the version of the app
  # @attr_reader [String] vendor_version the version of the OEM skin
  # @attr_reader [String] platform_version the OS version
  # @attr_reader [String] platform the OS of the device
  # @attr_reader [String] vendor the OEM that manufactored the device
  # @attr_accessor [String] mods the modules contained in the page
  # @since v3.0.0
  class PageBuilder
    attr_reader :app, :page, :platform, :vendor, :application_name, :tv_app
    attr_accessor :mods, :app_version, :vendor_version, :platform_version, :tv_app

    # @param [Devium::Page] page
    # @param [Hash] details the info needed to build the correct app page
    # @option details [String] app
    # @option details [String] app_version
    # @option details [String] platform
    # @option details [String] platform_version
    # @option details [String] vendor
    # @option details [String] vendor_version
    def initialize(page, details)
      @app_version      = details[:app_version]
      @vendor_version   = details[:vendor_version]
      @platform_version = details[:platform_version]
      @app              = details[:app]
      @page             = page
      @vendor           = details[:vendor]
      @platform         = details[:platform]
      @application_name = details[:application_name]
      @tv_app           = details[:tv]
      @module_list = [app, vendor, platform, tv_app]
    end

    # Builds the page
    def parse_page_modules
      page_modules
      reject_invalid_types
      inspect_version
      build_include_chain
    end

    # Set +@mods+ which is the modules contained in the page
    def page_modules
      @mods = Object.const_get("#{app}::#{page}").constants.map(&:to_s)
    end

    # Reject any modules that do not fit the current device
    def reject_invalid_types
      filtered_mods = @mods.each_with_object([]) do |change, memo|
        memo << change if type_valid?(change)
      end
      @mods = filtered_mods
      validate_mods
    end

    # Builds a sequence of modules that will be included in each page
    def build_include_chain
      range = [find_min, find_max]
      mutate_chain(range.compact.uniq)
    end

    # Modifies versions based on provided version vs supported version
    def inspect_version
      [app, vendor, platform, application_name.split(" ")[-1], tv_app].each do |type|
        instance_variable_set("@#{find_type(type)}_version", adjust(type))
      end
    end

    private

    def adjust(type)
      versions = applicable_versions(type)

      return get_version(type) if versions.empty?

      version_hash = create_version_hash(versions)
      version_length = version_max_length(version_hash).to_s.chars.count
      normalized_version = normalize_versions(version_hash, version_length)

      version_hash[normalized_version.sort.last]
    end

    def get_version(type)
      instance_variable_get("@#{find_type(type)}_version")
    end

    def create_version_hash(versions)
      versions.each_with_object({}) do |version, memo|
        key = version.split('.').join('').to_i
        memo[key] = version
      end
    end

    def normalize_versions(versions, count)
      versions.keys.map do |version|
        version * 10**(count - version.to_s.chars.count)
      end
    end

    def version_max_length(versions)
      versions.keys.max { |a, b| a.to_s.chars.count <=> b.to_s.chars.count }
    end

    def applicable_versions(type)
      mods.each_with_object([]) do |mod, memo|
        next if type != extract_type(mod)
        next if supported_version(mod).<=>(requested_version(type)) == 1
        memo << strip_version(mod).join('.')
      end
    end

    def supported_version(mod)
      version = strip_version(mod).join('.')
      Gem::Version.new(version)
    end

    def requested_version(type)
      version = get_version(type)
      Gem::Version.new(version)
    end

    def strip_version(mod)
      mod.split('_')[1..-1].map(&:strip)
    end

    def validate_mods
      [app, vendor, platform, application_name.split(" ")[-1], tv_app].each do |type|
        next if validate_mods_hierarchy?(type)
        raise 'Improper module hierarchy'
      end
    end

    def validate_mods_hierarchy?(type)
      current_version = 0
      @mods.each do |mod|
        next unless type == extract_type(mod)
        return false if change_version(mod) < current_version
        current_version = change_version(mod)
      end
    end

    def mod_index(type)
      @mods.index(append_version(type))
    end

    def find_min
      @mods.detect do |mod|
        relevant?(mod)
      end
    end

    def find_max
      return if @mods.count == 1
      @mods.reverse_each.detect do |change|
        relevant?(change)
      end
    end

    def relevant?(change)
      [append_version(app),
       append_version(vendor),
       append_version(platform),
       append_version(application_name.split(" ")[-1]),
       append_version(tv_app)].include?(change)
    end

    def type_valid?(change)
      [app, vendor, platform, application_name.split(" ")[-1], tv_app].include?(extract_type(change)) 
    end

    def append_version(type)
      type_version = version(type)
      "#{type}_#{type_version}"
    end

    def extract_type(param)
      param.split('_').first
    end

    def include_min_or_less(min)
      chain = []
      @mods.each_with_index do |change, index|
        chain << change if index <= @mods.index(min)
      end
      chain
    end

    def mutate_chain(range)
      return [] if range.empty?
      chain = include_min_or_less(range.first)
      return chain if @mods.count == 1
      range << @mods.last if range.count == 1
      add_to_chain(range.first, range.last, chain)
    end

    def version(type)
      type_version = get_version(type)
      type_version.tr('.', '_') if type_version 
    end

    def add_to_chain(min, max, chain)
      @mods.each_with_index do |change, index|
        next unless version_in_range(min, max, index)
        type_name = [app, vendor, platform, tv_app].detect do |type|
          extract_type(change) == type
        end
        target = version(type_name)
        chain << change if version_valid?(change, target)
      end

      chain << max
    end

    def version_in_range(min, max, index)
      index > @mods.index(min) && index < @mods.index(max)
    end

    def find_type(name)
      return 'app' if name == app
      return 'vendor' if name == vendor
      'platform'
    end

    def version_valid?(change, target)
      change_version(change) <= target_version(target)
    end

    def change_version(change)
      version_to_int(change.split('_')[1..-1].map(&:strip))
    end

    def target_version(current_target)
      version_to_int(current_target.split('_'))
    end

    def version_to_int(version_arr)
      version = if version_arr.length == 2
                  version_arr.join('') + '0'
                else
                  version_arr.join('')
                end
      version.to_f
    end
  end
end
