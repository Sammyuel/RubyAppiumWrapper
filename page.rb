# frozen_string_literal: true

# Devium namespace
module Devium
  # Parent class for all app pages
  #
  # @since v3.0.0
  class Page
    attr_reader :device
    attr_reader :mods
    attr_reader :ui_map

    # @param [Devium::Device] device the device object to be called in app pages
    def initialize(device)
      @device = device
      include_modules
      @ui_map = include_ui_map
    end

    # Builds page and includes dependencies
    def include_modules
      @mods = Devium::PageBuilder.new(page, details).parse_page_modules
      mods.map do |mod|
        extend Object.const_get("#{self.class}::#{mod}")
      end
    end

    # Includes all ui_map dependencies
    def include_ui_map
      map = {}
      mods.each.map do |mod|
        file = get_ui_map(extract_type(mod.upcase)).first
        loaded_yaml = YAML.load_file(file)
        next unless loaded_yaml.is_a? Hash
        map = merge_ui_map(map, mod, loaded_yaml)
      end
      map
    end

    # Nagivates between page within the same app
    def goto(page_name, *_args, &block)
      unless respond_to?("goto_page_#{method_name(page_name)}".to_sym)
        raise "#{page_name} not found"
      end
      page = Page.const_get("#{device.app}::#{page_name}")
                 .public_send(:new, device, &block)
      device.page = page
      public_send("goto_page_#{method_name(page_name)}".to_sym, page, &block)
    end

    private

    attr_writer :device

    def deep_merge(first_hash, second_hash)
      merger = proc do |_key, v1, v2|
        v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge(v2, &merger) : v2
      end

      first_hash.merge(second_hash, &merger)
    end

    def merge_ui_map(map, mod, loaded_yaml)
      version = mod.split('_')[1..-1].join('_')
      loaded_yaml = loaded_yaml[:"#{version}"]
      loaded_yaml.is_a?(Hash) ? deep_merge(map, loaded_yaml) : map
    end

    def method_name(page_name)
      page_name.to_s.split(/(?=[A-Z])/).map(&:downcase).join('_')
    end

    def page
      self.class.to_s.split('::').last
    end
      
    def extract_type(param)
      param.split('_').first
    end

    def get_ui_map(type)
      Object.const_get("#{device.app}::UiMap::#{type}_UI_MAP")
    end

    def details
      { 
        tv: device.tv_app,
        application_name: device.application_name,
        platform: device.platform,
        platform_version: device.platform_version,
        app: device.app,
        app_version: device.app_version,
        vendor: device.vendor,
        vendor_version: device.vendor_version,
      }
    end

    def instance_vars
      instance_variables.map do |var|
        instance_variable_get(var)
      end
    end
  end
end
