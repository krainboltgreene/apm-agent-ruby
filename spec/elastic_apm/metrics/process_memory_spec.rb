# frozen_string_literal: true

require 'forwardable'

module ElasticAPM
  class Metrics
    RSpec.describe ProcessMemory do
      let(:config) { Config.new }
      subject { described_class.new config }

      context 'macOS' do
        before { allow(Metrics).to receive(:platform) { :darwin } }

        it "get's memory used by process" do
          expect_any_instance_of(ProcessMemory::Darwin)
            .to receive(:`) { "  PID\n28382\n" }

          expect(subject.sample).to eq 28_382
        end
      end

      context 'Linux' do
        before { allow(Metrics).to receive(:platform) { :linux } }

        it "get's memory used by process" do
          expect(File).to receive(:open) do
            "VmPin:\t       0 kB\nVmHWM:\t   12104 kB\nVmRSS:\t   " \
            "12104 kB\nVmData:\t    8800 kB\nVmStk:\t    8188 kB\n"
          end

          expect(subject.sample).to eq 12_104
        end
      end
    end
  end
end
