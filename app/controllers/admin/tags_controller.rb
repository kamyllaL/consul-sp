class Admin::TagsController < Admin::BaseController
  before_action :find_tag, only: [:edit, :update, :destroy]

  respond_to :html, :js

  KINDS = { "category" => "Tema",  "subprefecture" => "Subprefeitura", "district" => "Distrito" }.freeze

  def index
    @category_tags = Tag.category.page(params[:page])
    @subprefecture_tags = Tag.subprefecture.page(params[:page])
    @district_tags = Tag.district.page(params[:page])
    @tag = Tag.new
  end

  def create
    Tag.find_or_create_by!(name: tag_params["name"], kind: KINDS.key(tag_params["kind"]))

    redirect_to admin_tags_path, notice: t("admin.tags.create.notice")
  end

  def edit
  end

  def update
    @tag.update(tag_params)
    redirect_to admin_tags_path, notice: t("flash.actions.save_changes.notice")
  end

  def destroy
    @tag.destroy!
    redirect_to admin_tags_path
  end

  private

    def tag_params
      params.require(:tag).permit(:name, :kind)
    end

    def find_tag
      @tag = Tag.find(params[:id])
    end
end
