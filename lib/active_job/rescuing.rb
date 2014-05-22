require 'active_support/rescuable'

module ActiveJob
  module Rescuing
    extend ActiveSupport::Concern
    
    included do
      include ActiveSupport::Rescuable
    end

    def execute(*serialized_args)
      super
    rescue => exception
      rescue_with_handler(exception) || raise(exception)
    end
  end
end
