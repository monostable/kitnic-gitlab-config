module Gitlab
  def self.config
    Settings
  end

  VERSION  = File.read(Rails.root.join("VERSION")).strip.freeze
REVISION = 'cbde95c'
end
