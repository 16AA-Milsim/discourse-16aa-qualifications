# frozen_string_literal: true

# name: discourse-16aa-qualifications
# about: Visual roster of qualifications for 16AA members
# version: 0.9.4
# authors: Codex & Darojax
# url: https://github.com/16aarapidreactionforce/discourse-16aa-qualifications

enabled_site_setting :sixteen_aa_qualifications_enabled

register_asset "stylesheets/common/qualifications.scss"
# register_asset "stylesheets/mobile/qualifications.scss"

register_svg_icon "id-card-clip"

require_relative "lib/engine"

after_initialize do
  ::Discourse16aaQualifications::ConfigSeeder.seed_if_needed!

  Discourse::Application.routes.append do
    mount ::Discourse16aaQualifications::Engine, at: "/16aa-qualifications"
    get "/qualifications" => "discourse_16aa_qualifications/qualifications#index"
    get "/qualifications.json" => "discourse_16aa_qualifications/qualifications#index", defaults: { format: :json }
  end

  schedule_roster_refresh = ->(force = false) do
    ::Discourse16aaQualifications::RosterCache.schedule_refresh!(force: force)
  end

  if ::Discourse16aaQualifications::RosterCache.fetch.blank?
    schedule_roster_refresh.call(true)
  end

  DiscourseEvent.on(:user_badge_granted) { schedule_roster_refresh.call }
  DiscourseEvent.on(:user_badge_revoked) { schedule_roster_refresh.call }
  DiscourseEvent.on(:user_added_to_group) { schedule_roster_refresh.call }
  DiscourseEvent.on(:user_removed_from_group) { schedule_roster_refresh.call }
  DiscourseEvent.on(:group_created) { schedule_roster_refresh.call }
  DiscourseEvent.on(:group_destroyed) { schedule_roster_refresh.call }
  DiscourseEvent.on(:group_updated) { schedule_roster_refresh.call }
  DiscourseEvent.on(:user_destroyed) { schedule_roster_refresh.call }
  DiscourseEvent.on(:user_updated) { schedule_roster_refresh.call }

  DiscourseEvent.on(:site_setting_changed) do |name, _old_value, _new_value|
    if name.to_s.start_with?("sixteen_aa_qualifications_")
      schedule_roster_refresh.call
    end
  end
end
