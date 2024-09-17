class AddEthnicityAndGenderToLocalCensusRecords < ActiveRecord::Migration[5.1]
  def change
    add_column :local_census_records, :ethnicity, :string
    add_column :local_census_records, :gender, :string
  end
end
