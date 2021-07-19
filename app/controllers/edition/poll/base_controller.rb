class Edition::Poll::BaseController < Edition::BaseController
	POLL_CONTROLLERS = ['booth_assignments', 'officer_assignments', 'recounts', 'electoral_colleges']
	OTHER_CONTROLLERS = ['questions', 'answers']
  helper_method :namespace

  before_action :authorize_editor

  private

    def namespace
    	if current_user.administrator?
      	"admin"
      elsif current_user.editor?
      	"edition"
      end
    end

    def authorize_editor
    	if current_user.editor? 
    		return if controller_name == 'polls' && ( action_name == 'index' || current_user.editor.poll_ids.include?(params[:id].to_i) )
    	elsif !current_user.administrator?
    		raise CanCan::AccessDenied.new
    	end
    end
end
