# frozen_string_literal: true

module Discourse16aaQualifications
  class Configuration
    attr_reader :group_priority, :qualifications, :qualification_groups, :standalone_qualifications

    def self.load
      new(
        group_priority_json: SiteSetting.sixteen_aa_qualifications_group_priority,
        definitions_json: SiteSetting.sixteen_aa_qualifications_definitions,
        qualification_groups_json: SiteSetting.sixteen_aa_qualifications_group_definitions,
        standalone_json: SiteSetting.sixteen_aa_qualifications_standalone_definitions,
        member_group_name: SiteSetting.sixteen_aa_qualifications_member_group_name,
      )
    end

    def initialize(group_priority_json:, definitions_json:, qualification_groups_json:, standalone_json:, member_group_name:)
      @group_priority = parse_array(group_priority_json)
      raw_definitions = parse_array(definitions_json)
      if raw_definitions.blank?
        raw_definitions =
          parse_array(qualification_groups_json) + parse_array(standalone_json)
      end

      @qualifications = normalize_definitions(raw_definitions)
      @qualification_groups = @qualifications.select { |item| group_definition?(item) }
      @standalone_qualifications = @qualifications.select { |item| standalone_definition?(item) }
      @member_group_name = member_group_name.presence || "16AA_Member"
    end

    def member_group_name
      @member_group_name
    end

    def qualification_badge_names
      qualifications
        .flat_map do |item|
          if group_definition?(item)
            (item["levels"] || []).map { |level| level["badge"] }
          else
            item["badge"]
          end
        end
        .compact
        .uniq
    end

    def to_h
      {
        "group_priority" => group_priority,
        "qualifications" => qualifications,
        "qualification_groups" => qualification_groups,
        "standalone_qualifications" => standalone_qualifications,
        "member_group_name" => member_group_name,
      }
    end

    alias_method :as_json, :to_h

    private

    def normalize_definitions(entries)
      entries.filter_map do |entry|
        next unless entry.is_a?(Hash)

        normalized = {}
        normalized["key"] = extract_string(entry, "key")
        normalized["name"] = extract_string(entry, "name")
        normalized["tooltip"] = extract_string(entry, "tooltip")
        normalized["empty_color"] = extract_string(entry, "empty_color")

        levels = entry["levels"] || entry[:levels]
        if levels.is_a?(Array)
          normalized["levels"] = normalize_levels(levels)
          next if normalized["levels"].blank?
        else
          badge = extract_string(entry, "badge")
          next if badge.blank?

          normalized["badge"] = badge
          normalized["name"] ||= badge
        end

        normalized.compact
      end
    end

    def normalize_levels(levels)
      levels.filter_map do |level|
        next unless level.is_a?(Hash)

        badge = extract_string(level, "badge")
        next if badge.blank?

        label = extract_string(level, "label")

        {
          "badge" => badge,
          "label" => label.presence || badge,
        }
      end
    end

    def extract_string(source, key)
      value = source[key] || source[key.to_sym]
      string = value.is_a?(String) ? value.strip : value&.to_s&.strip
      string.presence
    end

    def group_definition?(definition)
      definition["levels"].is_a?(Array) && definition["levels"].present?
    end

    def standalone_definition?(definition)
      !group_definition?(definition)
    end

    def parse_array(raw)
      case raw
      when Array
        raw
      when String
        raw = raw.strip
        return [] if raw.blank?

        begin
          parsed = ::JSON.parse(raw)
          parsed.is_a?(Array) ? parsed : []
        rescue JSON::ParserError
          []
        end
      else
        []
      end
    end
  end
end
