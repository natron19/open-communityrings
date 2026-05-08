class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }
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
  end
end
