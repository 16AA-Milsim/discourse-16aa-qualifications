# frozen_string_literal: true

# name: discourse-16aa-qualifications
# about: Visual roster of qualifications for 16AA members
# version: 0.1
# authors: Codex
# url: https://github.com/16aarapidreactionforce/discourse-16aa-qualifications

enabled_site_setting :sixteen_aa_qualifications_enabled

register_asset "stylesheets/common/qualifications.scss"
register_asset "stylesheets/mobile/qualifications.scss"

register_svg_icon "id-card-clip"

require_relative "lib/engine"

after_initialize do
  ::Discourse16aaQualifications::ConfigSeeder.seed_if_needed!

  Discourse::Application.routes.append do
    mount ::Discourse16aaQualifications::Engine, at: "/16aa-qualifications"
    get "/qualifications" => "discourse_16aa_qualifications/qualifications#index"
    get "/qualifications.json" => "discourse_16aa_qualifications/qualifications#index", defaults: { format: :json }
  end
end
