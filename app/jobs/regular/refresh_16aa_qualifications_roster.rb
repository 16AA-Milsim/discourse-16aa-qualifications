# frozen_string_literal: true

module Jobs
  class Refresh16aaQualificationsRoster < ::Jobs::Base
    def execute(_args)
      ::Discourse16aaQualifications::RosterCache.refresh!
    rescue => e
      Rails.logger.error(
        "[discourse-16aa-qualifications] roster refresh failed: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      )
      ::Discourse16aaQualifications::RosterCache.reset_throttle!
      raise
    ensure
      ::Discourse16aaQualifications::RosterCache.reset_throttle!
    end
  end
end
