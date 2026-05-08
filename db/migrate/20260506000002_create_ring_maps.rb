class CreateRingMaps < ActiveRecord::Migration[8.1]
  def change
    create_table :ring_maps, id: :uuid do |t|
      t.references :profile, null: false, foreign_key: true, type: :uuid
      t.datetime :generated_at, null: false
      t.datetime :overlaps_regenerated_at
      t.text :gemini_raw
      t.text :gemini_raw_overlaps
      t.timestamps null: false
    end
    add_index :ring_maps, :generated_at
  end
end
