require 'ddtrace/contrib/patcher'
require 'ddtrace/ext/app_types'
require 'ddtrace/contrib/faraday/ext'

module Datadog
  module Contrib
    module Faraday
      # Patcher enables patching of 'faraday' module.
      module Patcher
        include Contrib::Patcher

        module_function

        def patched?
          done?(:faraday)
        end

        def patch
          do_once(:faraday) do
            begin
              require 'ddtrace/contrib/faraday/middleware'

              add_pin!
              add_middleware!

              # TODO: When Faraday pin is removed, set service info.
              # register_service(get_option(:service_name))
            rescue StandardError => e
              Datadog::Tracer.log.error("Unable to apply Faraday integration: #{e}")
            end
          end
        end

        def add_pin!
          DeprecatedPin
            .new(
              get_option(:service_name),
              app: Ext::APP,
              app_type: Datadog::Ext::AppTypes::WEB,
              tracer: get_option(:tracer)
            ).onto(::Faraday)
        end

        def add_middleware!
          ::Faraday::Middleware.register_middleware(ddtrace: Middleware)
        end

        def register_service(name)
          get_option(:tracer).set_service_info(
            name,
            Ext::APP,
            Datadog::Ext::AppTypes::WEB
          )
        end

        def get_option(option)
          Datadog.configuration[:faraday].get_option(option)
        end

        # Implementation of deprecated Pin, which raises warnings when accessed.
        # To be removed when support for Datadog::Pin with Faraday is removed.
        class DeprecatedPin < Datadog::Pin
          include Datadog::DeprecatedPin

          DEPRECATION_WARNING = %(
            Use of Datadog::Pin with Faraday is DEPRECATED.
            Upgrade to the configuration API using the migration guide here:
            https://github.com/DataDog/dd-trace-rb/releases/tag/v0.11.0).freeze

          def tracer=(tracer)
            Datadog.configuration[:faraday][:tracer] = tracer
          end

          def service_name=(service_name)
            Datadog.configuration[:faraday][:service_name] = service_name
          end

          def log_deprecation_warning(method_name)
            do_once(method_name) do
              Datadog::Tracer.log.warn("#{method_name}:#{DEPRECATION_WARNING}")
            end
          end
        end
      end
    end
  end
end
