require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to sign in" do
        get dashboard_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
