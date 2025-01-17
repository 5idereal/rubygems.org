module WebauthnVerifiable
  extend ActiveSupport::Concern

  def setup_webauthn_authentication(form_url:, session_options: {})
    return if @user.webauthn_credentials.none?

    @webauthn_options = @user.webauthn_options_for_get
    @webauthn_verification_url = form_url

    session[:webauthn_authentication] = {
      "challenge" => @webauthn_options.challenge
    }.merge(session_options)
  end

  def webauthn_credential_verified?
    @credential = WebAuthn::Credential.from_get(credential_params)

    @credential.verify(
      challenge,
      public_key: user_webauthn_credential.public_key,
      sign_count: user_webauthn_credential.sign_count
    )
    user_webauthn_credential.update!(sign_count: @credential.sign_count)

    true
  rescue WebAuthn::Error => e
    @webauthn_error = e.message
    false
  rescue ActionController::ParameterMissing
    @webauthn_error = t("credentials_required")
    false
  ensure
    session.delete(:webauthn_authentication)
  end

  private

  def user_webauthn_credential
    @user_webauthn_credential ||= @user.webauthn_credentials.find_by(
      external_id: @credential.id
    )
  end

  def challenge
    session.dig(:webauthn_authentication, "challenge")
  end

  def credential_params
    params.require(:credentials).permit(
      :id,
      :type,
      :rawId,
      response: %i[authenticatorData attestationObject clientDataJSON signature]
    )
  end
end
