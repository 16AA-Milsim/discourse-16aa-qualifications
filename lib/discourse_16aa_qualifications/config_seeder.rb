# frozen_string_literal: true

module Discourse16aaQualifications
  class ConfigSeeder
    EMPTY_COLOR_MIGRATION_KEY = "empty-color-migration-v1".freeze
    GROUPS_TO_RECOLOR = %w[soldiering marksmanship].freeze
    TARGET_EMPTY_COLOR = "--16aa-qual-yellow".freeze
    LEGACY_EMPTY_COLOR = "--16aa-qual-red".freeze

    class << self
      def seed_if_needed!
        defaults = load_defaults
        seed_setting(
          "sixteen_aa_qualifications_definitions",
          default_definitions(defaults),
        )
        seed_setting(
          "sixteen_aa_qualifications_group_priority",
          defaults["group_priority"],
        )
        seed_setting(
          "sixteen_aa_qualifications_group_definitions",
          defaults["qualification_groups"],
        )
        seed_setting(
          "sixteen_aa_qualifications_standalone_definitions",
          defaults["standalone_qualifications"],
        )

        migrate_legacy_empty_colors!
      end

      def reset_to_defaults!
        defaults = load_defaults
        apply_setting(
          "sixteen_aa_qualifications_definitions",
          default_definitions(defaults),
        )
        apply_setting(
          "sixteen_aa_qualifications_group_priority",
          defaults["group_priority"],
        )
        apply_setting(
          "sixteen_aa_qualifications_group_definitions",
          defaults["qualification_groups"],
        )
        apply_setting(
          "sixteen_aa_qualifications_standalone_definitions",
          defaults["standalone_qualifications"],
        )
      end

      private

      def migrate_legacy_empty_colors!
        return if PluginStore.get(::Discourse16aaQualifications::PLUGIN_NAME, EMPTY_COLOR_MIGRATION_KEY)

        definitions = parse_setting_array(read_setting("sixteen_aa_qualifications_definitions"))
        changed = false

        definitions.each do |item|
          next unless item.is_a?(Hash)

          key = extract_value(item, "key")
          next unless GROUPS_TO_RECOLOR.include?(key)

          empty_color = extract_value(item, "empty_color")
          next unless empty_color == LEGACY_EMPTY_COLOR

          item["empty_color"] = TARGET_EMPTY_COLOR
          item.delete(:empty_color)
          changed = true
        end

        if changed
          apply_setting("sixteen_aa_qualifications_definitions", definitions)

          split = split_definitions(definitions)
          apply_setting("sixteen_aa_qualifications_group_definitions", split[:groups])
          apply_setting("sixteen_aa_qualifications_standalone_definitions", split[:standalone])
        end

        PluginStore.set(::Discourse16aaQualifications::PLUGIN_NAME, EMPTY_COLOR_MIGRATION_KEY, true)
      end

      def seed_setting(setting_name, value)
        return if value.blank?

        current = read_setting(setting_name)
        return if current.present?

        apply_setting(setting_name, value)
      end

      def apply_setting(setting_name, value)
        SiteSetting.set(setting_name, Array(value).to_json)
      end

      def load_defaults
        @defaults ||= begin
          path = File.expand_path("../../config/qualification_defaults.yml", __dir__)
          YAML.safe_load(File.read(path), permitted_classes: [Symbol], aliases: false) || {}
        rescue Errno::ENOENT, Psych::SyntaxError
          {}
        end
      end

      def default_definitions(defaults)
        definitions = defaults["qualifications"]
        return definitions if definitions.present?

        Array(defaults["qualification_groups"]) + Array(defaults["standalone_qualifications"])
      end

      def read_setting(setting_name)
        if SiteSetting.respond_to?(setting_name)
          SiteSetting.public_send(setting_name)
        else
          nil
        end
      end

      def parse_setting_array(raw)
        return raw if raw.is_a?(Array)
        return [] if raw.blank?

        parsed = ::JSON.parse(raw)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError
        []
      end

      def split_definitions(definitions)
        groups = []
        standalone = []

        definitions.each do |item|
          next unless item.is_a?(Hash)

          levels = extract_value(item, "levels")
          badge = extract_value(item, "badge")

          if levels.is_a?(Array)
            groups << item
          elsif badge.present?
            standalone << item
          end
        end

        { groups: groups, standalone: standalone }
      end

      def extract_value(item, key)
        item[key] || item[key.to_sym]
      end
    end
  end
end
