require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
# Uncomment to use all instrumentation
# require 'opentelemetry/instrumentation/all'

def otel_config
  OpenTelemetry::SDK.configure do |c|
    c.service_name = 'tiny-ruby-trace-sample'
    c.service_version = '1.0.0'
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      OpenTelemetry::SemanticConventions::Resource::DEPLOYMENT_ENVIRONMENT => 'development',
      OpenTelemetry::SemanticConventions::Resource::HOST_NAME => Socket.gethostname
    )
    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: 'http://localhost:4318/v1/traces'
        )
      )
    )
    # Uncomment to use all instrumentation
    # c.use_all
  end
end

def main
  $stdout.sync = true

  tracer = OpenTelemetry.tracer_provider.tracer('tiny-ruby-trace-sample')
  print "start (PID #{$$}): "
  1.upto(20) do |i|
    tracer.in_span('main') do |span|
      span.set_attribute('myname', "parent-#{i}")
      span.set_attribute('parameter', Time.now.to_f.to_s)
      print '+'
      1.upto(4) do |i2|
        tracer.in_span('child') do |child_span|
          child_span.set_attribute('myname', "child-#{i}-#{i2}")
          child_span.set_attribute('parameter', Time.now.to_f.to_s)
          if i % 8 == 0 && i2 == 2
            error_msg = "forced error #{$$}"
            child_span.record_exception(StandardError.new(error_msg))
            child_span.status = OpenTelemetry::Trace::Status.error(error_msg)
            sleep(1 + rand(0.5))
            print 'E'
          else
            sleep(0.1 + rand(0.1))
            print '.'
          end
        end
      end
    end
  end
  OpenTelemetry.tracer_provider.shutdown
  puts ''
end

otel_config
main