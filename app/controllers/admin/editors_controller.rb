class Admin::EditorsController < Admin::BaseController
  load_and_authorize_resource

  def index
    @editors = @editors.page(params[:page])
  end

  def search
    @users = User.search(params[:name_or_email])
                 .includes(:editor)
                 .page(params[:page])
                 .for_render
  end

  def create
    @editor.user_id = params[:user_id]
    @editor.save!

    redirect_to admin_editors_path
  end

  def destroy
    @editor.destroy!
    redirect_to admin_editors_path
  end
end
