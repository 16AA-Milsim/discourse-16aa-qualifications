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
        config_params = params.require(:config)
        raw_group_priority = config_params[:group_priority]
        raw_definitions = config_params[:qualifications]

        if raw_group_priority.nil? || raw_definitions.nil?
          render_json_error(
            I18n.t("sixteen_aa_qualifications.admin.invalid_config_payload"),
            status: 422,
          )
          return
        end

        group_priority = normalize_array_param(raw_group_priority)
        definitions = normalize_array_param(raw_definitions)

        if normalized_payload_lost?(raw_group_priority, group_priority) ||
             normalized_payload_lost?(raw_definitions, definitions) ||
             invalid_group_priority_payload?(group_priority, raw_group_priority) ||
             invalid_definitions_payload?(definitions, raw_definitions)
          render_json_error(
            I18n.t("sixteen_aa_qualifications.admin.invalid_config_payload"),
            status: 422,
          )
          return
        end

        SiteSetting.set(
          :sixteen_aa_qualifications_group_priority,
          serialize_setting(group_priority),
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

        Configuration.persist_admin_config!(
          group_priority: group_priority,
          qualifications: definitions,
          qualification_groups: split[:groups],
          standalone_qualifications: split[:standalone],
        )

        ::Discourse16aaQualifications::RosterCache.refresh!

        render json: success_payload
      end

      def reset
        ConfigSeeder.reset_to_defaults!
        Configuration.sync_store_from_site_settings!
        ::Discourse16aaQualifications::RosterCache.refresh!
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
        normalize_array_param(value).to_json
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

      def normalize_array_param(value)
        normalized = normalize_json_value(value)

        case normalized
        when Array
          normalized
        when Hash
          return [] if normalized.blank?
          return [] unless indexed_hash?(normalized)

          indexed_hash_values(normalized)
        when String
          parse_json_array(normalized)
        else
          []
        end
      end

      def normalize_json_value(value)
        case value
        when ActionController::Parameters
          normalize_json_value(value.to_unsafe_h)
        when Hash
          normalized =
            value.each_with_object({}) do |(key, nested), result|
              result[key.to_s] = normalize_json_value(nested)
            end

          if indexed_hash?(normalized)
            indexed_hash_values(normalized)
          else
            normalized
          end
        when Array
          value.map { |item| normalize_json_value(item) }
        else
          value
        end
      end

      def parse_json_array(raw)
        return [] if raw.blank?

        parsed = ::JSON.parse(raw)
        parsed.is_a?(Array) ? normalize_json_value(parsed) : []
      rescue JSON::ParserError
        []
      end

      def numeric_key?(key)
        key.to_s.match?(/\A\d+\z/)
      end

      def indexed_hash?(value)
        value.is_a?(Hash) && value.keys.present? && value.keys.all? { |key| numeric_key?(key) }
      end

      def indexed_hash_values(hash)
        hash
          .sort_by { |key, _| key.to_i }
          .map { |_, item| normalize_json_value(item) }
      end

      def normalized_payload_lost?(raw_value, normalized)
        return false unless normalized.empty?
        return false if raw_value.nil?

        case raw_value
        when String
          stripped = raw_value.strip
          stripped != "[]"
        when ActionController::Parameters, Hash
          raw_value.present?
        when Array
          raw_value.present?
        else
          raw_value.respond_to?(:present?) ? raw_value.present? : !!raw_value
        end
      end

      def invalid_group_priority_payload?(normalized, raw_value)
        return false if explicit_empty_array?(raw_value)
        return true if normalized.blank?

        normalized.any? do |item|
          !item.is_a?(Hash) || extract_string(item, "group").blank?
        end
      end

      def invalid_definitions_payload?(normalized, raw_value)
        return false if explicit_empty_array?(raw_value)
        return true if normalized.blank?

        normalized.any? { |item| invalid_definition_entry?(item) }
      end

      def invalid_definition_entry?(item)
        return true unless item.is_a?(Hash)

        levels = item["levels"] || item[:levels]
        badge = extract_string(item, "badge")

        if levels.is_a?(Array)
          levels.none? do |level|
            level.is_a?(Hash) && extract_string(level, "badge").present?
          end
        else
          badge.blank?
        end
      end

      def explicit_empty_array?(raw_value)
        raw_value.is_a?(String) && raw_value.strip == "[]"
      end

      def extract_string(source, key)
        return nil unless source.respond_to?(:[])

        value = source[key] || source[key.to_sym]
        value = value.to_s if !value.nil? && !value.is_a?(String)
        value&.strip&.presence
      end
    end
  end
end
