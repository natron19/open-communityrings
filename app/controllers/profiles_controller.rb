class ProfilesController < ApplicationController
  before_action :require_authentication

  def show
    @profile = current_user.profile
    redirect_to edit_profile_path and return unless @profile
  end

  def edit
    @profile = current_user.profile || current_user.build_profile
  end

  def create
    @profile = current_user.build_profile(profile_params)
    if @profile.save
      redirect_to dashboard_path, notice: "Profile saved. You are ready to run Ring Discovery."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update
    @profile = current_user.profile
    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:profile).permit(
      :life_context, :family_situation, :neighborhood,
      :work_occupation, :interests, :values,
      :weekly_hours, :known_rings
    )
  end
end
