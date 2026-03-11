# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Discourse16aaQualifications::Admin::Config", type: :request do
  fab!(:admin) { Fabricate(:admin) }

  let(:show_path) { "/admin/plugins/16aa-qualifications/config.json" }
  let(:update_path) { "/admin/plugins/16aa-qualifications/config" }

  before do
    sign_in(admin)
    Discourse16aaQualifications::Configuration.clear_persisted_admin_config!
  end

  it "serves plugin config from the dedicated config endpoint" do
    get show_path

    expect(response.status).to eq(200)

    body = response.parsed_body
    expect(body).to include("group_priority", "qualifications")
    expect(body).not_to include("id", "about", "admin_route")
  end

  it "persists updated config and returns it on a subsequent fetch" do
    payload = {
      config: {
        group_priority: [
          { group: "Coy_IC", label: "Coy IC" },
        ].to_json,
        qualifications: [
          { key: "navigation", name: "Nav", badge: "Navigation" },
        ].to_json,
      },
    }

    put update_path, params: payload

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("config", "group_priority")).to eq(
      [{ "group" => "Coy_IC", "label" => "Coy IC" }],
    )
    expect(response.parsed_body.dig("config", "qualifications")).to eq(
      [{ "key" => "navigation", "name" => "Nav", "badge" => "Navigation" }],
    )

    get show_path
    expect(response.status).to eq(200)
    expect(response.parsed_body["group_priority"]).to eq(
      [{ "group" => "Coy_IC", "label" => "Coy IC" }],
    )
    expect(response.parsed_body["qualifications"]).to eq(
      [{ "key" => "navigation", "name" => "Nav", "badge" => "Navigation" }],
    )
  end

  it "does not expose legacy write routes" do
    expect do
      Rails.application.routes.recognize_path(
        "/admin/plugins/16aa-qualifications",
        method: :put,
      )
    end.to raise_error(ActionController::RoutingError)

    expect do
      Rails.application.routes.recognize_path(
        "/admin/plugins/16aa-qualifications/reset",
        method: :post,
      )
    end.to raise_error(ActionController::RoutingError)
  end
end
