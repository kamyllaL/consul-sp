class Legislation::Proposal::Exporter
  require "csv"

  include ExporterSpreadsheet

  def initialize(proposals)
    @proposals = proposals
    @image_url = ''
    @documents = ['', '', ''] 
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << PROPOSALS_COLUMNS.map { |column| header_translation(column) }

      @proposals.each do |proposal|
        image_url(proposal.image)
        documents_url(proposal.documents)
        initialize_tags(proposal.tags)
        set_selected(proposal)
        csv << proposal_csv_row(proposal)
      end
    end
  end

  def comments_csv
    CSV.generate(headers: true) do |csv|
      csv << COMMENT_COLUMNS.map { |column| header_translation(column) }

      @proposals.each do |proposal|
        proposal.comments.each do |comment|
          csv << comment_csv_row(proposal, comment)
        end
      end
    end
  end

  private

  COMMENT_COLUMNS = %w(id title user comment).freeze
  PROPOSALS_COLUMNS = %w(id 
    created_at
    author
    title
    summary
    description
    video_url
    image_url
    first_document
    second_document
    third_document
    custom_tags
    subprefecture_tags
    district_tags
    cached_votes_up
    cached_votes_down
    cached_votes_total
    selected
  ).freeze

  def proposal_csv_row(proposal)
    [
      proposal.id.to_s,
      proposal.created_at,
      proposal.author.name,
      proposal.title,
      proposal.summary,
      sanitize_description(proposal.description),
      proposal.video_url,
      @image_url,
      @documents.first,
      @documents.second,
      @documents.third,
      @custom_tags,
      @subprefecture_tags,
      @district_tags,
      proposal.cached_votes_up,
      proposal.cached_votes_down,
      proposal.cached_votes_total,
      @selected
    ]
  end

  def image_url(image)
    @image_url = image.url if image.present?
  end

  def documents_url(documents)
    if documents.present?
      documents.each_with_index do |document, index|
        @documents[index] = document.url
      end
    end
  end

  def initialize_tags(tags)
    @custom_tags = []
    @subprefecture_tags = []
    @district_tags = []
    
    if tags.present?
      tags.each do |tag|
        case tag.kind
        when "category"
          @custom_tags << tag.name
        when "subprefecture"
          @subprefecture_tags << tag.name
        when "district"
          @district_tags << tag.name
        end
      end
    end
    format_tags
  end

  def format_tags
    if @custom_tags.empty?
      @custom_tags = ''
    else
      @custom_tags = @custom_tags.join(', ')
    end

    if @subprefecture_tags.empty?
      @subprefecture_tags = ''
    else
      @subprefecture_tags = @subprefecture_tags.join(', ')
    end

    if @district_tags.empty?
      @district_tags = ''
    else
      @district_tags = @district_tags.join(', ')
    end
  end

  def set_selected(proposal)
    if proposal.selected
      @selected = "Sim" 
    else
      @selected = "Não"
    end
  end

  def comment_csv_row(proposal, comment)
    [
      comment.id.to_s,
      proposal.title,
      comment.username,
      comment.body,
    ]
  end

  def header_translation(key)
    I18n.t(key, scope: 'legislation.proposals.spreadsheet')
  end
end
