# frozen_string_literal: true

module Decidim
  module Airtable
    class ProcessImportRow < Decidim::Command
      class RowError < StandardError; end

      def initialize(import_configuration:, current_user:, mapped_record:)
        @import_configuration = import_configuration
        @current_user = current_user
        @mapped_record = mapped_record
      end

      def call
        raise RowError, "An importing user is required" unless importing_user_valid?

        raise_unsupported_mappings!

        operation = nil
        proposal = nil

        ActiveRecord::Base.transaction do
          proposal = existing_proposal
          operation = proposal ? :updated : :created
          proposal = proposal ? update_proposal(proposal) : create_proposal
          sync_tracking!(proposal)
        end

        broadcast(:ok, proposal:, operation:)
      rescue ActiveRecord::RecordInvalid, RowError => e
        sync_failure!(e.message)
        broadcast(:invalid, error: e.message)
      end

      private

      attr_reader :import_configuration, :current_user, :mapped_record

      def importing_user_valid?
        current_user.present? && current_user.organization == import_configuration.organization
      end

      def component
        mapped_record.dig(:proposal_data, :component)
      end

      def proposal_data
        mapped_record.fetch(:proposal_data)
      end

      def tracking_record
        @tracking_record ||= Decidim::Airtable::ImportRecord.find_by(
          import_configuration:,
          airtable_record_id: mapped_record.fetch(:airtable_record_id)
        )
      end

      def existing_proposal
        proposal = tracking_record&.proposal
        return unless proposal
        raise RowError, "Tracked proposal does not belong to the configured component" unless proposal.component == component

        proposal
      end

      def create_proposal
        creator = Decidim::Proposals::Import::ProposalCreator.new(proposal_data, creator_context)
        proposal = creator.produce
        apply_proposal_data(proposal, creating: true)
        creator.finish!
        proposal
      end

      def update_proposal(proposal)
        apply_proposal_data(proposal, creating: false)
        Decidim.traceability.perform_action!(:update, proposal, current_user) do
          proposal.save!
          proposal
        end
      end

      def creator_context
        {
          current_organization: import_configuration.organization,
          current_user:,
          current_component: component,
          current_participatory_space: component.participatory_space
        }
      end

      def apply_proposal_data(proposal, creating:)
        proposal.assign_attributes(proposal_attributes(proposal, creating:))
        apply_taxonomies(proposal, creating:)
        apply_state(proposal)
        apply_authors(proposal)
      end

      def proposal_attributes(proposal, creating:)
        attributes = proposal_data.except(:component, :state, :taxonomies)
        localized_attribute_keys = attributes.keys.select { |key| key.to_s.match?(%r{\A(title|body)/}) }
        attributes.except!(*localized_attribute_keys)

        [:title, :body].each do |attribute|
          localized_values = localized_values_for(attribute)
          next if localized_values.empty?

          existing_values = creating ? {} : proposal.public_send(attribute).to_h
          attributes[attribute] = existing_values.merge(localized_values)
        end
        attributes
      end

      def localized_values_for(attribute)
        prefix = "#{attribute}/"
        proposal_data.each_with_object({}) do |(key, value), values|
          key_string = key.to_s
          values[key_string.delete_prefix(prefix)] = value if key_string.start_with?(prefix)
        end
      end

      def apply_taxonomies(proposal, creating:)
        resolutions = resolve_auxiliary_mappings("taxonomy_root:")
        return if resolutions.empty?

        mapped_root_ids = resolutions.map { |resolution| resolution.fetch(:root_id) }.uniq
        retained = creating ? [] : proposal.taxonomies.reject { |taxonomy| mapped_root_ids.include?(taxonomy.root_taxonomy.id) }
        proposal.taxonomies = (retained + resolutions.flat_map { |resolution| resolution.fetch(:taxonomies) }).uniq
      end

      def apply_state(proposal)
        token = proposal_data[:state].presence
        return if token.blank?

        state = Decidim::Proposals::ProposalState.find_by(component:, token: token.to_s)
        raise RowError, "Unknown proposal state '#{token}' for the configured component" unless state

        proposal.proposal_state = state
      end

      def apply_authors(proposal)
        author_mappings.each do |mapping|
          lookup_by = mapping.dig(:metadata, "lookup_by") || mapping.fetch(:mapping).delete_prefix("authors_by_")
          author_values(mapping.fetch(:value)).each do |value|
            author = find_author(lookup_by, value)
            raise RowError, "Could not find a unique proposal author for '#{value}'" unless author

            proposal.add_coauthor(author)
          end
        end
      end

      def find_author(lookup_by, value)
        users = Decidim::User.where(organization: import_configuration.organization)
        case lookup_by
        when "email"
          users.where("LOWER(email) = ?", value.to_s.downcase).first
        when "nickname"
          users.where("LOWER(nickname) = ?", value.to_s.downcase).first
        end
      end

      def author_values(value)
        value.is_a?(Array) ? value.compact_blank : value.to_s.split(/[;,\n]/).map(&:strip).compact_blank
      end

      def resolve_auxiliary_mappings(prefix)
        auxiliary_mappings.select { |mapping| mapping.fetch(:mapping).start_with?(prefix) }.map do |mapping|
          root_id = mapping.dig(:metadata, "taxonomy_id").to_i
          root = Decidim::Taxonomy.for(import_configuration.organization).roots.find_by(id: root_id)
          raise RowError, "Configured taxonomy root is no longer available" unless root

          taxonomies = taxonomy_values(mapping.fetch(:value)).map do |value|
            match = Decidim::Taxonomy.for(import_configuration.organization).non_roots.part_of(root.id).find do |taxonomy|
              taxonomy.name.values.any? { |name| name.to_s.casecmp?(value.to_s.strip) }
            end
            raise RowError, "Could not match taxonomy '#{value}' under '#{root.translated_name}'" unless match

            match
          end

          { root_id:, taxonomies: }
        end
      end

      def taxonomy_values(value)
        value.is_a?(Array) ? value.compact_blank : [value]
      end

      def auxiliary_mappings
        mapped_record.fetch(:auxiliary_mappings, [])
      end

      def author_mappings
        auxiliary_mappings.select { |mapping| mapping.fetch(:mapping).start_with?("authors_by_") }
      end

      def unsupported_mappings
        auxiliary_mappings.reject do |mapping|
          mapping.fetch(:mapping).start_with?("taxonomy_root:", "authors_by_")
        end
      end

      def sync_tracking!(proposal)
        sync_tracking(status: "synced", proposal:)
      end

      def raise_unsupported_mappings!
        unsupported = unsupported_mappings
        return if unsupported.empty?

        raise RowError, "Unsupported configured mapping(s): #{unsupported.map { |mapping| mapping[:mapping] }.uniq.join(", ")}"
      end

      def sync_failure!(error)
        sync_tracking(status: "failed", proposal: tracking_record&.proposal, last_error: error)
      rescue ActiveRecord::RecordInvalid
        nil
      end

      def sync_tracking(status:, proposal:, last_error: nil)
        result = nil
        Decidim::Airtable::SyncImportRecord.call(
          import_configuration:,
          organization: import_configuration.organization,
          airtable_record_id: mapped_record.fetch(:airtable_record_id),
          row_checksum: mapped_record[:row_checksum],
          metadata: { "auxiliary_mappings" => auxiliary_mappings },
          proposal:,
          status:,
          last_error:
        ) do
          on(:ok) { |record| result = record }
          on(:invalid) { |record| raise ActiveRecord::RecordInvalid, record }
        end
        result
      end
    end
  end
end
