class Legislation::DraftVersion::Exporter
  require "csv"

  include ExporterSpreadsheet

  def initialize(draft_version)
    @draft_version = draft_version
  end

  def to_csv
    CSV.generate(headers: true) do |csv|

      if @draft_version.annotations.empty?
        csv << NO_ANNOTATION_COLUMNS.map { |column| header_translation(column) }
        csv << csv_row(@draft_version)
      else
        csv << ANNOTATION_COLUMNS.map { |column| header_translation(column) }

        @draft_version.annotations.each do |annotation|
          csv << annotation_csv_row(@draft_version, annotation)
        end
      end
    end
  end

  private


  ANNOTATION_COLUMNS = %w(id title text comment user).freeze
  NO_ANNOTATION_COLUMNS = %w(id title comment).freeze


  def annotation_csv_row(draft_version, annotation)
    [
      draft_version.id.to_s,
      draft_version.title,
      sanitize_description(annotation.context),
      annotation.text,
      annotation.author.name
    ]
  end

    def csv_row(draft_version)
    [
      draft_version.id.to_s,
      draft_version.title,
      no_comments,
    ]
  end

  def no_comments
    I18n.t("legislation.draft_versions.spreedsheet.no_comments")
  end

  def header_translation(key)
    I18n.t(key, scope: 'legislation.draft_versions.spreedsheet')
  end
end
