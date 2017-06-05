module Gitlab
  module EtagCaching
    class Middleware
      RESERVED_WORDS = ProjectPathValidator::RESERVED.map { |word| "/#{word}/" }.join('|')
      ROUTE_REGEXP = Regexp.union(
        %r(^(?!.*(#{RESERVED_WORDS})).*/noteable/issue/\d+/notes\z)
      )

      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless enabled_for_current_route?(env)
        Gitlab::Metrics.add_event(:etag_caching_middleware_used)

        etag, cached_value_present = get_etag(env)
        if_none_match = env['HTTP_IF_NONE_MATCH']

        if if_none_match == etag
          Gitlab::Metrics.add_event(:etag_caching_cache_hit)
          [304, { 'ETag' => etag }, ['']]
        else
          track_cache_miss(if_none_match, cached_value_present)

          status, headers, body = @app.call(env)
          headers['ETag'] = etag
          [status, headers, body]
        end
      end

      private

      def enabled_for_current_route?(env)
        ROUTE_REGEXP.match(env['PATH_INFO'])
      end

      def get_etag(env)
        cache_key = env['PATH_INFO']
        store = Store.new
        current_value = store.get(cache_key)
        cached_value_present = current_value.present?

        unless cached_value_present
          current_value = store.touch(cache_key, only_if_missing: true)
        end

        [weak_etag_format(current_value), cached_value_present]
      end

      def weak_etag_format(value)
        %Q{W/"#{value}"}
      end

      def track_cache_miss(if_none_match, cached_value_present)
        if if_none_match.blank?
          Gitlab::Metrics.add_event(:etag_caching_header_missing)
        elsif !cached_value_present
          Gitlab::Metrics.add_event(:etag_caching_key_not_found)
        else
          Gitlab::Metrics.add_event(:etag_caching_resource_changed)
        end
      end
    end
  end
end
