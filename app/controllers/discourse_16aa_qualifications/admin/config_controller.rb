# frozen_string_literal: true

module Discourse16aaQualifications
  module Admin
    class ConfigController < ::Admin::AdminController
      requires_plugin Discourse16aaQualifications::PLUGIN_NAME

      def show
        config = Configuration.load
        render_json_dump(
          group_priority: config.group_priority,
          qualifications: config.qualifications,
        )
      end

      def update
        config_params = params.require(:config).permit!

        definitions = Array(config_params[:qualifications])

        SiteSetting.set(
          :sixteen_aa_qualifications_group_priority,
          serialize_setting(config_params[:group_priority]),
        )

        SiteSetting.set(
          :sixteen_aa_qualifications_definitions,
          serialize_setting(definitions),
        )

        split = split_definitions(definitions)
        SiteSetting.set(
          :sixteen_aa_qualifications_group_definitions,
          serialize_setting(split[:groups]),
        )
        SiteSetting.set(
          :sixteen_aa_qualifications_standalone_definitions,
          serialize_setting(split[:standalone]),
        )

        render json: success_payload
      end

      def reset
        ConfigSeeder.reset_to_defaults!
        render json: success_payload
      end

      private

      def success_payload
        config_hash = Configuration.load.to_h.slice(
          "group_priority",
          "qualifications",
        )

        {
          success: true,
          config: config_hash,
        }
      end

      def serialize_setting(value)
        Array(value).to_json
      end

      def split_definitions(definitions)
        groups = []
        standalone = []

        definitions.each do |item|
          next unless item.is_a?(Hash)

          levels = item["levels"] || item[:levels]
          badge = item["badge"] || item[:badge]

          if levels.is_a?(Array)
            groups << item
          elsif badge.present?
            standalone << item
          end
        end

        { groups: groups, standalone: standalone }
      end
    end
  end
end
