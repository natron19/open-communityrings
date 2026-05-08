class CreateStarterInitiatives < ActiveRecord::Migration[8.1]
  def change
    create_table :starter_initiatives, id: :uuid do |t|
      t.references :ring, null: false, foreign_key: true, type: :uuid
      t.text :goal, null: false
      t.text :activities, null: false
      t.text :expected_outcomes, null: false
      t.text :next_step, null: false
      t.timestamps null: false
    end
  end
end
