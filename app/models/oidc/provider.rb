class OIDC::Provider < ApplicationRecord
  validate :issuer_match, if: :configuration
  before_validation -> { configuration&.expected_issuer = issuer }

  validates :configuration, nested: { with_contract: false }
  validates :issuer, uniqueness: { ignore_case: true }

  has_many :api_key_roles, class_name: "OIDC::ApiKeyRole", inverse_of: :provider, foreign_key: :oidc_provider_id, dependent: :nullify
  has_many :id_tokens, class_name: "OIDC::IdToken", inverse_of: :provider, foreign_key: :oidc_provider_id, dependent: :nullify

  class Configuration < ::OpenIDConnect::Discovery::Provider::Config::Response
    attr_optional required_attributes.delete(:authorization_endpoint)

    def valid?
      super
      errors.delete(:authorization_endpoint, :blank)
      errors.none?
    end
  end

  attribute :configuration, (Class.new(ActiveRecord::Type::Json) do
    def deserialize(value)
      super&.then { Configuration.new(_1.deep_symbolize_keys) }
    end
  end).new

  attribute :jwks, (Class.new(ActiveRecord::Type::Json) do
    def deserialize(value)
      JSON::JWK::Set.new(super)
    end
  end).new

  private

  def issuer_match
    return if issuer == configuration.issuer
    errors.add :configuration, "issuer (#{configuration.issuer}) does not match the provider issuer: #{issuer}"
  end
end