# frozen_string_literal: true

module Discourse16aaQualifications
  class RosterBuilder
    PLUGIN_LOG_TAG = "[discourse-16aa-qualifications]".freeze
    RANK_SORT_LABELS = [
      ["Major", "Maj"],
      ["Captain", "Capt"],
      ["Squadron Leader", "Squadron_Leader", "Sqn Ldr"],
      ["Lieutenant", "Lt"],
      ["Flight Lieutenant", "Flight_Lieutenant", "Flt Lt"],
      ["Second Lieutenant", "Second_Lieutenant", "2Lt"],
      ["Flying Officer", "Flying_Officer", "Fg Off"],
      ["Pilot Officer", "Pilot_Officer", "Plt Off"],
      ["Acting Second Lieutenant", "Acting_Second_Lieutenant", "A/2Lt"],
      ["Warrant Officer Class 2", "Warrant_Officer_Class_2", "WO2"],
      ["Colour Sergeant", "Colour_Sergeant", "CSgt"],
      ["Staff Sergeant", "Staff_Sergeant", "SSgt"],
      ["Flight Sergeant Aircrew", "Flight_Sergeant_Aircrew", "FSAcr"],
      ["Sergeant", "Sgt"],
      ["Sergeant Aircrew", "Sergeant_Aircrew", "SAcr"],
      ["Acting Sergeant", "Acting_Sergeant", "A/Sgt"],
      ["Corporal", "Cpl"],
      ["Bombardier", "Bdr"],
      ["Acting Corporal", "Acting_Corporal", "A/Cpl"],
      ["Acting Bombardier", "Acting_Bombardier", "A/Bdr"],
      ["Lance Corporal", "Lance_Corporal", "LCpl"],
      ["Lance Bombardier", "Lance_Bombardier", "LBdr"],
      ["Acting Lance Corporal", "Acting_Lance_Corporal", "A/LCpl"],
      ["Acting Lance Bombardier", "Acting_Lance_Bombardier", "A/LBdr"],
      ["Private", "Pte"],
      ["Gunner", "Gnr"],
      ["Recruit", "Rec"],
    ].freeze
    RANK_PRIORITY_LOOKUP = begin
      mapping = {}
      RANK_SORT_LABELS.each_with_index do |labels, index|
        order = index + 1
        Array(labels).each do |label|
          normalized =
            label.to_s.strip.downcase.gsub(/[_\s]+/, " ")
          next if normalized.empty?

          mapping[normalized] ||= order
        end
      end
      mapping.freeze
    end
    RANK_FALLBACK_ORDER = RANK_PRIORITY_LOOKUP.values.max.to_i + 1

    def initialize(configuration, guardian: nil)
      @configuration = configuration
      @guardian = guardian || Guardian.new(nil)
    end

    def build
      base_group = Group.find_by(name: configuration.member_group_name)

      return empty_payload unless base_group

      members = fetch_members(base_group)
      return empty_payload if members.empty?

      relevant_group_names = configuration.group_priority.map { |item| item["group"] }.compact.uniq
      relevant_groups = Group.where(name: relevant_group_names).index_by(&:name)
      relevant_group_ids = relevant_groups.values.map(&:id)

      group_memberships = fetch_group_memberships(members, relevant_group_ids)
      badges_lookup = fetch_badge_lookup(configuration.qualification_badge_names)
      user_badges = fetch_user_badges(members, badges_lookup.values.map(&:id))

      grouped_users = build_grouped_users(
        members,
        relevant_groups,
        group_memberships,
        badges_lookup,
        user_badges,
      )

      {
        config: {
          group_priority: configuration.group_priority,
          qualifications: configuration.qualifications,
          qualification_groups: configuration.qualification_groups,
          standalone_qualifications: configuration.standalone_qualifications,
        },
        groups: grouped_users,
      }
    end

    private

    attr_reader :configuration, :guardian

    def empty_payload
      {
        config: {
          group_priority: configuration.group_priority,
          qualifications: configuration.qualifications,
          qualification_groups: configuration.qualification_groups,
          standalone_qualifications: configuration.standalone_qualifications,
        },
        groups: [],
      }
    end

    def fetch_members(base_group)
      base_group
        .users
        .activated
        .includes(:primary_group)
        .order(:username_lower)
    end

    def fetch_group_memberships(users, relevant_group_ids)
      return {} if relevant_group_ids.blank?

      GroupUser
        .where(user_id: users.map(&:id), group_id: relevant_group_ids)
        .includes(:group)
        .group_by(&:user_id)
    end

    def fetch_badge_lookup(names)
      return {} if names.blank?

      normalized = names.map { |name| name.to_s.presence }.compact
      return {} if normalized.blank?

      badge_records =
        Badge
          .where(name: normalized)
          .includes(:badge_type)
          .index_by(&:name)

      badge_records
    end

    def fetch_user_badges(users, badge_ids)
      return {} if badge_ids.blank?

      UserBadge
        .where(user_id: users.map(&:id), badge_id: badge_ids)
        .pluck(:user_id, :badge_id)
        .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(user_id, badge_id), acc|
          next if acc[user_id].include?(badge_id)

          acc[user_id] << badge_id
        end
    end

    def build_grouped_users(members, relevant_groups, group_memberships, badges_lookup, user_badges)
      lookup = configuration.group_priority.index_by { |item| item["group"] }

      group_buckets = lookup.transform_values do |item|
        label = item["label"].presence || item["group"]

        { "group" => item["group"], "label" => label, "users" => [] }
      end

      unassigned = { "group" => nil, "label" => I18n.t("js.sixteen_aa_qualifications.group_heading_unassigned"), "users" => [] }

      members.each do |user|
        user_group = determine_primary_group(user, lookup, relevant_groups, group_memberships)
        begin
          user_data = serialize_user(user, badges_lookup, user_badges[user.id] || [])
        rescue => e
          log(
            :error,
            "serialize_user failed for user #{user.id} (#{user.username}): #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
          )
          next
        end

        if user_group
          group_buckets[user_group]["users"] << user_data
        else
          unassigned["users"] << user_data
        end
      end

      group_buckets.each_value { |bucket| sort_users!(bucket["users"]) }
      sort_users!(unassigned["users"])

      ordered_groups = configuration.group_priority.map { |item| group_buckets[item["group"]] }
      ordered_groups << unassigned if unassigned["users"].present?
      ordered_groups.compact
    end

    def determine_primary_group(user, lookup, relevant_groups, group_memberships)
      memberships = group_memberships[user.id]
      return nil if memberships.blank?

      membership_ids = memberships.map(&:group_id)

      configuration.group_priority.each do |item|
        group_name = item["group"]
        group = relevant_groups[group_name]
        next unless group
        return group_name if membership_ids.include?(group.id)
      end

      nil
    end

    def serialize_user(user, badges_lookup, user_badges)
      qualifications = serialize_qualifications(badges_lookup, user_badges)
      grouped_qualifications = qualifications.select { |item| group_entry?(item) }
      standalone_qualifications = qualifications.select { |item| standalone_entry?(item) }

      base_user =
        BasicUserSerializer
          .new(user, scope: guardian, root: false)
          .as_json

      base_user["qualifications"] = qualifications
      base_user["qualification_groups"] = grouped_qualifications
      base_user["standalone_qualifications"] = standalone_qualifications
      base_user["sort_weight"] = calculate_sort_weight(grouped_qualifications)
      base_user
    end

    def serialize_qualifications(badges_lookup, user_badges)
      configuration.qualifications.map do |definition|
        if definition["levels"].is_a?(Array)
          serialize_group_definition(definition, badges_lookup, user_badges)
        else
          serialize_standalone_definition(definition, badges_lookup, user_badges)
        end
      end
    end

    def serialize_group_definition(definition, badges_lookup, user_badges)
      levels =
        Array(definition["levels"]).map do |level|
          level_data = level.is_a?(Hash) ? level.dup : { "badge" => level.to_s }
          badge_name = level_data["badge"] || level_data[:badge]
          badge_name = badge_name.to_s if badge_name
          level_data["badge"] = badge_name if badge_name
          badge = badge_name.present? ? badges_lookup[badge_name] : nil
          level_data["badge_details"] = serialize_badge(badge) if badge
          level_data
        end

      earned_level = nil
      levels.each do |level|
        badge_name = level["badge"] || level[:badge]
        badge_name = badge_name.to_s if badge_name
        next if badge_name.blank?

        badge = badges_lookup[badge_name]
        next unless badge&.id

        earned_level = level if user_badges.include?(badge.id)
      end

      {
        "key" => definition["key"],
        "name" => definition["name"],
        "empty_color" => definition["empty_color"],
        "levels" => levels,
        "earned" => earned_level,
      }
    end

    def calculate_sort_weight(qualification_groups)
      qualification_groups.filter_map do |group|
        earned = group["earned"]
        next unless earned

        levels = group["levels"] || []
        index = levels.find_index { |level| level["badge"] == earned["badge"] }
        index ? index + 1 : 0
      end.max || 0
    end

    def sort_users!(users)
      users.sort_by! do |user|
        [
          rank_sort_value(user),
          -(user["sort_weight"] || 0),
          user["username"].to_s.downcase,
        ]
      end
    end

    def rank_sort_value(user)
      return RANK_FALLBACK_ORDER unless user.is_a?(Hash)

      values_to_check = [
        user_value(user, :rank_prefix),
        user_value(user, :rank),
        user_value(user, :title),
        user_value(user, :primary_group_name),
        user_value(user, :primary_group),
        user_value(user, :display_name),
        user_value(user, :name),
        user_value(user, :username),
      ]

      values_to_check.each do |value|
        rank_order = detect_rank_order(value)
        return rank_order if rank_order
      end

      RANK_FALLBACK_ORDER
    end

    def user_value(user, key)
      return nil unless user.respond_to?(:[])

      user[key] || user[key.to_s] || user[key.to_sym]
    end

    def detect_rank_order(value)
      normalized_candidates(value).each do |candidate|
        order = RANK_PRIORITY_LOOKUP[candidate]
        return order if order
      end

      nil
    end

    def normalized_candidates(value)
      raw =
        value
          .to_s
          .strip
      return [] if raw.empty?

      normalized =
        raw
          .downcase
          .tr("_", " ")
          .gsub(/[^a-z0-9\/\s]+/, "")
          .squeeze(" ")
          .strip
      return [] if normalized.empty?

      parts = normalized.split(" ")

      candidates = []
      parts.each_index do |index|
        candidates << parts[0..index].join(" ")
      end
      candidates
    end

    def serialize_standalone_definition(definition, badges_lookup, user_badges)
      badge_name = (definition["badge"] || definition[:badge]).to_s
      badge = badge_name ? badges_lookup[badge_name] : nil
      badge_id = badge&.id
      earned = badge_id && user_badges.include?(badge_id)
      badge_details = serialize_badge(badge)

      {
        "key" => definition["key"],
        "name" => definition["name"],
        "badge" => badge_name,
        "empty_color" => definition["empty_color"],
        "badge_details" => badge_details,
        "earned" => !!earned,
      }
    end

    def group_entry?(item)
      item["levels"].is_a?(Array)
    end

    def standalone_entry?(item)
      !group_entry?(item)
    end

    def serialize_badge(badge)
      return nil unless badge

      {
        "id" => badge.id,
        "name" => badge.display_name || badge.name,
        "slug" => badge.slug,
        "description" => badge.description,
        "description_text" => strip_tags(badge.description),
        "image_url" => badge.image_url,
        "icon" => badge.icon,
        "url" => badge_url(badge),
      }
    end

    def strip_tags(value)
      return nil if value.blank?

      ApplicationController.helpers.strip_tags(value)
    end

    def log(level, message)
      Rails.logger.public_send(level, "#{PLUGIN_LOG_TAG} #{message}") if Rails.logger
    end

    def badge_url(badge)
      slug = badge.slug.presence || badge.name.to_s.parameterize.presence
      return nil unless badge.id

      path = "/badges/#{badge.id}"
      path = "#{path}/#{slug}" if slug
      Discourse.base_path.present? ? "#{Discourse.base_path}#{path}" : path
    end
  end
end
