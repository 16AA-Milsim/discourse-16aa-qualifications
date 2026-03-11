# frozen_string_literal: true

module Discourse16aaQualifications
  class Configuration
    ADMIN_CONFIG_STORE_KEY = "admin-config-v1".freeze

    attr_reader :group_priority, :qualifications, :qualification_groups, :standalone_qualifications

    def self.load
      persisted = load_persisted_admin_config
      return build_from_raw_config(persisted) if persisted

      load_from_site_settings
    end

    def self.persist_admin_config!(group_priority:, qualifications:, qualification_groups:, standalone_qualifications:)
      payload = {
        "group_priority" => group_priority,
        "qualifications" => qualifications,
        "qualification_groups" => qualification_groups,
        "standalone_qualifications" => standalone_qualifications,
      }

      plugin_store.set(ADMIN_CONFIG_STORE_KEY, payload)
      payload
    end

    def self.sync_store_from_site_settings!
      config = load_from_site_settings
      persist_admin_config!(
        group_priority: config.group_priority,
        qualifications: config.qualifications,
        qualification_groups: config.qualification_groups,
        standalone_qualifications: config.standalone_qualifications,
      )
    end

    def self.clear_persisted_admin_config!
      plugin_store.delete(ADMIN_CONFIG_STORE_KEY)
    end

    def self.load_from_site_settings
      new(
        group_priority_json: SiteSetting.sixteen_aa_qualifications_group_priority,
        definitions_json: SiteSetting.sixteen_aa_qualifications_definitions,
        qualification_groups_json: SiteSetting.sixteen_aa_qualifications_group_definitions,
        standalone_json: SiteSetting.sixteen_aa_qualifications_standalone_definitions,
        member_group_name: SiteSetting.sixteen_aa_qualifications_member_group_name,
      )
    end

    def self.build_from_raw_config(payload)
      new(
        group_priority_json: payload["group_priority"],
        definitions_json: payload["qualifications"],
        qualification_groups_json: payload["qualification_groups"],
        standalone_json: payload["standalone_qualifications"],
        member_group_name: SiteSetting.sixteen_aa_qualifications_member_group_name,
      )
    end

    def self.load_persisted_admin_config
      payload = plugin_store.get(ADMIN_CONFIG_STORE_KEY)
      return nil unless payload.is_a?(Hash)

      normalized = {
        "group_priority" => payload["group_priority"] || payload[:group_priority],
        "qualifications" => payload["qualifications"] || payload[:qualifications],
        "qualification_groups" => payload["qualification_groups"] || payload[:qualification_groups],
        "standalone_qualifications" =>
          payload["standalone_qualifications"] || payload[:standalone_qualifications],
      }

      return nil if normalized.values.all?(&:nil?)

      normalized
    end

    def self.plugin_store
      @plugin_store ||= PluginStore.new(::Discourse16aaQualifications::PLUGIN_NAME)
    end

    def initialize(group_priority_json:, definitions_json:, qualification_groups_json:, standalone_json:, member_group_name:)
      @group_priority = normalize_group_priority(parse_array(group_priority_json))
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

    def normalize_group_priority(entries)
      entries.filter_map do |entry|
        next unless entry.is_a?(Hash)

        group = extract_string(entry, "group")
        next if group.blank?

        label = extract_string(entry, "label")

        {
          "group" => group,
          "label" => label.presence || group,
        }
      end
    end

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
      parsed =
        case raw
        when Array, Hash
          raw
        when String
          raw = raw.strip
          return [] if raw.blank?

          begin
            ::JSON.parse(raw)
          rescue JSON::ParserError
            return []
          end
        else
          return []
        end

      normalize_array(parsed)
    end

    def normalize_array(value)
      case value
      when Array
        normalize_array_entries(value)
      when Hash
        extract_indexed_hash_values(value)
      else
        []
      end
    end

    def normalize_array_entries(entries)
      if indexed_pairs_array?(entries)
        entries
          .sort_by { |(key, _)| key.to_i }
          .map { |(_, item)| normalize_json_value(item) }
      elsif entries.length == 1 && entries.first.is_a?(Hash) && indexed_hash?(entries.first)
        extract_indexed_hash_values(entries.first)
      else
        entries.map { |item| normalize_json_value(item) }
      end
    end

    def normalize_json_value(value)
      case value
      when Hash
        normalized =
          value.each_with_object({}) do |(key, nested), result|
            result[key.to_s] = normalize_json_value(nested)
          end

        indexed_hash?(normalized) ? extract_indexed_hash_values(normalized) : normalized
      when Array
        normalize_array_entries(value)
      else
        value
      end
    end

    def extract_indexed_hash_values(hash)
      return [] unless indexed_hash?(hash)

      hash
        .sort_by { |(key, _)| key.to_i }
        .map { |(_, item)| normalize_json_value(item) }
    end

    def indexed_pairs_array?(entries)
      entries.all? do |item|
        item.is_a?(Array) && item.length == 2 && numeric_key?(item.first)
      end
    end

    def indexed_hash?(hash)
      hash.is_a?(Hash) && hash.keys.present? && hash.keys.all? { |key| numeric_key?(key) }
    end

    def numeric_key?(key)
      key.to_s.match?(/\A\d+\z/)
    end
  end
end
