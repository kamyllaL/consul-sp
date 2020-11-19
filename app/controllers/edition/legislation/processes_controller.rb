class Edition::Legislation::ProcessesController < Edition::Legislation::BaseController
  include Translatable
  include ImageAttributes

  has_filters %w[active all], only: :index

  load_and_authorize_resource :process, class: "Legislation::Process"

  def index
    @processes = ::Legislation::Process.joins(:editors).where(editors: { id: current_user.id }).send(@current_filter).order(start_date: :desc)
                 .page(params[:page])
  end

  def update
    if @process.update(process_params)
      link = legislation_process_path(@process)
      redirect_back(fallback_location: (request.referer || root_path),
                    notice: t("admin.legislation.processes.update.notice", link: link))
    else
      flash.now[:error] = t("admin.legislation.processes.update.error")
      render :edit
    end
  end

  private

    def process_params
      params.require(:legislation_process).permit(allowed_params)
    end

    def allowed_params
      [
        :start_date,
        :end_date,
        :debate_start_date,
        :debate_end_date,
        :draft_start_date,
        :draft_end_date,
        :draft_publication_date,
        :allegations_start_date,
        :allegations_end_date,
        :proposals_phase_start_date,
        :proposals_phase_end_date,
        :topics_phase_start_date,
        :topics_phase_end_date,
        :result_publication_date,
        :debate_phase_enabled,
        :draft_phase_enabled,
        :allegations_phase_enabled,
        :proposals_phase_enabled,
        :topics_phase_enabled,
        :draft_publication_enabled,
        :result_publication_enabled,
        :published,
        :custom_list,
        :background_color,
        :font_color,
        translation_params(::Legislation::Process),
        documents_attributes: [:id, :title, :attachment, :cached_attachment, :user_id, :_destroy],
        image_attributes: image_attributes
      ]
    end

    def resource
      @process || ::Legislation::Process.find(params[:id])
    end
end
