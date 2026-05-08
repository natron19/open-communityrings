module RingHelpers
  RING_TYPE_LABELS = {
    "family"            => "Family",
    "neighborhood"      => "Neighborhood",
    "civic"             => "Civic",
    "workplace"         => "Workplace",
    "professional"      => "Professional",
    "faith_or_values"   => "Faith / Values",
    "education"         => "Education",
    "sports_recreation" => "Sports & Rec",
    "arts_cultural"     => "Arts & Culture",
    "health_wellness"   => "Health & Wellness",
    "hobby_interest"    => "Hobby / Interest",
    "online_digital"    => "Online / Digital",
    "cause_based"       => "Cause-Based",
    "service_volunteer" => "Service / Volunteer",
    "mentorship"        => "Mentorship"
  }.freeze

  RING_TYPE_BADGE_VARIANTS = {
    "family"            => "secondary",
    "neighborhood"      => "info",
    "civic"             => "primary",
    "workplace"         => "dark",
    "professional"      => "dark",
    "faith_or_values"   => "light",
    "education"         => "warning",
    "sports_recreation" => "success",
    "arts_cultural"     => "danger",
    "health_wellness"   => "success",
    "hobby_interest"    => "info",
    "online_digital"    => "secondary",
    "cause_based"       => "warning",
    "service_volunteer" => "primary",
    "mentorship"        => "light"
  }.freeze

  def ring_type_label(ring_type)
    RING_TYPE_LABELS.fetch(ring_type, ring_type.humanize)
  end

  def ring_type_badge(ring_type)
    variant = RING_TYPE_BADGE_VARIANTS.fetch(ring_type, "secondary")
    content_tag(:span, ring_type_label(ring_type), class: "badge text-bg-#{variant}")
  end
end
