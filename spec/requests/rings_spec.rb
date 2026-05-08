require "rails_helper"

RSpec.describe "Rings", type: :request do
  let(:user)     { create(:user) }
  let(:profile)  { create(:profile, user: user) }
  let(:ring_map) { create(:ring_map, profile: profile) }
  let(:ring)     { create(:ring, ring_map: ring_map, position: 1) }

  describe "POST /ring_maps/:ring_map_id/rings" do
    context "when not signed in" do
      it "redirects to sign in" do
        post ring_map_rings_path(ring_map), params: { ring: { name: "New Ring" } }
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "creates a Ring with source user_added and the next position" do
        ring  # ensure ring_map exists with one ring
        expect {
          post ring_map_rings_path(ring_map),
               params: { ring: { name: "New neighborhood ring", ring_type: "neighborhood", description: "A small group of neighbors on Cedar Street.", rationale: "You have lived here for three years." } },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Ring, :count).by(1)

        new_ring = Ring.last
        expect(new_ring.source).to eq("user_added")
        expect(new_ring.position).to eq(2)
      end

      it "returns a Turbo Stream response" do
        post ring_map_rings_path(ring_map),
             params: { ring: { name: "New Ring", ring_type: "neighborhood", description: "Some neighbors.", rationale: "You live there." } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "returns 404 when trying to add to another user's ring map" do
        other = create(:user)
        sign_in_as(other)
        post ring_map_rings_path(ring_map),
             params: { ring: { name: "Intrusion ring", ring_type: "civic", description: "Unauthorized.", rationale: "Not yours." } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /rings/:id" do
    before { sign_in_as(user) }

    it "updates the Ring and returns a Turbo Stream" do
      ring
      patch ring_path(ring),
            params: { ring: { name: "Updated name", ring_type: ring.ring_type, description: ring.description, rationale: ring.rationale } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(ring.reload.name).to eq("Updated name")
    end

    it "returns 404 if another user tries to edit" do
      ring
      other = create(:user)
      sign_in_as(other)
      patch ring_path(ring), params: { ring: { name: "Hacked" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /rings/:id" do
    before { sign_in_as(user) }

    it "destroys the Ring and cascades to overlaps and initiatives" do
      ring_b = create(:ring, ring_map: ring_map, position: 2)
      create(:overlap, ring_map: ring_map, ring_a: ring, ring_b: ring_b)
      create(:starter_initiative, ring: ring)

      expect { delete ring_path(ring), headers: { "Accept" => "text/vnd.turbo-stream.html" } }
        .to change(Ring, :count).by(-1)
        .and change(Overlap, :count).by(-1)
        .and change(StarterInitiative, :count).by(-1)
    end

    it "returns a Turbo Stream response" do
      delete ring_path(ring), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "returns 404 if another user tries to delete" do
      other = create(:user)
      sign_in_as(other)
      delete ring_path(ring)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /rings/:id/toggle_priority" do
    before { sign_in_as(user) }

    it "flips is_priority and does not call Gemini" do
      expect(GeminiService).not_to receive(:generate)
      patch toggle_priority_ring_path(ring),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(ring.reload.is_priority).to be true
    end

    it "toggles back to false on second call" do
      ring.update!(is_priority: true)
      patch toggle_priority_ring_path(ring),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(ring.reload.is_priority).to be false
    end

    it "returns 404 if another user tries to toggle" do
      other = create(:user)
      sign_in_as(other)
      patch toggle_priority_ring_path(ring)
      expect(response).to have_http_status(:not_found)
    end
  end
end
