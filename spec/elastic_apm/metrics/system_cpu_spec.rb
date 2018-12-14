# frozen_string_literal: true

module ElasticAPM
  class Metrics
    RSpec.describe SystemCPU do
      let(:config) { Config.new }

      subject { described_class.new config }

      context 'OS X' do
        it 'gets CPU percentage' do
          allow(Metrics).to receive(:platform) { :darwin }

          expect(Concurrent).to receive(:processor_count) { 2 }
          expect_any_instance_of(SystemCPU::Darwin).to receive(:`) { "150.0\n" }

          expect(subject.sample).to eq 0.75
        end
      end

      context 'Linux' do
        it 'gets CPU percentage' do
          allow(Metrics).to receive(:platform) { :linux }

          expect(Concurrent).to receive(:processor_count) { 2 }
          expect(IO).to receive(:readlines) { ["150.00 0.00 0.00 1/403 210\n"] }

          expect(subject.sample).to eq 0.75
        end
      end
    end
  end
end
