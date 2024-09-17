class RemoveConstraintsFromLocalCensusRecords < ActiveRecord::Migration[5.1]
  def change
    change_column_null :local_census_records, :date_of_birth, true
    change_column_null :local_census_records, :postal_code, true
  end
end
