# frozen_string_literal: true

module Decidim
  module Proposals
    module Import
      module ProposalCreatorOverride
        extend ActiveSupport::Concern

        included do
          alias_method :original_produce, :produce
          alias_method :original_finish!, :finish!

          def produce
            resource.add_coauthor(context[:current_organization])
            resource
          end

          def finish!
            Decidim.traceability.perform_action!(:create, self.class.resource_klass, context[:current_user], visibility: "admin-only") do
              resource.save!
              resource
            end
            publish(resource)
          end

          private

          def publish(proposal)
            Decidim::EventsManager.publish(
              event: "decidim.events.proposals.proposal_published",
              event_class: Decidim::Proposals::PublishProposalEvent,
              resource: proposal,
              followers: proposal.participatory_space.followers,
              extra: {
                participatory_space: true
              }
            )
          end
        end
      end
    end
  end
end
