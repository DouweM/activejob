require 'active_support/core_ext/string/filters'

module ActiveJob
  module Logging
    extend ActiveSupport::Concern
    
    included do
      cattr_accessor(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) }

      attr_accessor :perform_start_time

      before_enqueue do |job|
        if job.enqueued_at
          ActiveSupport::Notifications.instrument "enqueue_at.active_job", 
            adapter: job.class.queue_adapter, job: job.class, args: job.arguments, timestamp: job.enqueued_at
        else
          ActiveSupport::Notifications.instrument "enqueue.active_job",
            adapter: job.class.queue_adapter, job: job.class, args: job.arguments
        end
      end
      
      before_perform do |job|
        job.perform_start_time = Time.now

        ActiveSupport::Notifications.instrument "perform_start.active_job",
          adapter: job.class.queue_adapter, job: job.class, args: job.arguments
      end

      after_perform do |job|
        ActiveSupport::Notifications.instrument "perform_success.active_job",
          adapter: job.class.queue_adapter, job: job.class, args: job.arguments, elapsed: (Time.now - job.perform_start_time).to_f
      end
    end

    def execute(*)
      super
    rescue
      ActiveSupport::Notifications.instrument "perform_fail.active_job",
        adapter: self.class.queue_adapter, job: self.class, args: self.arguments, elapsed: (Time.now - self.perform_start_time).to_f
      raise
    end
    
    class LogSubscriber < ActiveSupport::LogSubscriber
      def enqueue(event)
        info "Enqueued #{job_name(event)} to #{queue_name(event)}" + args_info(event)
      end

      def enqueue_at(event)
        info "Enqueued #{job_name(event)} to #{queue_name(event)} at #{enqueued_at(event)}" + args_info(event)
      end

      def perform_start(event)
        info "Performing #{job_name(event)} from #{queue_name(event)}" + args_info(event)
      end

      def perform_success(event)
        info "Performed #{job_name(event)} from #{queue_name(event)} in " + elapsed(event) + args_info(event)
      end

      def perform_fail(event)
        info "Failed to perform #{job_name(event)} from #{queue_name(event)} in "+ elapsed(event) + args_info(event)
      end


      private
        def job_name(event)
          event.payload[:job].name
        end

        def queue_name(event)
          event.payload[:adapter].name.demodulize.remove('Adapter')
        end

        def args_info(event)
          event.payload[:args].any? ? ": #{event.payload[:args].inspect}" : ""
        end

        def enqueued_at(event)
          Time.at(event.payload[:timestamp]).utc
        end

        def elapsed(event)
          "#{event.payload[:elapsed].round(3)} sec"
        end

        def logger
          ActiveJob::Base.logger
        end
    end
  end
end

ActiveJob::Logging::LogSubscriber.attach_to :active_job
