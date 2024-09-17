class CreateEditorLegislationProcesses < ActiveRecord::Migration[5.1]
  def change
    create_table :editor_legislation_processes do |t|
    	t.references :editor, foreign_key: true
    	t.references :legislation_process, foreign_key: true
    	
    	t.timestamps    	
    end
  end
end
