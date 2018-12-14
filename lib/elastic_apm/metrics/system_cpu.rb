# frozen_string_literal: true

module ElasticAPM
  class Metrics
    # @api private
    class SystemCPU
      include Logging

      def initialize(config)
        @config = config

        @disabled = false
        @sampler = sampler_for_platform(Metrics.platform)
      end

      def sample
        return if disabled?
        @sampler.sample
      end

      def disabled?
        @disabled
      end

      private

      def sampler_for_platform(platform)
        case platform
        when :darwin then Darwin.new
        when :linux then Linux.new
        else
          warn "Unknown platform '#{platform}', disabling"
          @disabled = true
          nil
        end
      end

      # @api private
      class Darwin
        def sample
          ps = `ps -A -o %cpu | awk '{s+=$1} END {print s}'`
          Float(ps.chomp) / 100 / Concurrent.processor_count
        end
      end

      # @api private
      class Linux
        def sample
          load_avg = IO.readlines('/proc/loadavg').first.split.first
          Float(load_avg) / 100 / Concurrent.processor_count
        end
      end
    end
  end
end
