require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns 200" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "includes the app name from ENV" do
      get root_path
      expect(response.body).to include(ENV.fetch("APP_NAME", "CommunityRings Demo"))
    end

    it "includes the tagline from ENV" do
      get root_path
      expect(response.body).to include("Map your communities")
    end

    it "includes links to sign up and sign in" do
      get root_path
      expect(response.body).to include(sign_up_path)
      expect(response.body).to include(sign_in_path)
    end
  end
end
