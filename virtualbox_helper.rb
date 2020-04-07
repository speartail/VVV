# frozen_string_literal: true

class VirtualboxHelper
  def initialize
    @vboxmanage_path = nil
  end

  def exe_path
    if Vagrant::Util::Platform.windows? || Vagrant::Util::Platform.cygwin?
      @vboxmanage_path = Vagrant::Util::Which.which('VBoxManage')

      # On Windows, we use the VBOX_INSTALL_PATH environmental
      # variable to find VBoxManage.
      unless @vboxmanage_path && (ENV.key?('VBOX_INSTALL_PATH') ||
                                  ENV.key?('VBOX_MSI_INSTALL_PATH'))

        # Get the path.
        path = ENV['VBOX_INSTALL_PATH'] || ENV['VBOX_MSI_INSTALL_PATH']

        # There can actually be multiple paths in here, so we need to
        # split by the separator ";" and see which is a good one.
        path.split(';').each do |single|
          # Make sure it ends with a \
          single += '\\' unless single.end_with?('\\')

          # If the executable exists, then set it as the main path
          # and break out
          vboxmanage = "#{single}VBoxManage.exe"
          if File.file?(vboxmanage)
            @vboxmanage_path = Vagrant::Util::Platform.cygwin_windows_path(vboxmanage)
            break
          end
        end
      end

      # If we still don't have one, try to find it using common locations
      drive = ENV['SYSTEMDRIVE'] || 'C:'
      [
        "#{drive}/Program Files/Oracle/VirtualBox",
        "#{drive}/Program Files (x86)/Oracle/VirtualBox",
        "#{ENV['PROGRAMFILES']}/Oracle/VirtualBox"
      ].each do |maybe|
        path = File.join(maybe, 'VBoxManage.exe')
        if File.file?(path)
          @vboxmanage_path = path
          break
        end
      end

    elsif Vagrant::Util::Platform.wsl?
      unless Vagrant::Util::Platform.wsl_windows_access?
        raise Vagrant::Errors::WSLVirtualBoxWindowsAccessError
      end

      @vboxmanage_path = Vagrant::Util::Which.which('VBoxManage') || Vagrant::Util::Which.which('VBoxManage.exe')
      unless @vboxmanage_path
        # If we still don't have one, try to find it using common locations
        drive = '/mnt/c'
        [
          "#{drive}/Program Files/Oracle/VirtualBox",
          "#{drive}/Program Files (x86)/Oracle/VirtualBox"
        ].each do |maybe|
          path = File.join(maybe, 'VBoxManage.exe')
          if File.file?(path)
            @vboxmanage_path = path
            break
          end
        end
      end
    end

    # Fall back to hoping for the PATH to work out
    @vboxmanage_path ||= 'VBoxManage'

    @vboxmanage_path
  end

  def version
    Vagrant::Util::Subprocess.execute(exe_path, '--version')&.stdout&.to_s.strip!
  end
end
