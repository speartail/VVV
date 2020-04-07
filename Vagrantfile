# frozen_string_literal: true

# vi: set ft=ruby ts=2 sw=2 et:
Vagrant.require_version '>= 2.2.4'
require_relative 'options'
require_relative 'virtualbox_helper'
require 'fileutils'
require 'logger'
require 'yaml'

vagrant_dir = __dir__
branch_c = "\033[38;5;6m" # 111m"
red = "\033[38;5;9m" # 124m"
green = "\033[1;38;5;2m" # 22m"
blue = "\033[38;5;4m" # 33m"
purple = "\033[38;5;5m" # 129m"
docs = "\033[0m"
yellow = "\033[38;5;3m" # 136m"
yellow_underlined = "\033[4;38;5;3m" # 136m"
url = yellow_underlined
creset = "\033[0m"

version = '?'
File.open("#{vagrant_dir}/version", 'r') do |f|
  version = f.read
  version = version.gsub("\n", '')
end

begin
  vvv_config_file = File.join(vagrant_dir, 'config/config.yml')
  old_vvv_config = File.join(vagrant_dir, 'vvv-custom.yml')
  puts 'before Options.new'
  vvv_config = Options.new vvv_config_file, old_vvv_config
  puts 'after Options.new'
  unless vvv_config[:sites].is_a?(Hash)
    puts "#{red}config/config.yml is missing a sites section.#{creset}\n\n"
  end
rescue StandardError => e
  puts "#{red}config/config.yml isn't a valid YAML file.#{creset}\n\n"
  puts "#{red}VVV cannot be executed!#{creset}\n\n"

  warn e.message
  exit
end

puts 'foobar'

# Show the initial splash screen

