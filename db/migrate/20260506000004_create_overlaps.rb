class CreateOverlaps < ActiveRecord::Migration[8.1]
  def change
    create_table :overlaps, id: :uuid do |t|
      t.references :ring_map, null: false, foreign_key: true, type: :uuid
      t.references :ring_a, null: false, foreign_key: { to_table: :rings }, type: :uuid
      t.references :ring_b, null: false, foreign_key: { to_table: :rings }, type: :uuid
      t.text :shared_element, null: false
      t.text :cross_ring_idea, null: false
      t.timestamps null: false
    end
    add_index :overlaps, [:ring_map_id, :ring_a_id, :ring_b_id], unique: true
  end
end
