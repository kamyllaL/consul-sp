class Edition::Legislation::TopicsController < Edition::Legislation::BaseController
  load_and_authorize_resource :process, class: "Legislation::Process"
  load_and_authorize_resource :topic, class: "Legislation::Topic", through: :process

  before_action :load_topics, only: [:index, :document]
  before_action :load_topic_levels, only: :document
  before_action :load_topic_level, only: [:new, :create]
  before_action :load_associated_topic_level, only: [:edit, :update]
  before_action :load_parent, only: [:new, :create]

  def new
    @topic = @process.topics.new
  end

  def create
    @topic = @process.topics.new(topic_params)

    if @topic.save
      redirect_to document_edition_legislation_process_topics_path,
        notice: t("admin.legislation.topics.create.notice")
    else
      render :new
    end
  end

  def update
    if @topic.update(topic_params)
      redirect_to document_edition_legislation_process_topics_path,
        notice: t("admin.legislation.topics.update.notice")
    else
      render :edit
    end
  end

  def destroy
    @topic.destroy!
    redirect_to document_edition_legislation_process_topics_path,
      notice: t("admin.legislation.topics.delete.notice")
  end

  private

  def topic_params
    params.require(:legislation_topic).permit([
      :title, :description, :legislation_topic_level_id, :parent_id, :evaluable
    ])
  end

  def resource
    @topic || ::Legislation::Topic.find(params[:id])
  end

  def load_topics
    @topics = @process.root_topics
  end

  def load_topic_levels
    @topic_levels = @process.topic_levels
  end

  def load_topic_level
    @topic_level = @process.topic_levels.find(legislation_topic_level_id)
  end

  def load_associated_topic_level
    @topic_level = @topic.legislation_topic_level
  end

  def load_parent
    @parent = @process.topics.find(parent_id) if parent_id.present?
  end

  def parent_id
    topic_params[:parent_id]
  end

  def legislation_topic_level_id
    topic_params[:legislation_topic_level_id]
  end

end
