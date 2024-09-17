class RemoveFormulationDescriptionFromBudgets < ActiveRecord::Migration[5.1]
  def change
    remove_column :budgets, :description_formulation, :text
  end
end
