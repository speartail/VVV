# frozen_string_literal: true

class Helpers::Base
  def mount_options(dmode = '0755', fmode = '0644')
    [
      "dmode=#{dmode}"
      "fmode=#{fmode}"
    ]
  end
end
