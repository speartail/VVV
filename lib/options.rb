# frozen_string_literal: true

require 'forwardable'

class Array
  def to_strings
    compact.map(&:to_s)
  end
end

class Hash
  def symbolize_keys!
    h = map do |k, v|
      v_sym = if v.instance_of? Hash
                v.symbolize_keys!
              else
                v
              end

      [k.to_sym, v_sym]
    end
    Hash[h]
  end
end

class Options
  extend Forwardable

  def_delegators :@config, :dig

  %i[hyperv libvirt parallels virtualbox vmware].each do |p|
    define_method "#{p}?".to_sym do
      provider == p
    end
  end

  %i[general sites vm_config].each do |i|
    define_method i do
      @config[i]
    end
  end

  def initialize(new_file, old_file)
    migrate_old_config_file_maybe!(new_file, old_file)

    begin
      @config = YAML.load_file(new_file).symbolize_keys!
    rescue StandardError => e
      puts e.message
    end

    set_defaults!
  end

  def [](key)
    @config[key.to_sym]
  end

  def []=(key, value)
    @config[key.to_sym] = value
  end

  def name
    File.basename(__dir__) + '_' + Digest::SHA256.hexdigest(__dir__)[0..10]
  end

  def box
    if vm_config.dig(:wordcamp_contributor_day_box)
      'vvv/contribute'
    else
      vm_config.dig(:box) || 'generic/ubuntu1804'
    end
  end

  def cpus
    vm_config.dig(:cores) || 1
  end

  def memory
    vm_config.dig(:memory) || 2048
  end

  def hosts
    [vm_config.dig(:hosts),
     'vvv.test'].flatten.compact.uniq
  end

  def provider
    (vm_config.dig(:provider) || ENV.fetch('VAGRANT_DEFAULT_PROVIDER', :virtualbox)).to_sym
  end

  def db_mount_opts(dmode = '0755', fmode = '0644')
    {
      create: true,
      owner: mysql_id,
      group: mysql_id,
      # The Parallels and Hyperv Providers do not understand "dmode"/"fmode" in the "mount_options"
      mount_options: %i[hyperv parallels].include?(provider) ? [] : ["dmode=#{dmode}", "fmode=#{fmode}"]
    }
  end

  def provider_version; end

  def private_ip
    if hyperv?
      nil
    elsif virtualbox?
      '192.168.50.4'
    else
      '192.168.112.4'
    end
  end

  def show_logo?
    return false if ENV.fetch('VVV_SKIP_LOGO')

    # whitelist when we show the logo, else it'll show on global Vagrant commands
    %w[up resume status provision reload].include? ARGV[0]
  end

  def use_disksize?
    defined?(Vagrant::Disksize) && vm_config.dig('vagrant-plugins'.to_sym, :disksize)
  end

  def use_hosts_updater?
    defined?(VagrantPlugins::HostsUpdater) && !ENV.key?('SKIP_HOSTS_UPDATER')
  end

  def mysql_id
    9001
  end

  def platform
    tags = ['platform-' + Vagrant::Util::Platform.platform]

    if Vagrant::Util::Platform.windows?
      tags << 'windows'
      tags << 'wsl' if Vagrant::Util::Platform.wsl?
      tags << 'msys' if Vagrant::Util::Platform.msys?
      tags << 'cygwin' if Vagrant::Util::Platform.cygwin?
      if Vagrant::Util::Platform.windows_hyperv_enabled?
        tags << 'HyperV-Enabled'
      end
      tags << 'HyperV-Admin' if Vagrant::Util::Platform.windows_hyperv_admin?
      tags << 'HasWinAdminPriv' if Vagrant::Util::Platform.windows_admin?
    else
      tags << 'shell: ' + ENV['SHELL'] if ENV['SHELL']
      tags << 'systemd' if Vagrant::Util::Platform.systemd?
      tags << 'libvirt' if Vagrant::Util::Platform.libvirt?
    end

    %w[vagrant-hostsupdater vagrant-vbguest vagrant-disksize].each do |p|
      tags << p if Vagrant.has_plugin?(p)
    end

    tags << 'NoColour' unless Vagrant::Util::Platform.terminal_supports_colors?

    if vm_config.dig(:wordcamp_contributor_day_box)
      tags << 'contributor_day_box'
    end

    if box = vvv_config.vm_config.dig(:box)
      tags << 'box_override:' + box
    end

    tags << 'shared_db_folder' + vvv_config.dig(:general, :db_share_type) ? 'enabled' : 'disabled'

    tags.sort.join ' '
  end

  private

  # Perform file migrations from older versions
  def migrate_old_config_file_maybe!(new_file, old_file)
    return if File.file?(new_file)

    FileUtils.mv(old_file, new_file) if File.file?(old_file)
  end

  def set_defaults!
    # arrays
    %i[hosts].each do |i|
      @config[i] = [] unless @config[i].is_a?(Array)
    end

    # hashes
    %i[dashboard general sites utilities utility-sources vagrant-plugins].each do |i|
      @config[i] = {} unless @config[i].is_a?(Hash)
    end
  end
end
