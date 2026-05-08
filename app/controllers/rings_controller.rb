class RingsController < ApplicationController
  before_action :require_authentication
  before_action :load_ring_map, only: [:create]
  before_action :load_ring,     only: [:show, :edit, :update, :destroy, :toggle_priority]

  def show
    # Renders rings/show.html.erb — used by Turbo Frame cancel navigation
  end

  def edit
    @ring_map = @ring.ring_map
  end

  def create
    @ring = @ring_map.rings.build(ring_params)
    @ring.source   = "user_added"
    @ring.position = (@ring_map.rings.maximum(:position) || 0) + 1

    if @ring.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to ring_map_path(@ring_map) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("ring-form-errors",
            partial: "rings/errors", locals: { ring: @ring })
        end
        format.html { redirect_to ring_map_path(@ring_map), alert: "Could not add Ring." }
      end
    end
  end

  def update
    @ring_map = @ring.ring_map
    if @ring.update(ring_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to ring_map_path(@ring_map) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("ring-#{@ring.id}-edit",
            partial: "rings/form", locals: { ring: @ring, ring_map: @ring_map })
        end
        format.html { redirect_to ring_map_path(@ring_map), alert: "Could not save Ring." }
      end
    end
  end

  def destroy
    @ring_map = @ring.ring_map
    @ring.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to ring_map_path(@ring_map), notice: "Ring removed." }
    end
  end

  def toggle_priority
    @ring_map = @ring.ring_map
    @ring.update!(is_priority: !@ring.is_priority)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to ring_map_path(@ring_map) }
    end
  end

  private

  def load_ring_map
    @ring_map = current_user.profile&.ring_maps&.find_by(id: params[:ring_map_id])
    render file: Rails.public_path.join("404.html"), status: :not_found unless @ring_map
  end

  def load_ring
    ring = Ring.find_by(id: params[:id])
    if ring && ring.ring_map.profile.user_id == current_user.id
      @ring = ring
    else
      render file: Rails.public_path.join("404.html"), status: :not_found
    end
  end

  def ring_params
    params.require(:ring).permit(:name, :ring_type, :description, :rationale)
  end
end
