class LegalController < ApplicationController
  # Public pages: anyone can read them before signing up.
  skip_before_action :authenticate_user!

  def terms; end

  def privacy; end

  def cookie_policy; end

  def legal_notice; end
end
