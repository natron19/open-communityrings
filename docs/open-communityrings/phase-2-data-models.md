# Phase 2: Data Models & Migrations

**Goal:** Create the five domain models (`Profile`, `RingMap`, `Ring`, `Overlap`, `StarterInitiative`), their migrations, the `ring_helpers.rb` helper module, and all FactoryBot factories. After this phase the database schema is complete and all model specs pass.

---

## Files to Create

| Action | File |
|---|---|
| Create | `db/migrate/YYYYMMDD_create_profiles.rb` |
| Create | `db/migrate/YYYYMMDD_create_ring_maps.rb` |
| Create | `db/migrate/YYYYMMDD_create_rings.rb` |
| Create | `db/migrate/YYYYMMDD_create_overlaps.rb` |
| Create | `db/migrate/YYYYMMDD_create_starter_initiatives.rb` |
| Create | `app/models/profile.rb` |
| Create | `app/models/ring_map.rb` |
| Create | `app/models/ring.rb` |
| Create | `app/models/overlap.rb` |
| Create | `app/models/starter_initiative.rb` |
| Modify | `app/models/user.rb` |
| Create | `app/helpers/ring_helpers.rb` |
| Create | `spec/factories/profiles.rb` |
| Create | `spec/factories/ring_maps.rb` |
| Create | `spec/factories/rings.rb` |
| Create | `spec/factories/overlaps.rb` |
| Create | `spec/factories/starter_initiatives.rb` |
| Create | `spec/models/profile_spec.rb` |
| Create | `spec/models/ring_map_spec.rb` |
| Create | `spec/models/ring_spec.rb` |
| Create | `spec/models/overlap_spec.rb` |
| Create | `spec/models/starter_initiative_spec.rb` |

---

## Migrations

Generate with `rails generate migration`. All tables use UUID primary keys (`id: :uuid`) and require the `pgcrypto` extension (already enabled by the boilerplate).

### `create_profiles`

```ruby
create_table :profiles, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.text :life_context, null: false
  t.text :family_situation
  t.text :neighborhood
  t.text :work_occupation
  t.text :interests
  t.text :values
  t.integer :weekly_hours, null: false
  t.text :known_rings
  t.timestamps null: false
end
add_index :profiles, :user_id, unique: true
```

### `create_ring_maps`

```ruby
create_table :ring_maps, id: :uuid do |t|
  t.references :profile, null: false, foreign_key: true, type: :uuid
  t.datetime :generated_at, null: false
  t.datetime :overlaps_regenerated_at
  t.text :gemini_raw
  t.text :gemini_raw_overlaps
  t.timestamps null: false
end
add_index :ring_maps, :generated_at
```

### `create_rings`

```ruby
create_table :rings, id: :uuid do |t|
  t.references :ring_map, null: false, foreign_key: true, type: :uuid
  t.string :name, null: false
  t.string :ring_type, null: false
  t.text :description, null: false
  t.text :rationale, null: false
  t.boolean :is_priority, null: false, default: false
  t.integer :position, null: false
  t.string :source, null: false
  t.timestamps null: false
end
add_index :rings, [:ring_map_id, :position], unique: true
```

### `create_overlaps`

```ruby
create_table :overlaps, id: :uuid do |t|
  t.references :ring_map, null: false, foreign_key: true, type: :uuid
  t.references :ring_a, null: false, foreign_key: { to_table: :rings }, type: :uuid
  t.references :ring_b, null: false, foreign_key: { to_table: :rings }, type: :uuid
  t.text :shared_element, null: false
  t.text :cross_ring_idea, null: false
  t.timestamps null: false
end
add_index :overlaps, [:ring_map_id, :ring_a_id, :ring_b_id], unique: true
```

### `create_starter_initiatives`

```ruby
create_table :starter_initiatives, id: :uuid do |t|
  t.references :ring, null: false, foreign_key: true, type: :uuid
  t.text :goal, null: false
  t.text :activities, null: false
  t.text :expected_outcomes, null: false
  t.text :next_step, null: false
  t.timestamps null: false
end
```

Run: `rails db:migrate`

---

## Models

### `app/models/profile.rb`

```ruby
class Profile < ApplicationRecord
  belongs_to :user
  has_many :ring_maps, dependent: :destroy

  validates :life_context, presence: true, length: { minimum: 30, maximum: 1500 }
  validates :weekly_hours, presence: true, inclusion: { in: 1..40 }
  validates :user_id, uniqueness: true
  validates :family_situation,  length: { maximum: 1500 }, allow_blank: true
  validates :neighborhood,      length: { maximum: 1500 }, allow_blank: true
  validates :work_occupation,   length: { maximum: 1500 }, allow_blank: true
  validates :interests,         length: { maximum: 1500 }, allow_blank: true
  validates :values,            length: { maximum: 1500 }, allow_blank: true
  validates :known_rings,       length: { maximum: 1500 }, allow_blank: true
end
```

