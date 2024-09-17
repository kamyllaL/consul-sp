class Edition::BaseController < ApplicationController
  layout "admin"

  before_action :authenticate_user!
  before_action :verify_editor

  skip_authorization_check

  private

    def verify_editor
      raise CanCan::AccessDenied unless current_user&.editor? || current_user&.administrator?
    end
end
