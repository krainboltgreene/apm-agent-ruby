# frozen_string_literal: true

module ElasticAPM
  class Metrics
    RSpec.describe SystemMemory do
      let(:config) { Config.new }
      subject { described_class.new config }

      context 'macOS' do
        before { allow(Metrics).to receive(:platform) { :darwin } }

        it 'knows total memory' do
          expect_any_instance_of(SystemMemory::Darwin)
            .to receive(:`) { "hw.memsize: 17179869184\n" }

          expect(subject.total).to eq 17_179_869_184
        end

        it 'knows free memory' do
          expect_any_instance_of(SystemMemory::Darwin)
            .to receive(:`) do
              "Pages free:                              152190.\n"
            end

          expect(subject.free).to eq 623_370_240
        end
      end

      context 'linux' do
        before { allow(Metrics).to receive(:platform) { :linux } }

        it 'knows total memory' do
          expect_any_instance_of(SystemMemory::Linux)
            .to receive(:`) { "3947960\n" }

          expect(subject.total).to eq 3_947_960_000
        end

        it 'knows free memory' do
          expect_any_instance_of(SystemMemory::Linux)
            .to receive(:`) { "686352\n" }

          expect(subject.free).to eq 686_352_000
        end
      end
    end
  end
end
