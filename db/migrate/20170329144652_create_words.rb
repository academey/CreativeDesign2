class CreateWords < ActiveRecord::Migration
  def change
    create_table :words do |t|
			t.string 	:name
			t.string	:meaning
			t.string	:example
			t.string	:pos
			t.integer :target
			
      t.timestamps null: false
    end
  end
end
