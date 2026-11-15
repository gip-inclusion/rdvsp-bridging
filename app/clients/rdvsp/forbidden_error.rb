module Rdvsp
  # The agent's token is valid but RDV-SP refuses them this: an organisation they don't belong to
  class ForbiddenError < Error; end
end