### `app/models/ring_map.rb`

```ruby
class RingMap < ApplicationRecord
  belongs_to :profile
  has_many :rings, dependent: :destroy
  has_many :overlaps, dependent: :destroy
  has_one :user, through: :profile

  validates :generated_at, presence: true

  default_scope { order(generated_at: :desc) }
end
```

### `app/models/ring.rb`

The fifteen allowed ring types:

```ruby
RING_TYPES = %w[
  family neighborhood civic workplace professional faith_or_values
  education sports_recreation arts_cultural health_wellness
  hobby_interest online_digital cause_based service_volunteer mentorship
].freeze
```

Full model:

```ruby
class Ring < ApplicationRecord
  belongs_to :ring_map
  has_many :starter_initiatives, dependent: :destroy
  has_many :overlaps_as_a, class_name: "Overlap", foreign_key: :ring_a_id, dependent: :destroy
  has_many :overlaps_as_b, class_name: "Overlap", foreign_key: :ring_b_id, dependent: :destroy

  RING_TYPES = %w[
    family neighborhood civic workplace professional faith_or_values
    education sports_recreation arts_cultural health_wellness
    hobby_interest online_digital cause_based service_volunteer mentorship
  ].freeze

  SOURCES = %w[ai_generated user_added].freeze

  validates :name, presence: true, length: { minimum: 2, maximum: 80 }
  validates :ring_type, inclusion: { in: RING_TYPES }
  validates :description, presence: true, length: { minimum: 10, maximum: 1500 }
  validates :rationale, presence: true, length: { minimum: 10, maximum: 500 }
  validates :position, presence: true, uniqueness: { scope: :ring_map_id }
  validates :source, inclusion: { in: SOURCES }

  default_scope { order(position: :asc) }

  def all_overlaps
    Overlap.where(ring_a_id: id).or(Overlap.where(ring_b_id: id))
  end
end
```

### `app/models/overlap.rb`

```ruby
class Overlap < ApplicationRecord
  belongs_to :ring_map
  belongs_to :ring_a, class_name: "Ring"
  belongs_to :ring_b, class_name: "Ring"

  validates :shared_element, presence: true
  validates :cross_ring_idea, presence: true
  validate :rings_must_differ
  validate :pair_unique_within_ring_map

  private

  def rings_must_differ
    errors.add(:ring_b_id, "must differ from ring_a_id") if ring_a_id == ring_b_id
  end

  def pair_unique_within_ring_map
    return if ring_a_id.blank? || ring_b_id.blank?
    duplicate = Overlap.where(ring_map_id: ring_map_id)
                       .where(ring_a_id: ring_a_id, ring_b_id: ring_b_id)
                       .where.not(id: id)
    errors.add(:base, "Ring pair already overlaps") if duplicate.exists?
  end
end
```

**Canonicalization rule:** Always store the smaller UUID as `ring_a_id` before saving. Enforce this in the controller (not the model) when creating Overlaps from parsed JSON, so deterministic uniqueness is maintained.

### `app/models/starter_initiative.rb`

```ruby
class StarterInitiative < ApplicationRecord
  belongs_to :ring

  validates :goal, presence: true, length: { minimum: 10, maximum: 300 }
  validates :activities, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :expected_outcomes, presence: true, length: { minimum: 10, maximum: 600 }
  validates :next_step, presence: true, length: { minimum: 10, maximum: 300 }
end
```

### `app/models/user.rb` — Add Association

Add to the existing User model:

```ruby
has_one :profile, dependent: :destroy
has_many :ring_maps, through: :profile
```

---

## Helper Module — `app/helpers/ring_helpers.rb`

Maps `ring_type` strings to human-readable labels and Bootstrap badge variants.

```ruby
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
```

Include in `ApplicationHelper`:

```ruby
# app/helpers/application_helper.rb
include RingHelpers
```

---

## FactoryBot Factories

### `spec/factories/profiles.rb`

```ruby
FactoryBot.define do
  factory :profile do
    association :user
    life_context    { "Mid-career developer in a walkable neighborhood, looking to be more rooted in the community after years of remote work." }
    family_situation { "Married with two school-age kids." }
    neighborhood    { "Older walkable neighborhood with a mix of long-time residents and newer arrivals." }
    work_occupation { "Senior software engineer at a remote-first company." }
    interests       { "Trail running, board games, neighborhood history." }
    values          { "Civic life, public schools, local community, showing up." }
    weekly_hours    { 4 }
    known_rings     { "Cedar Street block, school PTA, local running club" }
  end
end
```

