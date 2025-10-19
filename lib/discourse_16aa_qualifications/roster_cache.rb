# frozen_string_literal: true

require "time"

module Discourse16aaQualifications
  module RosterCache
    STORE_KEY = "roster_payload".freeze
    THROTTLE_KEY = "discourse-16aa-qualifications:roster-refresh-throttle".freeze
    THROTTLE_SECONDS = 60

    module_function

    def fetch
      payload = plugin_store.get(STORE_KEY)
      payload.is_a?(Hash) ? payload.deep_dup : nil
    end

    def fetch_or_build(configuration, guardian: nil)
      payload = fetch
      return payload if payload.present?

      refresh!(configuration: configuration, guardian: guardian)
    end

    def refresh!(configuration: nil, guardian: nil)
      configuration ||= Configuration.load
      builder_guardian = guardian || Guardian.new(nil)

      payload =
        RosterBuilder
          .new(configuration, guardian: builder_guardian)
          .build

      timestamp = Time.zone ? Time.zone.now : Time.now.utc
      payload["meta"] ||= {}
      payload["meta"]["refreshed_at"] = timestamp.utc.iso8601

      plugin_store.set(STORE_KEY, payload)
      reset_throttle!
      payload
    end

    def clear!
      plugin_store.delete(STORE_KEY)
      reset_throttle!
    end

    def schedule_refresh!(force: false)
      if force
        set_throttle!
        Jobs.enqueue(:refresh_16aa_qualifications_roster)
      elsif allow_enqueue?
        Jobs.enqueue(:refresh_16aa_qualifications_roster)
      end
    end

    def allow_enqueue?
      Discourse.redis.set(THROTTLE_KEY, "1", nx: true, ex: THROTTLE_SECONDS)
    end

    def set_throttle!
      Discourse.redis.set(THROTTLE_KEY, "1", ex: THROTTLE_SECONDS)
    end

    def reset_throttle!
      Discourse.redis.del(THROTTLE_KEY)
    end

    def plugin_store
      @plugin_store ||= PluginStore.new(::Discourse16aaQualifications::PLUGIN_NAME)
    end
  end
end