if vvv_config.show_logo?
  git_or_zip = 'zip-no-vcs'
  branch = ''
  if File.directory?("#{vagrant_dir}/.git")
    git_or_zip = 'git::'
    branch = `git --git-dir="#{vagrant_dir}/.git" --work-tree="#{vagrant_dir}" rev-parse --abbrev-ref HEAD`
    branch = branch.chomp("\n"); # remove trailing newline so it doesnt break the ascii art
  end

  splashfirst = <<~HEREDOC
    \033[1;38;5;196m#{red}__ #{green}__ #{blue}__ __
    #{red}\\ V#{green}\\ V#{blue}\\ V / #{red}Varying #{green}Vagrant #{blue}Vagrants
    #{red} \\_/#{green}\\_/#{blue}\\_/  #{purple}v#{version}#{creset}-#{branch_c}#{git_or_zip}#{branch}#{creset}

  HEREDOC
  puts splashfirst
end

old_db_backup_dir = File.join(vagrant_dir, 'database/backups/')
new_db_backup_dir = File.join(vagrant_dir, 'database/sql/backups/')
if File.directory?(old_db_backup_dir) && !File.directory?(new_db_backup_dir)
  puts 'Moving db backup directory into database/sql/backups'
  FileUtils.mv(old_db_backup_dir, new_db_backup_dir)
end

vvv_config[:hosts] += ['vvv.test']

vvv_config[:sites].each_pair do |site, args|
  if args.is_a? String
    repo = args
    args = {}
    args[:repo] = repo
  end

  args = {} unless args.is_a? Hash

  defaults = {}
  defaults['repo'] = false
  defaults['vm_dir'] = "/srv/www/#{site}"
  defaults['local_dir'] = File.join(vagrant_dir, 'www', site)
  defaults['branch'] = 'master'
  defaults['skip_provisioning'] = false
  defaults['allow_customfile'] = false
  defaults['nginx_upstream'] = 'php'
  defaults['hosts'] = []

  vvv_config[:sites][site] = defaults.merge(args)

  unless vvv_config[:sites][site][:skip_provisioning]
    site_host_paths = Dir.glob(Array.new(4) { |i| vvv_config[:sites][site][:local_dir] + '/*' * (i + 1) + '/vvv-hosts' })
    vvv_config[:sites][site][:hosts] += site_host_paths.map do |path|
      lines = File.readlines(path).map(&:chomp)
      lines.grep(/\A[^#]/)
    end.flatten

    vvv_config[:hosts] += vvv_config.dig(:sites, site, :hosts)
  end
  vvv_config[:sites][site].delete(:hosts)
end

vvv_config['utility-sources'.to_sym].each_pair do |name, args|
  next unless args.is_a? String

  repo = args
  args = {}
  args['repo'] = repo
  args['branch'] = 'master'

  vvv_config['utility-sources'][name] = args
end

dashboard_defaults = {}
dashboard_defaults[:repo] = 'https://github.com/Varying-Vagrant-Vagrants/dashboard.git'
dashboard_defaults[:branch] = 'master'
vvv_config[:dashboard] = dashboard_defaults.merge(vvv_config[:dashboard])

unless vvv_config['utility-sources'].key?('core')
  vvv_config['utility-sources']['core'] = {}
  vvv_config['utility-sources']['core']['repo'] = 'https://github.com/Varying-Vagrant-Vagrants/vvv-utilities.git'
  vvv_config['utility-sources']['core']['branch'] = 'master'
end

# Create a global variable to use in functions and classes
# $vvv_config = vvv_config

if vvv_config.vm_config.dig(:box)
  puts "Custom Box: Box overriden via config/config.yml , this won't take effect until a destroy + reprovision happens"
end

if vvv_config.show_logo?
  virtualbox_version = 'N/A'

  virtualbox_version = get_virtualbox_version if vvv_config.virtalbox?

  splashsecond = <<~HEREDOC
    #{yellow}Platform: #{yellow}#{vvv_config.platform}, #{purple}VVV Path: "#{vagrant_dir}"
    #{green}Vagrant: #{green}v#{Vagrant::VERSION}, #{blue}VirtualBox: #{blue}v#{virtualbox_version}

    #{docs}Docs:       #{url}https://varyingvagrantvagrants.org/
    #{docs}Contribute: #{url}https://github.com/varying-vagrant-vagrants/vvv
    #{docs}Dashboard:  #{url}http://vvv.test#{creset}

  HEREDOC
  puts splashsecond
end

# Override or set the vagrant provider.
ENV['VAGRANT_DEFAULT_PROVIDER'] = vvv_config.provider

ENV['LC_ALL'] = 'C.UTF-8'

Vagrant.configure('2') do |config|
  # Store the current version of Vagrant for use in conditionals when dealing
  # with possible backward compatible issues.
  vagrant_version = Vagrant::VERSION.sub(/^v/, '')

  config.vm.provider :virtualbox do |v|
    v.customize [:modifyvm, :id, '--uartmode1', 'file', File.join(vagrant_dir, 'log/ubuntu-bionic-18.04-cloudimg-console.log')]

    v.customize [:modifyvm, :id, '--memory', vvv_config.memory]
    v.customize [:modifyvm, :id, '--cpus', vvv_config.cpus]
    v.customize [:modifyvm, :id, '--natdnshostresolver1', 'on']
    v.customize [:modifyvm, :id, '--natdnsproxy1', 'on']

    # see https://github.com/hashicorp/vagrant/issues/7648
    v.customize [:modifyvm, :id, '--cableconnected1', 'on']

    v.customize [:modifyvm, :id, '--rtcuseutc', 'on']
    v.customize [:modifyvm, :id, '--audio', 'none']
    v.customize [:modifyvm, :id, '--paravirtprovider', 'kvm']
    v.customize [:setextradata, :id, 'VBoxInternal2/SharedFoldersEnableSymlinksCreate//srv/www', '1']
    v.customize [:setextradata, :id, 'VBoxInternal2/SharedFoldersEnableSymlinksCreate//srv/config', '1']

    # Set the box name in VirtualBox to match the working directory.
    v.name = vvv_config.name
  end

  config.vm.provider :hyperv do |v|
    v.memory = vvv_config.memory
    v.cpus = vvv_config.cpus
    v.enable_virtualization_extensions = true
    v.linked_clone = true
  end

  config.vm.provider :libvirt do |v|
    v.qemu_use_session = true
    v.memory = vvv_config.memory
    v.cpus = vvv_config.cpus
  end

  config.vm.provider :parallels do |v|
    v.update_guest_tools = true
    v.customize ['set', :id, '--longer-battery-life', 'off']
    v.memory = vvv_config.memory
    v.cpus = vvv_config.cpus
  end

  config.vm.provider :vmware_desktop do |v|
    v.vmx[:memsize] = vvv_config.memory
    v.vmx[:numvcpus] = vvv_config.cpus
  end

  # Auto Download Vagrant plugins, supported from Vagrant 2.2.0
  unless Vagrant.has_plugin?('vagrant-hostsupdater')
    if File.file?(File.join(vagrant_dir, 'vagrant-hostsupdater.gem'))
      system('vagrant plugin install ' + File.join(vagrant_dir, 'vagrant-hostsupdater.gem'))
      File.delete(File.join(vagrant_dir, 'vagrant-hostsupdater.gem'))
      puts "#{yellow}VVV has completed installing local plugins. Please run the requested command again.#{creset}"
      exit
    else
      config.vagrant.plugins = ['vagrant-hostsupdater']
    end
  end

  # The vbguest plugin has issues for some users, so we're going to disable it for now
  config.vbguest.auto_update = false if Vagrant.has_plugin?('vagrant-vbguest')

  # SSH Agent Forwarding
  #
  # Enable agent forwarding on vagrant ssh commands. This allows you to use ssh keys
  # on your host machine inside the guest. See the manual for `ssh-add`.
  config.ssh.forward_agent = true

  # SSH Key Insertion
  #
  # This is disabled, we had several contributors who ran into issues.
  # See: https://github.com/Varying-Vagrant-Vagrants/VVV/issues/1551
  config.ssh.insert_key = false

  # Default Ubuntu Box
  #
  # This box is provided by Ubuntu vagrantcloud.com and is a nicely sized
  # box containing the Ubuntu 18.04 Bionic 64 bit release. Once this box is downloaded
  # to your host computer, it is cached for future use under the specified box name.
  config.vm.box = vvv_config.box

  config.vm.hostname = 'vvv'

  # Specify disk size
  #
  # If the Vagrant plugin disksize (https://github.com/sprotheroe/vagrant-disksize) is
  # installed, the following will automatically configure your local machine's disk size
  # to be the specified size. This plugin only works on VirtualBox.
  #
  # Warning: This plugin only resizes up, not down, so don't set this to less than 10GB,
  # and if you need to downsize, be sure to destroy and reprovision.
  #
  if (disksize = vvv_config.dig('vagrant-plugins'.to_sym, :disksize)) && defined?(Vagrant::Disksize)
    config.vm.provider :virtualbox do |_v, override|
      override.disksize.size = disksize
    end
  end

  # Private Network (default)
  #
  # A private network is created by default. This is the IP address through which your
  # host machine will communicate to the guest. In this default configuration, the virtual
  # machine will have an IP address of 192.168.50.4 and a virtual network adapter will be
  # created on your host machine with the IP of 192.168.50.1 as a gateway.
  #
  # Access to the guest machine is only available to your local host. To provide access to
  # other devices, a public network should be configured or port forwarding enabled.
  #
  # Note: If your existing network is using the 192.168.50.x subnet, this default IP address
  # should be changed. If more than one VM is running through VirtualBox, including other
  # Vagrant machines, different subnets should be used for each.
  #
  config.vm.network :private_network, id: 'vvv_primary', ip: vvv_config.vm_config.dig(:private_ip)

  config.vm.provider :hyperv do |_v, override|
    override.vm.network :private_network, id: 'vvv_primary', ip: nil
  end

  # Public Network (disabled)
  #
  # Using a public network rather than the default private network configuration will allow
  # access to the guest machine from other devices on the network. By default, enabling this
  # line will cause the guest machine to use DHCP to determine its IP address. You will also
  # be prompted to choose a network interface to bridge with during `vagrant up`.
  #
  # Please see VVV and Vagrant documentation for additional details.
  #
  # config.vm.network :public_network

  # Port Forwarding (disabled)
  #
  # This network configuration works alongside any other network configuration in Vagrantfile
  # and forwards any requests to port 8080 on the local host machine to port 80 in the guest.
  #
  # Port forwarding is a first step to allowing access to outside networks, though additional
  # configuration will likely be necessary on our host machine or router so that outside
  # requests will be forwarded from 80 -> 8080 -> 80.
  #
  # Please see VVV and Vagrant documentation for additional details.
  #
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Drive mapping
  #
  # The following config.vm.synced_folder settings will map directories in your Vagrant
  # virtual machine to directories on your local machine. Once these are mapped, any
  # changes made to the files in these directories will affect both the local and virtual
  # machine versions. Think of it as two different ways to access the same file. When the
  # virtual machine is destroyed with `vagrant destroy`, your files will remain in your local
  # environment.

  # Disable the default synced folder to avoid overlapping mounts
  config.vm.synced_folder '.', '/vagrant', disabled: true
  config.vm.provision 'file', source: "#{vagrant_dir}/version", destination: '/home/vagrant/version'

  # /srv/database/
  #
  # If a database directory exists in the same directory as your Vagrantfile,
  # a mapped directory inside the VM will be created that contains these files.
  # This directory is used to maintain default database scripts as well as backed
  # up MariaDB/MySQL dumps (SQL files) that are to be imported automatically on vagrant up
  config.vm.synced_folder 'database/sql/', '/srv/database'

  use_db_share = vvv_config.dig(:general, :db_share_type)

  if use_db_share
    # Map the MySQL Data folders on to mounted folders so it isn't stored inside the VM
    config.vm.synced_folder 'database/data/', '/var/lib/mysql', **vvv_config.db_mount_opts
  end

  # /srv/config/
  #
  # If a server-conf directory exists in the same directory as your Vagrantfile,
  # a mapped directory inside the VM will be created that contains these files.
  # This directory is currently used to maintain various config files for php and
  # nginx as well as any pre-existing database files.
  config.vm.synced_folder 'config/', '/srv/config'

  # /srv/config/
  #
  # Map the provision folder so that utilities and provisioners can access helper scripts
  config.vm.synced_folder 'provision/', '/srv/provision'

  # /srv/certificates
  #
  # This is a location for the TLS certificates to be accessible inside the VM
  config.vm.synced_folder 'certificates/', '/srv/certificates', create: true

  # /var/log/
  #
  # If a log directory exists in the same directory as your Vagrantfile, a mapped
  # directory inside the VM will be created for some generated log files.
  config.vm.synced_folder 'log/memcached', '/var/log/memcached', owner: 'root', create: true, group: 'syslog', mount_options: ['dmode=777', 'fmode=666']
  config.vm.synced_folder 'log/nginx', '/var/log/nginx', owner: 'root', create: true, group: 'syslog', mount_options: ['dmode=777', 'fmode=666']
  config.vm.synced_folder 'log/php', '/var/log/php', create: true, owner: 'root', group: 'syslog', mount_options: ['dmode=777', 'fmode=666']
  config.vm.synced_folder 'log/provisioners', '/var/log/provisioners', create: true, owner: 'root', group: 'syslog', mount_options: ['dmode=777', 'fmode=666']

  # /srv/www/
  #
  # If a www directory exists in the same directory as your Vagrantfile, a mapped directory
  # inside the VM will be created that acts as the default location for nginx sites. Put all
  # of your project files here that you want to access through the web server
  config.vm.synced_folder 'www/', '/srv/www', owner: 'vagrant', group: 'www-data', mount_options: ['dmode=775', 'fmode=774']

  vvv_config[:sites].each_pair do |site, args|
    if args[:local_dir] != File.join(vagrant_dir, 'www', site)
      config.vm.synced_folder args[:local_dir], args[:vm_dir], owner: 'vagrant', group: 'www-data', mount_options: ['dmode=775', 'fmode=774']
    end
  end

  # The Parallels Provider does not understand "dmode"/"fmode" in the "mount_options" as
  # those are specific to Virtualbox. The folder is therefore overridden with one that
  # uses corresponding Parallels mount options.
  config.vm.provider :parallels do |_v, override|
    override.vm.synced_folder 'www/', '/srv/www',
                              owner: 'vagrant', group: 'www-data', mount_options: []

    override.vm.synced_folder 'log/memcached', '/var/log/memcached',
                              owner: 'root', create: true, group: 'syslog', mount_options: []
    override.vm.synced_folder 'log/nginx', '/var/log/nginx',
                              owner: 'root', create: true, group: 'syslog', mount_options: []
    override.vm.synced_folder 'log/php', '/var/log/php',
                              create: true, owner: 'root', group: 'syslog', mount_options: []
    override.vm.synced_folder 'log/provisioners', '/var/log/provisioners',
                              create: true, owner: 'root', group: 'syslog', mount_options: []

    if use_db_share
      # Map the MySQL Data folders on to mounted folders so it isn't stored inside the VM
      override.vm.synced_folder 'database/data/', '/var/lib/mysql',
                                create: true, owner: 112, group: 115, mount_options: []
    end

    vvv_config[:sites].each_pair do |site, args|
      if args[:local_dir] != File.join(vagrant_dir, 'www', site)
        override.vm.synced_folder args[:local_dir], args[:vm_dir],
                                  owner: 'vagrant', group: 'www-data', mount_options: []
      end
    end
  end

  # The Hyper-V Provider does not understand "dmode"/"fmode" in the "mount_options" as
  # those are specific to Virtualbox. Furthermore, the normal shared folders need to be
  # replaced with SMB shares. Here we switch all the shared folders to us SMB and then
  # override the www folder with options that make it Hyper-V compatible.
  config.vm.provider :hyperv do |v, override|
    v.vmname = File.basename(vagrant_dir) + '_' + (Digest::SHA256.hexdigest vagrant_dir)[0..10]

    override.vm.synced_folder 'www/', '/srv/www', owner: 'vagrant', group: 'www-data', mount_options: ['dir_mode=0775', 'file_mode=0774']

    if use_db_share == true
      # Map the MySQL Data folders on to mounted folders so it isn't stored inside the VM
      override.vm.synced_folder 'database/data/', '/var/lib/mysql', create: true, owner: 112, group: 115, mount_options: ['dir_mode=0775', 'file_mode=0664']
    end

    override.vm.synced_folder 'log/memcached', '/var/log/memcached', owner: 'root', create: true, group: 'syslog', mount_options: ['dir_mode=0777', 'file_mode=0666']
    override.vm.synced_folder 'log/nginx', '/var/log/nginx', owner: 'root', create: true, group: 'syslog', mount_options: ['dir_mode=0777', 'file_mode=0666']
    override.vm.synced_folder 'log/php', '/var/log/php', create: true, owner: 'root', group: 'syslog', mount_options: ['dir_mode=0777', 'file_mode=0666']
    override.vm.synced_folder 'log/provisioners', '/var/log/provisioners', create: true, owner: 'root', group: 'syslog', mount_options: ['dir_mode=0777', 'file_mode=0666']

    vvv_config['sites'].each do |site, args|
      if args['local_dir'] != File.join(vagrant_dir, 'www', site)
        override.vm.synced_folder args['local_dir'], args['vm_dir'], owner: 'vagrant', group: 'www-data', mount_options: ['dir_mode=0775', 'file_mode=0774']
      end
    end
  end

  # The VMware Provider does not understand "dmode"/"fmode" in the "mount_options" as
  # those are specific to Virtualbox. The folder is therefore overridden with one that
  # uses corresponding VMware mount options.
  config.vm.provider :vmware_desktop do |_v, override|
    override.vm.synced_folder 'www/', '/srv/www', owner: 'vagrant', group: 'www-data', mount_options: ['umask=002']

    override.vm.synced_folder 'log/memcached', '/var/log/memcached', owner: 'root', create: true, group: 'syslog', mount_options: ['umask=000']
    override.vm.synced_folder 'log/nginx', '/var/log/nginx', owner: 'root', create: true, group: 'syslog', mount_options: ['umask=000']
    override.vm.synced_folder 'log/php', '/var/log/php', create: true, owner: 'root', group: 'syslog', mount_options: ['umask=000']
    override.vm.synced_folder 'log/provisioners', '/var/log/provisioners', create: true, owner: 'root', group: 'syslog', mount_options: ['umask=000']

    if use_db_share == true
      # Map the MySQL Data folders on to mounted folders so it isn't stored inside the VM
      override.vm.synced_folder 'database/data/', '/var/lib/mysql', create: true, owner: 112, group: 115, mount_options: ['umask=000']
    end

    vvv_config['sites'].each do |site, args|
      if args['local_dir'] != File.join(vagrant_dir, 'www', site)
        override.vm.synced_folder args['local_dir'], args['vm_dir'], owner: 'vagrant', group: 'www-data', mount_options: ['umask=002']
      end
    end
  end

  # Customfile - POSSIBLY UNSTABLE
  #
  # Use this to insert your own additional Vagrant config lines. Helpful
  # for mapping additional drives. If a file 'Customfile' exists in the same directory
  # as this Vagrantfile, it will be evaluated as ruby inline as it loads.
  #
  # Note that if you find yourself using a Customfile for anything crazy or specifying
  # different provisioning, then you may want to consider a new Vagrantfile entirely.
  if File.exist?(File.join(vagrant_dir, 'Customfile'))
    puts "Running Custom Vagrant file with additional vagrant configs at #{File.join(vagrant_dir, 'Customfile')}\n\n"
    eval(IO.read(File.join(vagrant_dir, 'Customfile')), binding)
    puts "Finished running Custom Vagrant file with additional vagrant configs, resuming normal vagrantfile execution\n\n"
  end

  vvv_config[:sites].each_pair do |site, args|
    next unless args[:allow_customfile]

    Dir[File.join(args['local_dir'], '**', 'Customfile')].each do |file|
      puts "Running additional site vagrant customfile at #{file}\n\n"
      eval(IO.read(file), binding)
    end
  end

  # Provisioning
  #
  # Process one or more provisioning scripts depending on the existence of custom files.
  #
  # provison-pre.sh acts as a pre-hook to our default provisioning script. Anything that
  # should run before the shell commands laid out in provision.sh (or your provision-custom.sh
  # file) should go in this script. If it does not exist, no extra provisioning will run.
  # if File.exist?(File.join(vagrant_dir, 'provision', 'provision-pre.sh'))
  #   config.vm.provision 'pre', type: 'shell', keep_color: true, path: File.join('provision', 'provision-pre.sh')
  # end

  # provision.sh or provision-custom.sh
  #
  # By default, Vagrantfile is set to use the provision.sh bash script located in the
  # provision directory. If it is detected that a provision-custom.sh script has been
  # created, that is run as a replacement. This is an opportunity to replace the entirety
  # of the provisioning provided by default.
  # if File.exist?(File.join(vagrant_dir, 'provision', 'provision-custom.sh'))
  #   config.vm.provision 'custom', type: 'shell', keep_color: true, path: File.join('provision', 'provision-custom.sh')
  # else
  #   config.vm.provision 'default', type: 'shell', keep_color: true, path: File.join('provision', 'provision.sh')
  # end

  config.vm.provision :ansible_local do |ansible|
    ansible.become = true
    ansible.playbook = '/srv/provision/ansible/playbook.yml'
    ansible.compatibility_mode = '2.0'
    ansible.install_mode = :default
    ansible.version = :latest

    #   ansible.extra_vars = {
    #     mysql = {
    #       id: MYSQL_ID,
    #     }
    #   }
  end

  # Provision the dashboard that appears when you visit vvv.test
  config.vm.provision 'dashboard',
                      type: 'shell',
                      keep_color: true,
                      path: File.join('provision', 'provision-dashboard.sh'),
                      args: [
                        vvv_config['dashboard']['repo'],
                        vvv_config['dashboard']['branch']
                      ]

  vvv_config['utility-sources'.to_sym].each do |name, args|
    config.vm.provision "utility-source-#{name}",
                        type: 'shell',
                        keep_color: true,
                        path: File.join('provision', 'provision-utility-source.sh'),
                        args: [
                          name,
                          args[:repo].to_s,
                          args[:branch]
                        ]
  end

  vvv_config[:utilities].each_pair do |name, utilities|
    utilities = {} unless utilities.is_a? Enumerable
    utilities.each do |utility|
      if utility == 'tideways'
        vvv_config[:hosts] += %w[tideways.vvv.test]
        vvv_config[:hosts] += %w[xhgui.vvv.test]
      end
      config.vm.provision "utility-#{name}-#{utility}",
                          type: 'shell',
                          keep_color: true,
                          path: File.join('provision', 'provision-utility.sh'),
                          args: [
                            name,
                            utility
                          ]
    end
  end

  vvv_config[:sites].each do |site, args|
    next if args[:skip_provisioning]

    config.vm.provision "site-#{site}",
                        type: 'shell',
                        keep_color: true,
                        path: File.join('provision', 'provision-site.sh'),
                        args: [
                          site,
                          args['repo'].to_s,
                          args['branch'],
                          args['vm_dir'],
                          args['skip_provisioning'].to_s,
                          args['nginx_upstream']
                        ]
  end

  # provision-post.sh acts as a post-hook to the default provisioning. Anything that should
  # run after the shell commands laid out in provision.sh or provision-custom.sh should be
  # put into this file. This provides a good opportunity to install additional packages
  # without having to replace the entire default provisioning script.
  if File.exist?(File.join(vagrant_dir, 'provision', 'provision-post.sh'))
    config.vm.provision 'post', type: 'shell', keep_color: true, path: File.join('provision', 'provision-post.sh')
  end

  # Local Machine Hosts
  #
  # If the Vagrant plugin hostsupdater (https://github.com/cogitatio/vagrant-hostsupdater) is
  # installed, the following will automatically configure your local machine's hosts file to
  # be aware of the domains specified below. Watch the provisioning script as you may need to
  # enter a password for Vagrant to access your hosts file.
  #
  # By default, we'll include the domains set up by VVV through the vvv-hosts file
  # located in the www/ directory and in config/config.yml.
  if vvv_config.use_hosts_updater

    # Pass the found host names to the hostsupdater plugin so it can perform magic.
    config.hostsupdater.aliases = vvv_config[:hosts]
    config.hostsupdater.remove_on_suspend = true
  end

  # Vagrant Triggers
  #
  # We run various scripts on Vagrant state changes like `vagrant up`, `vagrant halt`,
  # `vagrant suspend`, and `vagrant destroy`
  #
  # These scripts are run on the host machine, so we use `vagrant ssh` to tunnel back
  # into the VM and execute things. By default, each of these scripts calls db_backup
  # to create backups of all current databases. This can be overridden with custom
  # scripting. See the individual files in config/homebin/ for details.
  config.trigger.after :up do |trigger|
    trigger.name = 'VVV Post-Up'
    trigger.run_remote = { inline: '/srv/config/homebin/vagrant_up' }
    trigger.on_error = :continue
  end

  config.trigger.before :provision do |trigger|
    trigger.info = '༼ つ ◕_◕ ༽つ Provisioning can take a few minutes, go make a cup of tea and sit back. If you only wanted to turn VVV on, use vagrant up'
    trigger.on_error = :continue
  end

  config.trigger.after :provision do |trigger|
    trigger.name = 'VVV Post-Provision'
    trigger.run_remote = { inline: '/srv/config/homebin/vagrant_provision' }
    trigger.on_error = :continue
  end

  config.trigger.before :reload do |trigger|
    trigger.name = 'VVV Pre-Reload'
    trigger.run_remote = { inline: '/srv/config/homebin/vagrant_halt' }
    trigger.on_error = :continue
  end

  config.trigger.after :reload do |trigger|
    trigger.name = 'VVV Post-Reload'
    trigger.run_remote = { inline: '/srv/config/homebin/vagrant_up' }
    trigger.on_error = :continue
  end

  config.trigger.before :halt do |trigger|
    trigger.name = 'VVV Pre-Halt'
    trigger.run_remote = { inline: '/srv/config/homebin/vagrant_halt' }
    trigger.on_error = :continue
  end

  config.trigger.before :suspend do |trigger|
    trigger.name = 'VVV Pre-Suspend'
    trigger.run_remote = { inline: '/srv/config/homebin/vagrant_suspend' }
    trigger.on_error = :continue
  end

  config.trigger.before :destroy do |trigger|
    trigger.name = 'VVV Pre-Destroy'
    trigger.run_remote = { inline: '/srv/config/homebin/vagrant_destroy' }
    trigger.on_error = :continue
  end
end

# -*- mode: ruby -*-
