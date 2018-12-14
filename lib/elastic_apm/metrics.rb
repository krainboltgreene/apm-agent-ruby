# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Metrics
    def self.platform
      @platform ||= Gem::Platform.local.os.to_sym
    end
  end
end

require 'elastic_apm/metrics/system_cpu'
require 'elastic_apm/metrics/system_memory'
