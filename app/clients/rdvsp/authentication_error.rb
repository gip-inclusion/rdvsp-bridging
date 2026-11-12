module Rdvsp
  # RDV-SP refused the grant or the token: an agent must authorize the bridge again
  class AuthenticationError < Error; end
end
