module Admin::LocalCensusRecords::ImportsHelper
  def errors_for(resource, field)
    if resource.errors.include? field
      tag.div class: "error float-left" do
        resource.errors[field].map(&:capitalize).join(". ")
      end
    end
  end

  def local_census_records_import_required_headers
    LocalCensusRecords::Import::ATTRIBUTES.to_sentence(last_word_connector: " e ")
  end
end
