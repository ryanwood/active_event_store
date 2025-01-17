# frozen_string_literal: true

module ActiveEventStore
  using(Module.new {
    refine Hash do
      def symbolize_keys
        RubyEventStore::TransformKeys.symbolize(self)
      end
    end
  })

  # Custom mapper for RES events.
  #
  # See https://github.com/RailsEventStore/rails_event_store/blob/v0.35.0/ruby_event_store/lib/ruby_event_store/mappers/default.rb
  class Mapper
    def initialize(mapping:, serializer: ActiveEventStore.config.serializer)
      @serializer = serializer
      @mapping = mapping
    end

    def event_to_record(domain_event)
      # lazily add type to mapping
      # NOTE: use class name instead of a class to handle code reload
      # in development (to avoid accessing orphaned classes)
      mapping.register(domain_event.event_type, domain_event.class.name) unless mapping.exist?(domain_event.event_type)

      RubyEventStore::Record.new(
        event_id: domain_event.event_id,
        metadata: serializer.dump(domain_event.metadata.to_h),
        data: serializer.dump(domain_event.data),
        event_type: domain_event.event_type,
        timestamp: domain_event.timestamp,
        valid_at: domain_event.valid_at
      )
    end

    def record_to_event(record)
      event_class = mapping.fetch(record.event_type) {
        raise "Don't know how to deserialize event: \"#{record.event_type}\". " \
              "Add explicit mapping: ActiveEventStore.mapping.register \"#{record.event_type}\", \"<Class Name>\""
      }

      Object.const_get(event_class).new(
        **serializer.load(record.data).symbolize_keys,
        metadata: serializer.load(record.metadata).symbolize_keys,
        event_id: record.event_id
      )
    end

    private

    attr_reader :serializer, :mapping
  end
end
