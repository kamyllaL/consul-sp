class Legislation::ProcessesController < Legislation::BaseController
  include RandomSeed

  has_filters %w[open past], only: :index
  has_filters %w[random winners], only: :proposals

  load_and_authorize_resource

  before_action :set_random_seed, only: :proposals

  def index
    @current_filter ||= "open"
    @processes = ::Legislation::Process.send(@current_filter).published
                 .not_in_draft.order(start_date: :desc).page(params[:page])
  end

  def show
    draft_version = @process.draft_versions.published.last
    allegations_phase = @process.allegations_phase

    if @process.homepage_enabled? && @process.homepage.present?
      render :show
    elsif allegations_phase.enabled? && allegations_phase.started? && draft_version.present?
      redirect_to legislation_process_draft_version_path(@process, draft_version)
    elsif @process.debate_phase.enabled?
      redirect_to debate_legislation_process_path(@process)
    elsif @process.proposals_phase.enabled?
      redirect_to proposals_legislation_process_path(@process)
    elsif @process.topics_phase.enabled?
      redirect_to topics_legislation_process_path(@process)
    else
      redirect_to allegations_legislation_process_path(@process)
    end
  end

  def debate
    set_process
    @phase = :debate_phase

    respond_to do |format|
      format.html do
        if @process.debate_phase.started? || (current_user&.administrator?)
          render :debate
        else
          render :phase_not_open
        end
      end
      format.csv do
        exporter = Legislation::Debate::Exporter.new(@process.questions)
        if csv_type == "answers"
          send_data exporter.answers_csv,
            filename: "respostas-fechadas-debate-#{@process.filename}.csv"
        elsif csv_type == "comments"
          send_data exporter.comments_csv,
            filename: "respostas-abertas-debate-#{@process.filename}.csv"
        end
      end
    end
  end

  def topics
    set_process
    @phase = :topics_phase

    if @process.topics_phase.started?
      @topics = @process.root_topics

      respond_to do |format|
        format.html do
          if @topics.any?
            render :topics
          else
            render :phase_empty
          end
        end
        format.csv do
          send_data Legislation::Topic::Exporter.new(@topics).to_csv,
            filename: "contribuicoes-revisao-#{@process.filename}.csv"
        end
      end
    else
      render :phase_not_open
    end
  end

  def draft_publication
    set_process
    @phase = :draft_publication

    if @process.draft_publication.started?
      draft_version = @process.draft_versions.published.last

      if draft_version.present?
        redirect_to legislation_process_draft_version_path(@process, draft_version)
      else
        render :phase_empty
      end
    else
      render :phase_not_open
    end
  end

  def allegations
    set_process
    @phase = :allegations_phase

    if @process.allegations_phase.started?
      draft_version = @process.draft_versions.published.last

      if draft_version.present?
        redirect_to legislation_process_draft_version_path(@process, draft_version)
      else
        render :phase_empty
      end
    else
      render :phase_not_open
    end
  end

  def result_publication
    set_process
    @phase = :result_publication

    if @process.result_publication.started?
      final_version = @process.final_draft_version

      if final_version.present?
        redirect_to legislation_process_draft_version_path(@process, final_version)
      else
        render :phase_empty
      end
    else
      render :phase_not_open
    end
  end

  def milestones
    @phase = :milestones
  end

  def proposals
    set_process
    @phase = :proposals_phase

    @proposals = ::Legislation::Proposal.where(process: @process)
    @proposals = @proposals.search(params[:search]) if params[:search].present?

    @current_filter = "winners" if params[:filter].blank? && @proposals.winners.any?

    if @current_filter == "random"
      @proposals = @proposals.sort_by_random(session[:random_seed]).page(params[:page])
    else
      @proposals = @proposals.send(@current_filter).page(params[:page])
    end

    if @process.proposals_phase.started? || (current_user&.administrator?)
      legislation_proposal_votes(@proposals)

      respond_to do |format|
        format.html do
          render :proposals
        end

        format.csv do
          all_proposals = ::Legislation::Proposal.where(process: @process)
          exporter = Legislation::Proposal::Exporter.new(all_proposals)
          if csv_type == "proposals"
            send_data exporter.to_csv,
              filename: "resultado-propostas-#{@process.filename}.csv"
          elsif csv_type == "proposal_comments"
            send_data exporter.comments_csv,
              filename: "comentarios-propostas-#{@process.filename}.csv"
          end
        end
      end
    else
      render :phase_not_open
    end
  end

  private

    def member_method?
      params[:id].present?
    end

    def set_process
      return if member_method?

      @process = ::Legislation::Process.find(params[:process_id])
    end

    def csv_type
      params[:type]
    end
end
