# frozen_string_literal: true

require "test_helper"
require "helpers/mocked_instrumentation_service"
require "html_pipeline/node_filter/image_max_width_filter"

class HTMLPipelineTest < Minitest::Test
  def setup
    @default_context = {}
    @pipeline = HTMLPipeline.new(text_filters: [TestTextFilter], default_context: @default_context)
  end

  def test_filter_instrumentation
    service = MockedInstrumentationService.new
    events = service.subscribe("call_filter.html_pipeline")
    @pipeline.instrumentation_service = service
    body = "hello"
    @pipeline.call(body)
    event, payload, = events.pop

    assert(event, "event expected")
    assert_equal("call_filter.html_pipeline", event)
    assert_equal(TestTextFilter.name, payload[:filter])
    assert_equal(@pipeline.class.name, payload[:pipeline])
    assert_equal(body.reverse, payload[:result][:output])
  end

  def test_pipeline_instrumentation
    service = MockedInstrumentationService.new
    events = service.subscribe("call_text_filters.html_pipeline")
    @pipeline.instrumentation_service = service
    body = "hello"
    @pipeline.call(body)
    event, payload, = events.pop

    assert(event, "event expected")
    assert_equal("call_text_filters.html_pipeline", event)
    assert_equal(@pipeline.text_filters.map(&:name), payload[:text_filters])
    assert_equal(@pipeline.class.name, payload[:pipeline])
    assert_equal(body.reverse, payload[:result][:output])
  end

  def test_default_instrumentation_service
    service = "default"
    HTMLPipeline.default_instrumentation_service = service
    pipeline = HTMLPipeline.new(text_filters: [], default_context: @default_context)

    assert_equal(service, pipeline.instrumentation_service)
  ensure
    HTMLPipeline.default_instrumentation_service = nil
  end

  def test_setup_instrumentation
    assert_nil(@pipeline.instrumentation_service)

    service = MockedInstrumentationService.new
    events = service.subscribe("call_text_filters.html_pipeline")
    name = "foo"
    @pipeline.setup_instrumentation(name, service: service)

    assert_equal(service, @pipeline.instrumentation_service)
    assert_equal(name, @pipeline.instrumentation_name)

    body = "foo"
    @pipeline.call(body)

    event, payload, = events.pop

    assert(event, "expected event")
    assert_equal(name, payload[:pipeline])
    assert_equal(body.reverse, payload[:result][:output])
  end

  def test_incorrect_text_filters
    assert_raises(HTMLPipeline::InvalidFilterError) do
      HTMLPipeline.new(text_filters: [HTMLPipeline::NodeFilter::MentionFilter], default_context: @default_context)
    end
  end

  def test_incorrect_convert_filter
    assert_raises(HTMLPipeline::InvalidFilterError) do
      HTMLPipeline.new(convert_filter: HTMLPipeline::NodeFilter::ImageMaxWidthFilter, default_context: @default_context)
    end
  end

  def test_convert_filter_needed_for_text_and_html_filters
    assert_raises(HTMLPipeline::InvalidFilterError) do
      HTMLPipeline.new(
        text_filters: [TestTextFilter],
        node_filters: [
          HTMLPipeline::NodeFilter::MentionFilter.new,
        ],
        default_context: @default_context,
      )
    end
  end

  def test_incorrect_node_filters
    assert_raises(HTMLPipeline::InvalidFilterError) do
      HTMLPipeline.new(node_filters: [HTMLPipeline::ConvertFilter::MarkdownFilter], default_context: @default_context)
    end
  end
end
