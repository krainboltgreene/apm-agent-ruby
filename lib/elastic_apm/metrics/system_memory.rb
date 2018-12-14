# frozen_string_literal: true

require 'forwardable'

module ElasticAPM
  class Metrics
    # @api private
    class SystemMemory
      extend Forwardable

      def initialize(config)
        @config = config

        @disabled = false
        @sampler = sampler_for_platform(Metrics.platform)
      end

      def_delegators :@sampler, :total, :free

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
        def total
          sysctl = `sysctl hw.memsize`.split[1]
          Integer(sysctl)
        end

        def free
          vm_stat = `vm_stat | grep 'Pages free'`.split[2].delete('.')
          Integer(vm_stat) * 4096
        end
      end

      # @api private
      class Linux
        def total
          awk = `awk '/MemTotal/ {print $2}' /proc/meminfo`.chomp
          Integer(awk) * 1000
        end

        def free
          awk = `awk '/MemFree/ {print $2}' /proc/meminfo`.chomp
          Integer(awk) * 1000
        end
      end
    end
  end
end
