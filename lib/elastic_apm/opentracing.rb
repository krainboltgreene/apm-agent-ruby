# frozen_string_literal: true

require 'opentracing'

module ElasticAPM
  module OpenTracing
    # @api private
    class Span
      def initialize(elastic_span)
        @elastic_span = elastic_span
      end

      attr_reader :elastic_span

      def context
        elastic_span.trace_context
      end

      def finish(end_time: Time.now)
        return unless @elastic_span

      end
    end

    # @api private
    class SpanContext
      def initialize(trace_context)
        @trace_context = trace_context
      end

      attr_accessor :trace_context
    end

    # @api private
    class Scope
      def initialize(span, scope_stack, finish_on_close:)
        @span = span
        @scope_stack = scope_stack
        @finish_on_close = finish_on_close
      end

      attr_reader :span

      def elastic_span
        span.elastic_span
      end

      def close
        @span.finish if @finish_on_close
        @scope_stack.pop
      end
    end

    # @api private
    class ScopeStack
      KEY = :__elastic_apm_ot_scope_stack

      def push(scope)
        scopes << scope
      end

      def pop
        scopes.pop
      end

      def last
        scopes.last
      end

      private

      def scopes
        Thread.current[KEY] ||= []
      end
    end

    # @api private
    class ScopeManager
      def initialize
        @scope_stack = ScopeStack.new
      end

      def activate(span, finish_on_close: true)
        return active_scope if active_scope && active_scope.span == span
        scope = Scope.new(span, @scope_stack, finish_on_close: finish_on_close)
        @scope_stack.push scope
        scope
      end

      def active_scope
        @scope_stack.last
      end
    end

    # A custom tracer to use the OpenTracing API with ElasticAPM
    class Tracer
      def initialize
        @scope_manager = ScopeManager.new
      end

      attr_reader :scope_manager

      def active_span
        scope_manager.active_scope&.span
      end

      def start_span(
        operation_name,
        child_of: nil,
        references: nil,
        start_time: Time.now,
        tags: {},
        ignore_active_scope: false,
        **
      )
        context = prepare_span_context(
          child_of: child_of,
          references: references,
          ignore_active_scope: ignore_active_scope
        )

        elastic_span =
          if ElasticAPM.current_transaction
            ElasticAPM.start_span(operation_name, trace_context: context)
          else
            ElasticAPM.start_transaction(operation_name, trace_context: context)
          end

        unless elastic_span
          return ::OpenTracing::Span::NOOP_INSTANCE
        end

        elastic_span.start Util.micros(start_time)

        Span.new(elastic_span)
      end

      def start_active_span(
        operation_name,
        child_of: nil,
        references: nil,
        start_time: Time.now,
        tags: nil,
        ignore_active_scope: false,
        finish_on_close: true,
        **
      )
        span = start_span(
          operation_name,
          child_of: child_of,
          references: references,
          start_time: start_time,
          tags: tags,
          ignore_active_scope: ignore_active_scope
        )
        scope = scope_manager.activate(span, finish_on_close: finish_on_close)

        if block_given?
          begin
            yield scope
          ensure
            scope.close
          end
        end

        scope
      end

      private

      def prepare_span_context(
        child_of:,
        references:,
        ignore_active_scope:
      )
        context_from_child_of(child_of) ||
          context_from_references(references) ||
          context_from_active_scope(ignore_active_scope)
      end

      def context_from_child_of(child_of)
        return unless child_of
        child_of.respond_to?(:context) ? child_of.context : child_of
      end

      def context_from_references(references)
        return if !references || references.none?

        child_of = references.find do |reference|
          reference.type == ::OpenTracing::Reference::CHILD_OF
        end

        (child_of || references.first).context
      end

      def context_from_active_scope(ignore_active_scope)
        return if ignore_active_scope
        @scope_manager.active_scope&.span&.context
      end
    end
  end
end
