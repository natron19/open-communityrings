class CreateRings < ActiveRecord::Migration[8.1]
  def change
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
  end
end
