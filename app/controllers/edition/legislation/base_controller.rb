class Edition::Legislation::BaseController < Edition::BaseController
  include FeatureFlags

  feature_flag :legislation

  helper_method :namespace

  private

    def namespace
      "edition"
    end
end
