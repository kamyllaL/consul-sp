class Legislation::DraftVersionsController < Legislation::BaseController
  load_and_authorize_resource :process
  load_and_authorize_resource :draft_version, through: :process

  def index
  end

  def show
    @draft_versions_list = visible_draft_versions
    @draft_version = @draft_versions_list.find(params[:id])

    exporter = Legislation::DraftVersion::Exporter.new(@draft_version)

    respond_to do |format|
      format.html do
      end
      format.csv do
        send_data exporter.to_csv,
          filename: "resultado-anotacoes-versao-#{@draft_version.title}.csv"
      end
    end
  end

  def changes
    @draft_versions_list = visible_draft_versions
    @draft_version = @draft_versions_list.find(params[:draft_version_id])
  end

  def go_to_version
    version = visible_draft_versions.find(params[:draft_version_id])

    if params[:redirect_action] == "changes"
      redirect_to legislation_process_draft_version_changes_path(@process, version, anchor: "process-list")
    elsif params[:redirect_action] == "annotations"
      redirect_to legislation_process_draft_version_annotations_path(@process, version, anchor: "process-list")
    else
      redirect_to legislation_process_draft_version_path(@process, version, anchor: "process-list")
    end
  end

  private

    def visible_draft_versions
      if current_user&.administrator?
        @process.draft_versions
      else
        @process.draft_versions.published
      end
    end
end
