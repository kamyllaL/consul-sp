class CreateEditors < ActiveRecord::Migration[5.1]
  def change
    create_table :editors do |t|
    	t.belongs_to :user, index: true, foreign_key: true
    end
  end
end
