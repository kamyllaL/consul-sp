class Edition::Legislation::TopicLevelsController < Edition::Legislation::BaseController

  before_action :load_process
  before_action :load_topic_level, only: [:edit, :update, :destroy]

  def new
    @topic_level = @process.topic_levels.new
  end

  def create
    @topic_level = @process.topic_levels.new(topic_level_params)

    if @topic_level.save
      redirect_to document_edition_legislation_process_topics_path,
        notice: t("admin.legislation.topic_levels.create.notice")
    else
      render :new
    end
  end

  def update
    if @topic_level.update(topic_level_params)
      redirect_to document_edition_legislation_process_topics_path,
        notice: t("admin.legislation.topic_levels.update.notice")
    else
      render :edit
    end
  end

  def destroy
    @topic_level.destroy!
    redirect_to document_edition_legislation_process_topics_path,
      notice: t("admin.legislation.topic_levels.delete.notice")
  end

  private

  def load_process
    @process = ::Legislation::Process.find(params[:process_id])
  end

  def load_topic_level
    @topic_level = ::Legislation::TopicLevel.find(params[:id])
  end

  def topic_level_params
    params.require(:legislation_topic_level).permit(
      [:title, evaluations_attributes: [:id, :title, :_destroy]]
    )
  end

end
