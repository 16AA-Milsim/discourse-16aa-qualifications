# frozen_string_literal: true

module Discourse16aaQualifications
  class QualificationsController < ::ApplicationController
    requires_plugin Discourse16aaQualifications::PLUGIN_NAME

    before_action :ensure_enabled!
    before_action :ensure_logged_in
    before_action :ensure_can_view!

    def index
      if request.format.json?
        config = Configuration.load
        roster = RosterCache.fetch_or_build(config, guardian: guardian)
        render_json_dump(roster)
      else
        render body: nil
      end
    end

    private

    def ensure_enabled!
      raise Discourse::NotFound unless SiteSetting.sixteen_aa_qualifications_enabled
    end

    def ensure_can_view!
      visibility = SiteSetting.sixteen_aa_qualifications_visibility

      return if visibility == "everyone"
      return if current_user&.staff?

      case visibility
      when "staff"
        raise Discourse::InvalidAccess
      when "trust_level_2"
        ensure_trust_level!(TrustLevel[2])
      when "trust_level_3"
        ensure_trust_level!(TrustLevel[3])
      when "trust_level_4"
        ensure_trust_level!(TrustLevel[4])
      when "groups"
        ensure_in_allowed_group!
      else
        raise Discourse::InvalidAccess
      end
    end

    def ensure_trust_level!(minimum)
      raise Discourse::InvalidAccess if current_user&.trust_level.to_i < minimum
    end

    def ensure_in_allowed_group!
      raise Discourse::InvalidAccess unless current_user

      allowed_groups = (SiteSetting.sixteen_aa_qualifications_allowed_groups || "")
        .split("|")
        .map(&:strip)
        .reject(&:blank?)

      if allowed_groups.blank?
        fallback = SiteSetting.sixteen_aa_qualifications_member_group_name
        allowed_groups = [fallback].compact_blank
      end

      raise Discourse::InvalidAccess if allowed_groups.blank?

      has_membership = current_user.groups.where(name: allowed_groups).exists?
      raise Discourse::InvalidAccess unless has_membership
    end
  end
end
