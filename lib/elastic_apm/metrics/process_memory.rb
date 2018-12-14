# frozen_string_literal: true

module ElasticAPM
  class Metrics
    # @api private
    class ProcessMemory
      class LookupError < InternalError; end

      extend Forwardable

      def initialize(config)
        @config = config
        @sampler = sampler_for_platform(Metrics.platform)
      end

      def_delegators :@sampler, :sample

      private

      def sampler_for_platform(platform)
        case platform
        when :darwin then Darwin.new
        when :linux then Linux.new
        else
          warn "Unknown platform '#{platform}', disabling"
          nil
        end
      end

      # @api private
      class Darwin
        def sample
          `ps -o rss #{$$}`.split("\n")[1].to_i
        end
      end

      # @api private
      class Linux
        def sample
          status = File.open("/proc/#{$$}/status", 'r') do |f|
            f.read_nonblock(4096)
          end

          unless status =~ /RSS:\s*(\d+) kB/i
            raise LookupError
          end

          Regexp.last_match(1).to_i
        end
      end
    end
  end
end
