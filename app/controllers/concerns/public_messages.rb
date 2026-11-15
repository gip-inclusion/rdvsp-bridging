# A page that tells someone outside the team what happened, and what to do
module PublicMessages
  private

  def message(title, text, status = :ok, success: false)
    render("shared/message", locals: { title:, text:, success: }, status:)
  end
end
