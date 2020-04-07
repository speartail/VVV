# frozen_string_literal: true

class Helpers::Factory
  def self.create(provider)
    case provider
    when :hyperv, :parallels
      Helpers::Parallels.new
    else
      Helpers::Base.new
    end
  end
end
