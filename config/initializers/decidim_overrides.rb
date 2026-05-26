# frozen_string_literal: true

# Wires concern-based overrides into Decidim core classes on every code reload.
# Place per-class override modules under app/<layer>/concerns/decidim/... (for
# controllers and models) or app/services/decidim/... (for services).
Rails.application.config.to_prepare do
  Decidim::ErrorsController.include(Decidim::ErrorsControllerOverride)
  Decidim::Devise::OmniauthRegistrationsController.include(Decidim::Devise::OmniauthRegistrationsControllerOverride)
  Decidim::Proposals::Import::ProposalCreator.include(Decidim::Proposals::Import::ProposalCreatorOverride)
end
