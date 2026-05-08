class RingMapsController < ApplicationController
  before_action :require_authentication
  before_action :load_profile, only: [:create]
  before_action :load_ring_map, only: [:show, :destroy, :regenerate_overlaps]

  def create
    result = GeminiService.generate(
      template: "ring_discovery_v1",
      variables: {
        life_context:     @profile.life_context,
        family_situation: @profile.family_situation.to_s,
        neighborhood:     @profile.neighborhood.to_s,
        work_occupation:  @profile.work_occupation.to_s,
        interests:        @profile.interests.to_s,
        values:           @profile.values.to_s,
        weekly_hours:     @profile.weekly_hours.to_s,
        known_rings:      @profile.known_rings.to_s
      }
    )

    if @profile.known_rings.to_s.length > 600
      Rails.logger.warn("[RingMapsController] known_rings exceeds 600 chars for profile #{@profile.id}; model may drop user-named Rings")
    end

    ring_map = persist_ring_map!(result, @profile)
    redirect_to ring_map_path(ring_map), notice: "Your Ring map is ready."

  rescue GeminiService::BudgetExceededError
    flash.now[:alert] = "You have reached your daily AI call limit. Try again tomorrow."
    render partial: "shared/ai_error", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity
  rescue GeminiService::GatekeeperError
    flash.now[:alert] = "Your Profile contained content that could not be sent to the AI."
    render partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity
  rescue GeminiService::TimeoutError
    flash.now[:alert] = "The AI took too long to respond. Please try again."
    render partial: "shared/ai_error", locals: { error_type: :timeout }, status: :unprocessable_entity
  rescue GeminiService::GeminiError
    flash.now[:alert] = "Something went wrong with the AI call. Please try again."
    render partial: "shared/ai_error", locals: { error_type: :error }, status: :unprocessable_entity
  rescue JSON::ParserError
    flash.now[:alert] = "We could not parse the AI response. Please try again."
    render template: "ring_maps/parse_error", status: :unprocessable_entity
  end

  def show
    @rings        = @ring_map.rings.includes(:starter_initiatives)
    @overlaps     = @ring_map.overlaps.includes(:ring_a, :ring_b)
    @priority_rings = @rings.select(&:is_priority)
  end

  def destroy
    @ring_map.destroy
    redirect_to dashboard_path, notice: "Ring map deleted."
  end

  def regenerate_overlaps
    rings = @ring_map.rings.order(:position)
    rings_text = rings.map { |r| "Position #{r.position}. #{r.name} (#{r.ring_type}): #{r.description}" }.join("\n")

    result = GeminiService.generate(
      template: "overlap_regeneration_v1",
      variables: { rings_text: rings_text }
    )

    data = JSON.parse(strip_json_fences(result))
    position_to_ring = rings.index_by(&:position)

    ActiveRecord::Base.transaction do
      @ring_map.overlaps.destroy_all

      (data["overlaps"] || []).each do |overlap_data|
        ring_a = position_to_ring[overlap_data["ring_a_position"].to_i]
        ring_b = position_to_ring[overlap_data["ring_b_position"].to_i]
        next unless ring_a && ring_b
        next if ring_a.id == ring_b.id

        a_id, b_id = [ring_a.id, ring_b.id].sort
        @ring_map.overlaps.create!(
          ring_a_id: a_id,
          ring_b_id: b_id,
          shared_element: overlap_data["shared_element"],
          cross_ring_idea: overlap_data["cross_ring_idea"]
        )
      rescue ActiveRecord::RecordInvalid
        next
      end

      @ring_map.update!(
        overlaps_regenerated_at: Time.current,
        gemini_raw_overlaps: result
      )
    end

    redirect_to ring_map_path(@ring_map), notice: "Overlaps regenerated."

  rescue GeminiService::BudgetExceededError
    redirect_to ring_map_path(@ring_map), alert: "Daily AI call limit reached. Try again tomorrow."
  rescue GeminiService::TimeoutError
    redirect_to ring_map_path(@ring_map), alert: "Gemini timed out. Please try again."
  rescue GeminiService::GeminiError
    redirect_to ring_map_path(@ring_map), alert: "Something went wrong with the AI call. Please try again."
  rescue JSON::ParserError
    redirect_to ring_map_path(@ring_map), alert: "Could not parse the AI response. Please try again."
  end

  private

  def strip_json_fences(text)
    text.gsub(/\A```(?:json)?\s*/m, "").gsub(/\s*```\z/m, "").strip
  end

  def load_profile
    @profile = current_user.profile
    render file: Rails.public_path.join("404.html"), status: :not_found unless @profile
  end

  def load_ring_map
    @ring_map = current_user.profile&.ring_maps&.find_by(id: params[:id])
    render file: Rails.public_path.join("404.html"), status: :not_found unless @ring_map
  end

  def persist_ring_map!(json_string, profile)
    data = JSON.parse(strip_json_fences(json_string))

    ActiveRecord::Base.transaction do
      ring_map = profile.ring_maps.create!(
        generated_at: Time.current,
        gemini_raw:   json_string
      )

      position_to_ring = {}
      (data["rings"] || []).each do |ring_data|
        ring = ring_map.rings.create!(
          name:        ring_data["name"],
          ring_type:   ring_data["ring_type"],
          description: ring_data["description"],
          rationale:   ring_data["rationale"],
          is_priority: ring_data["is_priority"] == true,
          position:    ring_data["position"].to_i,
          source:      "ai_generated"
        )
        position_to_ring[ring_data["position"].to_i] = ring
      end

      (data["overlaps"] || []).each do |overlap_data|
        ring_a = position_to_ring[overlap_data["ring_a_position"].to_i]
        ring_b = position_to_ring[overlap_data["ring_b_position"].to_i]
        next unless ring_a && ring_b
        next if ring_a.id == ring_b.id

        a_id, b_id = [ring_a.id, ring_b.id].sort
        ring_map.overlaps.create!(
          ring_a_id:       a_id,
          ring_b_id:       b_id,
          shared_element:  overlap_data["shared_element"],
          cross_ring_idea: overlap_data["cross_ring_idea"]
        )
      rescue ActiveRecord::RecordInvalid
        next
      end

      (data["starter_initiatives"] || []).each do |init_data|
        ring = position_to_ring[init_data["ring_position"].to_i]
        next unless ring&.is_priority

        ring.starter_initiatives.create!(
          goal:              init_data["goal"],
          activities:        init_data["activities"],
          expected_outcomes: init_data["expected_outcomes"],
          next_step:         init_data["next_step"]
        )
      end

      ring_map
    end
  end
end