### `spec/factories/ring_maps.rb`

```ruby
FactoryBot.define do
  factory :ring_map do
    association :profile
    generated_at  { Time.current }
    gemini_raw    { '{"rings":[],"overlaps":[],"starter_initiatives":[]}' }
  end
end
```

### `spec/factories/rings.rb`

```ruby
FactoryBot.define do
  factory :ring do
    association :ring_map
    sequence(:name)     { |n| "Ring #{n}" }
    ring_type           { "neighborhood" }
    description         { "A community of neighbors on the same block who know each other by name." }
    rationale           { "You live here and already know several neighbors." }
    is_priority         { false }
    sequence(:position) { |n| n }
    source              { "ai_generated" }

    trait :priority do
      is_priority { true }
    end

    trait :user_added do
      source { "user_added" }
    end
  end
end
```

### `spec/factories/overlaps.rb`

```ruby
FactoryBot.define do
  factory :overlap do
    association :ring_map
    association :ring_a, factory: :ring
    association :ring_b, factory: :ring
    shared_element  { "Families with school-age children living on the same block." }
    cross_ring_idea { "Organize a block-level school supply drive to bridge the neighborhood and education Rings." }
  end
end
```

### `spec/factories/starter_initiatives.rb`

```ruby
FactoryBot.define do
  factory :starter_initiative do
    association :ring
    goal              { "Host a small block gathering to introduce newer residents to long-time neighbors." }
    activities        { "1. Reserve the block park for a Sunday afternoon\n2. Print and distribute flyers to twenty nearby households\n3. Ask two long-time residents to share one story about the block's history" }
    expected_outcomes { "At least twelve households attend. Three new connections are made between newer and longer-term residents. One follow-up idea emerges organically from the conversation." }
    next_step         { "Check the city's park reservation portal this week and reserve a date two weeks out." }
  end
end
```

---

## RSpec Model Specs

### `spec/models/profile_spec.rb`

```ruby
RSpec.describe Profile, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:life_context) }
    it { is_expected.to validate_presence_of(:weekly_hours) }

    it "requires life_context to be at least 30 characters" do
      profile = build(:profile, life_context: "Too short")
      expect(profile).not_to be_valid
      expect(profile.errors[:life_context]).to be_present
    end

    it "requires weekly_hours to be between 1 and 40" do
      expect(build(:profile, weekly_hours: 0)).not_to be_valid
      expect(build(:profile, weekly_hours: 41)).not_to be_valid
      expect(build(:profile, weekly_hours: 1)).to be_valid
      expect(build(:profile, weekly_hours: 40)).to be_valid
    end

    it "enforces maximum length on optional text fields" do
      long_text = "a" * 1501
      %i[family_situation neighborhood work_occupation interests values known_rings].each do |field|
        profile = build(:profile, field => long_text)
        expect(profile).not_to be_valid, "Expected #{field} to fail with 1501 chars"
      end
    end

    it "allows blank optional text fields" do
      profile = build(:profile, family_situation: nil, neighborhood: nil)
      expect(profile).to be_valid
    end

    it "enforces uniqueness of user_id" do
      user = create(:user)
      create(:profile, user: user)
      duplicate = build(:profile, user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:ring_maps).dependent(:destroy) }

    it "destroys ring_maps when profile is destroyed" do
      profile = create(:profile)
      create(:ring_map, profile: profile)
      expect { profile.destroy }.to change(RingMap, :count).by(-1)
    end
  end
end
```

### `spec/models/ring_map_spec.rb`

```ruby
RSpec.describe RingMap, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:generated_at) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:profile) }
    it { is_expected.to have_many(:rings).dependent(:destroy) }
    it { is_expected.to have_many(:overlaps).dependent(:destroy) }

    it "cascades destroy through rings to starter_initiatives" do
      ring_map = create(:ring_map)
      ring = create(:ring, ring_map: ring_map)
      create(:starter_initiative, ring: ring)
      expect { ring_map.destroy }.to change(StarterInitiative, :count).by(-1)
    end
  end

  describe "default scope" do
    it "orders by generated_at descending" do
      profile = create(:profile)
      older = create(:ring_map, profile: profile, generated_at: 2.days.ago)
      newer = create(:ring_map, profile: profile, generated_at: 1.day.ago)
      expect(profile.ring_maps.first).to eq(newer)
    end
  end
end
```

### `spec/models/ring_spec.rb`

