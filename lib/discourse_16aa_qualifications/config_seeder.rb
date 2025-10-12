# frozen_string_literal: true

module Discourse16aaQualifications
  class ConfigSeeder
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
    end
  end
end
