require "rails_helper"

RSpec.describe "RingMaps", type: :request do
  let(:user)    { create(:user) }
  let(:profile) { create(:profile, user: user) }

  describe "POST /ring_maps" do
    context "when not signed in" do
      it "redirects to sign in" do
        post ring_maps_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in without a profile" do
      before { sign_in_as(user) }

      it "returns 404" do
        post ring_maps_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in with a profile and Gemini succeeds" do
      before do
        sign_in_as(user)
        profile
        gemini_returns(RingDiscoveryFixture::VALID_RESPONSE)
      end

      it "creates a RingMap" do
        expect { post ring_maps_path }.to change(RingMap, :count).by(1)
      end

      it "creates the correct number of Rings" do
        post ring_maps_path
        expect(user.profile.ring_maps.first.rings.count).to eq(5)
      end

      it "creates the correct number of Overlaps" do
        post ring_maps_path
        expect(user.profile.ring_maps.first.overlaps.count).to eq(2)
      end

      it "creates one StarterInitiative per priority Ring" do
        post ring_maps_path
        priority_rings = user.profile.ring_maps.first.rings.where(is_priority: true)
        expect(priority_rings.count).to eq(2)
        expect(StarterInitiative.count).to eq(2)
        priority_rings.each do |ring|
          expect(ring.starter_initiatives.count).to eq(1)
        end
      end

      it "stores the raw Gemini response in gemini_raw" do
        post ring_maps_path
        expect(user.profile.ring_maps.first.gemini_raw).to be_present
      end

      it "redirects to the new ring map" do
        post ring_maps_path
        expect(response).to redirect_to(ring_map_path(RingMap.last))
      end

      it "calls GeminiService.generate with ring_discovery_v1" do
        expect(GeminiService).to receive(:generate).with(
          hash_including(template: "ring_discovery_v1")
        ).and_return(RingDiscoveryFixture::VALID_RESPONSE)
        post ring_maps_path
      end
    end

    context "when Gemini raises BudgetExceededError" do
      before do
        sign_in_as(user)
        profile
        gemini_raises(GeminiService::BudgetExceededError)
      end

      it "does not create a RingMap" do
        expect { post ring_maps_path }.not_to change(RingMap, :count)
      end

      it "renders an error response" do
        post ring_maps_path
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when Gemini raises TimeoutError" do
      before do
        sign_in_as(user)
        profile
        gemini_raises(GeminiService::TimeoutError)
      end

      it "does not create a RingMap" do
        expect { post ring_maps_path }.not_to change(RingMap, :count)
      end
    end

    context "when Gemini returns malformed JSON" do
      before do
        sign_in_as(user)
        profile
        gemini_returns("This is not JSON")
      end

      it "does not create a RingMap" do
        expect { post ring_maps_path }.not_to change(RingMap, :count)
      end

      it "renders the parse error template" do
        post ring_maps_path
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("could not read")
      end
    end
  end

  describe "GET /ring_maps/:id" do
    let(:ring_map) { create(:ring_map, profile: profile) }

    before { sign_in_as(user) }

    it "returns 200 for the owner" do
      get ring_map_path(ring_map)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's ring map" do
      other = create(:user)
      sign_in_as(other)
      get ring_map_path(ring_map)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /ring_maps/:id/regenerate_overlaps" do
    let(:ring_map) { create(:ring_map, profile: profile) }
    let(:ring_a)   { create(:ring, ring_map: ring_map, position: 1) }
    let(:ring_b)   { create(:ring, ring_map: ring_map, position: 2) }

    let(:overlap_response) do
      JSON.generate({
        overlaps: [
          { ring_a_position: 1, ring_b_position: 2, shared_element: "Shared families.", cross_ring_idea: "Joint event." }
        ]
      })
    end

    before { sign_in_as(user) }

    it "replaces existing overlaps with regenerated ones" do
      ring_a; ring_b
      create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      gemini_returns(overlap_response)

      expect {
        post regenerate_overlaps_ring_map_path(ring_map)
      }.not_to change(Ring, :count)

      expect(ring_map.reload.overlaps.count).to eq(1)
      expect(ring_map.overlaps_regenerated_at).to be_present
      expect(ring_map.gemini_raw_overlaps).to be_present
    end

    it "does not touch Rings or StarterInitiatives" do
      ring = create(:ring, :priority, ring_map: ring_map, position: 1)
      create(:starter_initiative, ring: ring)
      gemini_returns('{"overlaps":[]}')

      expect { post regenerate_overlaps_ring_map_path(ring_map) }
        .not_to change(StarterInitiative, :count)
      expect { post regenerate_overlaps_ring_map_path(ring_map) }
        .not_to change(Ring, :count)
    end

    it "calls overlap_regeneration_v1" do
      ring_a; ring_b
      expect(GeminiService).to receive(:generate).with(
        hash_including(template: "overlap_regeneration_v1")
      ).and_return('{"overlaps":[]}')
      post regenerate_overlaps_ring_map_path(ring_map)
    end

    it "returns 404 for another user" do
      other = create(:user)
      sign_in_as(other)
      post regenerate_overlaps_ring_map_path(ring_map)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /ring_maps/:id" do
    let(:ring_map) { create(:ring_map, profile: profile) }

    before { sign_in_as(user) }

    it "destroys the ring map and redirects to dashboard" do
      ring_map
      expect { delete ring_map_path(ring_map) }.to change(RingMap, :count).by(-1)
      expect(response).to redirect_to(dashboard_path)
    end

    it "returns 404 if another user tries to delete" do
      other = create(:user)
      sign_in_as(other)
      delete ring_map_path(ring_map)
      expect(response).to have_http_status(:not_found)
    end
  end
end