```ruby
RSpec.describe Ring, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:rationale) }
    it { is_expected.to validate_presence_of(:position) }

    it "validates ring_type is in the taxonomy" do
      expect(build(:ring, ring_type: "neighborhood")).to be_valid
      expect(build(:ring, ring_type: "invalid_type")).not_to be_valid
    end

    it "validates source is ai_generated or user_added" do
      expect(build(:ring, source: "ai_generated")).to be_valid
      expect(build(:ring, source: "user_added")).to be_valid
      expect(build(:ring, source: "other")).not_to be_valid
    end

    it "validates position uniqueness scoped to ring_map_id" do
      ring_map = create(:ring_map)
      create(:ring, ring_map: ring_map, position: 1)
      duplicate = build(:ring, ring_map: ring_map, position: 1)
      expect(duplicate).not_to be_valid
    end

    it "allows the same position on different ring_maps" do
      create(:ring, position: 1)
      ring = build(:ring, position: 1)
      expect(ring).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:ring_map) }
    it { is_expected.to have_many(:starter_initiatives).dependent(:destroy) }

    it "destroys overlaps when ring is destroyed" do
      ring_map = create(:ring_map)
      ring_a = create(:ring, ring_map: ring_map, position: 1)
      ring_b = create(:ring, ring_map: ring_map, position: 2)
      create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      expect { ring_a.destroy }.to change(Overlap, :count).by(-1)
    end
  end

  describe "default scope" do
    it "orders by position ascending" do
      ring_map = create(:ring_map)
      r3 = create(:ring, ring_map: ring_map, position: 3)
      r1 = create(:ring, ring_map: ring_map, position: 1)
      expect(ring_map.rings.first).to eq(r1)
    end
  end
end
```

### `spec/models/overlap_spec.rb`

```ruby
RSpec.describe Overlap, type: :model do
  let(:ring_map) { create(:ring_map) }
  let(:ring_a)   { create(:ring, ring_map: ring_map, position: 1) }
  let(:ring_b)   { create(:ring, ring_map: ring_map, position: 2) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:shared_element) }
    it { is_expected.to validate_presence_of(:cross_ring_idea) }

    it "rejects ring_a and ring_b being the same ring" do
      overlap = build(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_a)
      expect(overlap).not_to be_valid
      expect(overlap.errors[:ring_b_id]).to be_present
    end

    it "rejects duplicate ring pairs within the same ring_map" do
      create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      duplicate = build(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      expect(duplicate).not_to be_valid
    end

    it "allows the same ring pair in a different ring_map" do
      other_map = create(:ring_map, profile: ring_map.profile)
      other_a = create(:ring, ring_map: other_map, position: 1)
      other_b = create(:ring, ring_map: other_map, position: 2)
      create(:overlap, ring_map: ring_map, ring_a: ring_a, ring_b: ring_b)
      overlap = build(:overlap, ring_map: other_map, ring_a: other_a, ring_b: other_b)
      expect(overlap).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:ring_map) }
    it { is_expected.to belong_to(:ring_a).class_name("Ring") }
    it { is_expected.to belong_to(:ring_b).class_name("Ring") }
  end
end
```

### `spec/models/starter_initiative_spec.rb`

```ruby
RSpec.describe StarterInitiative, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:goal) }
    it { is_expected.to validate_presence_of(:activities) }
    it { is_expected.to validate_presence_of(:expected_outcomes) }
    it { is_expected.to validate_presence_of(:next_step) }

    it "enforces max length on goal" do
      expect(build(:starter_initiative, goal: "a" * 301)).not_to be_valid
    end

    it "enforces max length on activities" do
      expect(build(:starter_initiative, activities: "a" * 1001)).not_to be_valid
    end

    it "enforces max length on expected_outcomes" do
      expect(build(:starter_initiative, expected_outcomes: "a" * 601)).not_to be_valid
    end

    it "enforces max length on next_step" do
      expect(build(:starter_initiative, next_step: "a" * 301)).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:ring) }
  end
end
```

---

## Manual Test Checklist

After completing Phase 2, verify:

- [ ] `rails db:migrate` runs without errors
- [ ] `rails db:migrate:status` shows all five new migrations as "up"
- [ ] `rails console` — `Profile.new.valid?` returns false (no life_context)
- [ ] `rails console` — `Ring::RING_TYPES.length == 15` returns true
- [ ] `rails console` — `User.first.profile` returns nil (no profile yet)
- [ ] `bundle exec rspec spec/models/` — all model specs pass
- [ ] No N+1 warnings in development log when loading a Ring with `includes(:starter_initiatives)`
- [ ] `ring_type_label("neighborhood")` returns "Neighborhood" in a Rails console with `include RingHelpers`
