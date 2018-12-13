# frozen_string_literal: true

require 'spec_helper'
require 'elastic_apm/opentracing'

RSpec.describe 'OpenTracing bridge', :intercept do
  let(:tracer) { ::OpenTracing.global_tracer }

  before :context do
    ::OpenTracing.global_tracer = ElasticAPM::OpenTracing::Tracer.new
  end

  context 'without an agent' do
    it 'is a noop' do
      tracer.start_active_span('namest') do |scope|
        expect(scope).to be_a ElasticAPM::OpenTracing::Scope

        tracer.start_span('nested') do |span|
          expect(span).to be ::OpenTracing::Span::NOOP_INSTANCE

          '...'
        end
      end
    end
  end

  context 'with an APM Agent' do
    before { ElasticAPM.start }
    after { ElasticAPM.stop }

    describe '#start_span' do
      context 'as root' do
        subject! { tracer.start_span('namest') }

        it { should be_an ElasticAPM::OpenTracing::Span }
        its(:elastic_span) { should be_an ElasticAPM::Transaction }
        its(:context) { should be_an ElasticAPM::TraceContext }

        it 'is not active' do
          expect(tracer.active_span).to be nil
        end
      end

      context 'as a child' do
        let(:parent) { tracer.start_span('parent') }
        subject! { tracer.start_span('namest', child_of: parent) }

        its(:context) { should be parent.context }
      end
    end

    describe '#start_active_span' do
      context 'as root' do
        subject! { tracer.start_active_span('namest') }

        it { should be_an ElasticAPM::OpenTracing::Scope }
        its(:elastic_span) { should be_a ElasticAPM::Transaction }

        it 'is active' do
          expect(tracer.active_span).to be subject.span
        end
      end
    end

    describe '#inject' do
      let(:context) do
        ElasticAPM::TraceContext.parse(
          '00-11111111111111111111111111111111-2222222222222222-00'
        )
      end
      let(:carrier) { {} }

      subject { tracer.inject(context, format, carrier) }

      context 'Rack' do
        let(:format) { ::OpenTracing::FORMAT_RACK }

        it 'sets a header' do
          subject
          expect(carrier['elastic-apm-traceparent']).to eq context.to_header
        end
      end

      context 'Binary' do
        let(:format) { ::OpenTracing::FORMAT_BINARY }

        it 'warns about lack of support' do
          expect(tracer).to receive(:warn).with(/Only injection via/)
          subject
        end
      end
    end

    describe '#extract' do
      let(:carrier) do
        { 'elastic-apm-traceparent' =>
          '00-11111111111111111111111111111111-2222222222222222-00' }
      end

      subject { tracer.extract(format, carrier) }

      context 'Rack' do
        let(:format) { ::OpenTracing::FORMAT_RACK }

        it 'returns a trace context' do
          expect(subject).to be_a ElasticAPM::TraceContext
          expect(subject.trace_id).to eq '11111111111111111111111111111111'
        end
      end

      context 'Binary' do
        let(:format) { ::OpenTracing::FORMAT_BINARY }

        it 'warns about lack of support' do
          expect(tracer).to receive(:warn).with(/Only extraction from/)
          subject
        end
      end
    end
  end

  describe 'example', :intercept do
    before { ElasticAPM.start }
    after { ElasticAPM.stop }

    it 'traces nested spans' do
      OpenTracing.start_active_span(
        'operation_name',
        tags: { test: '0' }
      ) do |scope|
        expect(scope).to be_a(ElasticAPM::OpenTracing::Scope)
        expect(OpenTracing.active_span).to be scope.span
        expect(OpenTracing.active_span).to be_a ElasticAPM::OpenTracing::Span

        OpenTracing.start_active_span(
          'nested',
          tags: { test: '1' }
        ) do
          expect(OpenTracing.active_span).to_not be_nil
        end
      end

      expect(@intercepted.transactions.length).to be 1
      expect(@intercepted.spans.length).to be 1

      transaction, = @intercepted.transactions
      expect(transaction.context.tags).to match(test: '0')

      span, = @intercepted.spans
      expect(span.context.tags).to match(test: '1')
    end
  end
end
