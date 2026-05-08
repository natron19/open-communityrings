require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /profile" do
    context "when not signed in" do
      it "redirects to sign in" do
        get profile_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in without a profile" do
      before { sign_in_as(user) }

      it "redirects to edit" do
        get profile_path
        expect(response).to redirect_to(edit_profile_path)
      end
    end

    context "when signed in with a profile" do
      before do
        sign_in_as(user)
        create(:profile, user: user)
      end

      it "returns 200" do
        get profile_path
        expect(response).to have_http_status(:ok)
      end

      it "shows the user's life_context" do
        get profile_path
        expect(response.body).to include("Mid-career developer")
      end
    end
  end

  describe "GET /profile/edit" do
    context "when not signed in" do
      it "redirects to sign in" do
        get edit_profile_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in without a profile" do
      before { sign_in_as(user) }

      it "renders the new-profile form" do
        get edit_profile_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Build your Profile")
      end
    end

    context "when signed in with an existing profile" do
      before do
        sign_in_as(user)
        create(:profile, user: user)
      end

      it "renders the edit form" do
        get edit_profile_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Edit Profile")
      end
    end
  end

  describe "POST /profile" do
    before { sign_in_as(user) }

    context "with valid params" do
      let(:valid_params) do
        {
          profile: {
            life_context: "Mid-career developer looking to be more rooted in the community.",
            weekly_hours: 4
          }
        }
      end

      it "creates a Profile and redirects to dashboard" do
        expect { post profile_path, params: valid_params }
          .to change(Profile, :count).by(1)
        expect(response).to redirect_to(dashboard_path)
      end

      it "associates the profile with the current user" do
        post profile_path, params: valid_params
        expect(user.reload.profile).to be_present
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors when life_context is missing" do
        post profile_path, params: { profile: { weekly_hours: 4 } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
      end

      it "does not create a Profile" do
        expect {
          post profile_path, params: { profile: { life_context: "" } }
        }.not_to change(Profile, :count)
      end
    end
  end

  describe "PATCH /profile" do
    before do
      sign_in_as(user)
      create(:profile, user: user)
    end

    context "with valid params" do
      it "updates the profile and redirects to show" do
        patch profile_path, params: { profile: { weekly_hours: 8 } }
        expect(response).to redirect_to(profile_path)
        expect(user.profile.reload.weekly_hours).to eq(8)
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors" do
        patch profile_path, params: { profile: { weekly_hours: 100 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "profile isolation between users" do
    it "does not mix profiles between users" do
      sign_in_as(user)
      post profile_path, params: { profile: { life_context: "User one context here, enough characters.", weekly_hours: 3 } }

      sign_in_as(other_user)
      get profile_path
      expect(response).to redirect_to(edit_profile_path)
    end
  end
end
