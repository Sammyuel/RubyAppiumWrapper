# frozen_string_literal: true

# Devium namespace
module Devium
  # Creates Devices from specs provided by the Client
  #
  # @since v3.0.0
  class Device
    include PageObject

    attr_accessor :page, :credentials, :permissions

    # @param [String] app the app name corresponding to the folder
    def initialize(app)
      @credentials = get_secrets_yaml(app)
      @permissions = get_permissions_yaml(app)
    end

    # Create devices through the specs provided
    #
    # @param [Hash] devices_info device specification
    # @option devices_info [String] platform_version the OS version
    # @option devices_info [String] backend e.g appium, watir, etc.
    # @option devices_info [String] id unique device identifier
    # @option devices_info [String] name app name
    # @option devices_info [String] version app version
    # @option devices_info [String] vendor OEM name
    # @option devices_info [String] vendor_version OEM skin version
    # @option devices_info [Integer] port the port used by appium to connect
    # to Devium Hub
    def self.factory(devices_info)
      devices = [' '] + devices_info.map do |device_info|
        device_info[:tv] = is_tv(device_info[:applicationName])
        backend = device_info[:backend]
        platform = device_info[:platform].capitalize
        vendor_platform = device_info[:vendor] || platform
        create_devices(backend, vendor_platform, device_info)
      end
      launch_devices(devices) 
      return devices
    end

    # Obtain the information required by the user from the +secrets.yaml+ file

    # @param [Symbol] handle the name of the secret
    # @param [Hash, Symbol] opts set to either get a random or specific
    #   secret-set from a group
    # @option opts [Hash] key:'value' to get the specific secret-set from a
    #   group
    # @option opts [Symbol] :random to get a random secret-set
    # @return [Array<String>, String] the data associated with the user input
    # @raise [Exception] if the user entered secret is not found
    # @example get password for user1 who is a subscriber
    #   device.get_secret :subscribers, username:'user1'
    def get_secret(handle, opts = {})
      set = credentials[handle]
      raise DeviumDebug.fetch('secrets.invalid_secret') unless set
      return set.is_a?(Hash) ? set.values : set if opts.empty?
      if opts == :random
        return set.sample.is_a?(Hash) ? set.sample.values : set.sample
      end
      get_value_from_set set, opts
    end

    # Allows device objects to call page methods
    def method_missing(method, *args, &block)
      page.send(method, *args, &block)
    end

    def get_permissions(handle, opts={})
      set = permissions[handle]
      raise DeviumDebug.fetch('secrets.invalid_secret') unless set
      return set.is_a?(Hash) ? set.values : set if opts.empty?
      if opts == :random
        return set.sample.is_a?(Hash) ? set.sample.values : set.sample
      end
      get_value_from_set set, opts
    end

    # Class method. Includes version helpers during device creation
    #
    # @param [String] version version number
    def self.include_version(version)
      include const_get("Version_#{version.tr('.', '_')}") if version
    rescue StandardError => e
      puts e.class
      puts e.class.superclass
      puts e.class.superclass.superclass
      puts "#{e} \n \n"
    end


    private
    def self.is_tv(application_name)
      tv = ['mibox', 'bravia', 'afft', 'aquos','shield', 'aftmm', 'sony']
      if tv.any? { |element| application_name.downcase.include?(element) }
        return 'TV'
      end 
    end 

    def self.create_devices(backend, vendor_platform, device_info)
      if device_info[:backend] == 'Watir'
        vendor_platform += (device_info[:platform])
      end
      if device_info[:tv]
        vendor_platform += device_info[:tv]
      end
      Devium::PageObject.const_get(backend, false)
                        .const_get(vendor_platform, false)
                        .new(device_info)
    rescue StandardError => e
      puts e.class
      puts e.class.superclass
      puts e.class.superclass.superclass
      puts "#{e} \n \n" 
    end


    def self.launch_devices(devices)
      devices.drop(1).map(&:create_driver)
    end

    def get_value_from_set(set, look_for)
      handle = look_for.keys[0]
      final_set = set.detect { |f| f[handle] == look_for[handle] }
      final_set.values.last
    end

    def get_secrets_yaml(app)
      file = File.expand_path("apps/#{app}/secrets.yaml")
      YAML.load_file(file) if File.file?(file)
    end

    def get_permissions_yaml(app)
      file = File.expand_path("apps/#{app}/permissions.yaml")
      YAML.load_file(file) if File.file?(file)
    end
    private_class_method :create_devices, :launch_devices
  end
end
