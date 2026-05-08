require "rails_helper"

RSpec.describe "Discovery flow", type: :system do
  let(:user) { create(:user, password: "password123") }

  before do
    driven_by(:rack_test)
    allow(GeminiService).to receive(:generate).and_return(RingDiscoveryFixture::VALID_RESPONSE)
    AiTemplate.find_or_create_by!(name: "ring_discovery_v1") do |t|
      t.description = "Test template"
      t.system_prompt = "You are a test assistant."
      t.user_prompt_template = "{{life_context}}"
      t.model = "gemini-2.5-flash"
      t.max_output_tokens = 500
      t.temperature = 0.5
    end
  end

  it "lets a user build a Profile and run Ring Discovery" do
    visit sign_in_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"

    expect(page).to have_current_path(dashboard_path)

    click_link "Build your Profile"
    expect(page).to have_current_path(edit_profile_path)
    expect(page).to have_content("Build your Profile")

    fill_in "Life context", with: "Mid-career developer in a walkable neighborhood, looking to be more rooted in the community after years of remote work."
    fill_in "Weekly hours available", with: "4"
    click_button "Build Profile"

    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_content("Run Ring Discovery")

    click_button "Run Ring Discovery"

    expect(page).to have_content("Your Ring Map")
    expect(page).to have_content("Cedar Street block")
    expect(page).to have_content("Lincoln Elementary parents")
    expect(page).to have_content("Overlaps")
    expect(page).to have_content("Starter Initiatives")
    expect(page).to have_content("Show raw response")
  end
end
