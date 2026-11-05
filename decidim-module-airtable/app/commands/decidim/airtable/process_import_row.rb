# frozen_string_literal: true

module Decidim
  module Airtable
    class ProcessImportRow < Decidim::Command
      class RowError < StandardError; end

      def initialize(import_configuration:, current_user:, mapped_record:, attachment_downloader: Decidim::Airtable::AttachmentDownloader.new, airtable_client: Decidim::Airtable::Api::Client.new)
        @import_configuration = import_configuration
        @current_user = current_user
        @mapped_record = mapped_record.with_indifferent_access
        @attachment_downloader = attachment_downloader
        @airtable_client = airtable_client
      end

      def call
        raise RowError, "An importing user is required" unless importing_user_valid?
        raise RowError, "Airtable row is missing its mapped record ID" if mapped_record[:airtable_record_id].blank?

        raise_unsupported_mappings!

        operation = nil
        proposal = nil

        ActiveRecord::Base.transaction do
          proposal = existing_proposal
          operation = proposal ? :updated : :created
          proposal = proposal ? update_proposal(proposal) : create_proposal
          sync_tracking!(proposal)
        end
        writeback!(proposal)

        broadcast(:ok, proposal:, operation:)
      rescue ActiveRecord::RecordInvalid,
             RowError,
             KeyError,
             Decidim::Airtable::Api::Error,
             Decidim::Airtable::AttachmentDownloader::Error,
             Decidim::Airtable::ProposalCustomFieldsUpdater::Error => e
        sync_failure!(e.message)
        broadcast(:invalid, error: e.message)
      end

      private

      attr_reader :import_configuration, :current_user, :mapped_record, :attachment_downloader, :airtable_client

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
        proposal ||= proposal_from_writeback_id
        proposal ||= proposal_from_reference
        return unless proposal
        raise RowError, "Existing proposal does not belong to the configured component" unless proposal.component == component

        proposal
      end

      def proposal_from_writeback_id
        mapping = auxiliary_mappings.find { |item| item.fetch(:mapping) == "writeback_proposal_id" }
        proposal_id = mapping&.fetch(:value)
        return if proposal_id.blank? || !proposal_id.to_s.match?(/\A\d+\z/)

        Decidim::Proposals::Proposal.find_by(id: proposal_id)
      end

      def proposal_from_reference
        reference = proposal_data[:reference]
        return if reference.blank?

        Decidim::Proposals::Proposal.find_by(component:, reference:)
      end

      def create_proposal
        creator = Decidim::Proposals::Import::ProposalCreator.new(proposal_data, creator_context)
        proposal = creator.produce
        apply_proposal_data(proposal, creating: true)
        creator.finish!
        apply_attachments(proposal)
        proposal
      end

      def update_proposal(proposal)
        apply_proposal_data(proposal, creating: false)
        Decidim.traceability.perform_action!(:update, proposal, current_user) do
          proposal.save!
          proposal
        end
        apply_attachments(proposal)
        proposal
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
        apply_custom_fields(proposal)
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
        previous_author_ids = previously_imported_author_ids
        return if previous_author_ids.empty? && author_mappings.empty? && !author_mapping_configured?

        remove_imported_authors(proposal, previous_author_ids)
        authors = mapped_authors

        if authors.any?
          remove_organization_author(proposal)
        elsif proposal.authors.empty?
          proposal.add_coauthor(import_configuration.organization)
        end

        @imported_author_ids = authors.each_with_object([]) do |author, imported_ids|
          next if proposal.authored_by?(author)

          proposal.add_coauthor(author)
          imported_ids << author.id
        end.uniq
      end

      def mapped_authors
        author_mappings.flat_map do |mapping|
          author_values(mapping.fetch(:value)).map do |value|
            author = find_author(author_lookup_by(mapping), value)
            raise RowError, "Could not find a unique proposal author for '#{value}'" unless author

            author
          end
        end.uniq(&:id)
      end

      def remove_organization_author(proposal)
        removed = false
        proposal.coauthorships.to_a.each do |coauthorship|
          next unless coauthorship.author == import_configuration.organization

          if coauthorship.persisted?
            coauthorship.destroy!
          else
            proposal.coauthorships.target.delete(coauthorship)
          end
          removed = true
        end

        reset_author_associations(proposal) if removed
      end

      def author_mapping_configured?
        mappings = import_configuration.settings&.dig("proposal_field_mappings") || {}
        mappings.values.any? { |value| value.to_s.start_with?("authors_by_") }
      end

      def previously_imported_author_ids
        metadata = tracking_record&.metadata || {}
        return normalized_author_ids(metadata["airtable_imported_author_ids"]) if metadata.has_key?("airtable_imported_author_ids")

        legacy_imported_author_ids(metadata)
      end

      def normalized_author_ids(ids)
        Array(ids).filter_map { |id| id.to_i if id.to_s.match?(/\A\d+\z/) }
      end

      def legacy_imported_author_ids(metadata)
        Array(metadata["auxiliary_mappings"]).flat_map do |mapping|
          mapping = mapping.with_indifferent_access
          next [] unless mapping[:mapping].to_s.start_with?("authors_by_")

          author_values(mapping[:value]).filter_map do |value|
            find_author(author_lookup_by(mapping), value)&.id
          end
        end.flatten.uniq
      end

      def author_lookup_by(mapping)
        mapping.dig(:metadata, "lookup_by") || mapping.fetch(:mapping).delete_prefix("authors_by_")
      end

      def remove_imported_authors(proposal, author_ids)
        return if author_ids.empty? || proposal.new_record?

        removed = proposal.coauthorships.where(
          decidim_author_type: Decidim::User.base_class.name,
          decidim_author_id: author_ids
        ).destroy_all
        reset_author_associations(proposal) if removed.any?
      end

      def reset_author_associations(proposal)
        proposal.association(:coauthorships).reset
        proposal.remove_instance_variable(:@authors) if proposal.instance_variable_defined?(:@authors)
      end

      def find_author(lookup_by, value)
        users = Decidim::User.where(organization: import_configuration.organization)
        case lookup_by
        when "email"
          users.where("LOWER(email) = ?", value.to_s.downcase).first
        when "nickname"
          nickname = value.to_s.strip.delete_prefix("@").downcase
          users.where("LOWER(nickname) = ?", nickname).first
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
        return [] if value.blank?
        return value.compact_blank if value.is_a?(Array)

        [value]
      end

      def auxiliary_mappings
        mapped_record.fetch(:auxiliary_mappings, [])
      end

      def author_mappings
        auxiliary_mappings.select { |mapping| mapping.fetch(:mapping).start_with?("authors_by_") }
      end

      def unsupported_mappings
        auxiliary_mappings.reject do |mapping|
          mapping.fetch(:mapping).start_with?("taxonomy_root:", "authors_by_", "awesome_custom:") ||
            mapping.fetch(:mapping) == "attachments" ||
            mapping.fetch(:mapping).start_with?("writeback_")
        end
      end

      def apply_custom_fields(proposal)
        mappings = auxiliary_mappings.select { |mapping| mapping.fetch(:mapping).start_with?("awesome_custom:") }
        return if mappings.empty?

        Decidim::Airtable::ProposalCustomFieldsUpdater.new(
          organization: import_configuration.organization,
          component:,
          current_user:
        ).apply(proposal, mappings)
      end

      def apply_attachments(proposal)
        attachment_mappings.each do |mapping|
          source_field_id = mapping.fetch(:airtable_field_id)
          remove_previous_airtable_attachments(proposal, source_field_id)

          Array(mapping.fetch(:value)).each do |file_data|
            attach_airtable_file(proposal, source_field_id, file_data)
          end
        end
      end

      def attachment_mappings
        auxiliary_mappings.select { |mapping| mapping.fetch(:mapping) == "attachments" }
      end

      def remove_previous_airtable_attachments(proposal, source_field_id)
        proposal.attachments.with_attached_file.each do |attachment|
          next unless attachment.file.attached?

          metadata = attachment.file.blob.metadata["airtable_import"] || {}
          next unless metadata["configuration_id"].to_s == import_configuration.id.to_s
          next unless metadata["record_id"] == mapped_record.fetch(:airtable_record_id)
          next unless metadata["field_id"] == source_field_id

          attachment.destroy!
        end
      end

      def attach_airtable_file(proposal, source_field_id, file_data)
        url = file_data["url"] || file_data[:url]
        raise RowError, "Airtable attachment is missing its download URL" if url.blank?

        downloaded = attachment_downloader.download(url)
        filename = attachment_filename(file_data, url)
        content_type = attachment_content_type(downloaded, file_data)
        blob = ActiveStorage::Blob.create_and_upload!(
          io: downloaded.fetch(:io),
          filename:,
          content_type:,
          identify: false,
          metadata: {
            "airtable_import" => {
              "configuration_id" => import_configuration.id.to_s,
              "record_id" => mapped_record.fetch(:airtable_record_id),
              "field_id" => source_field_id
            }
          }
        )
        attachment = Decidim::Attachment.new(
          attached_to: proposal,
          title: { import_configuration.organization.default_locale => filename },
          content_type:
        )
        attachment.file.attach(blob)
        attachment.save!
      rescue StandardError
        blob&.purge
        raise
      ensure
        downloaded&.dig(:io)&.close!
      end

      def attachment_filename(file_data, url)
        value = file_data["filename"] || file_data[:filename]
        value = File.basename(URI.parse(url).path) if value.blank?
        File.basename(value.presence || "airtable-attachment")
      end

      def attachment_content_type(downloaded, file_data)
        response_type = downloaded[:content_type].to_s.split(";").first.presence
        airtable_type = file_data["type"] || file_data[:type]
        return airtable_type if response_type.blank? || response_type == "application/octet-stream"

        response_type
      end

      def writeback!(proposal)
        fields = auxiliary_mappings.each_with_object({}) do |mapping, result|
          case mapping.fetch(:mapping)
          when "writeback_proposal_id"
            result[mapping.fetch(:airtable_field_id)] = proposal.id
          when "writeback_proposal_url"
            result[mapping.fetch(:airtable_field_id)] = Decidim::ResourceLocatorPresenter.new(proposal).url
          end
        end
        return if fields.empty?

        airtable_client.update_record(
          base_id: import_configuration.airtable_base_id,
          table_id: import_configuration.airtable_table_id,
          record_id: mapped_record.fetch(:airtable_record_id),
          fields:
        )
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
        return if mapped_record[:airtable_record_id].blank?

        sync_tracking(status: "failed", proposal: tracking_record&.proposal, last_error: error)
      rescue ActiveRecord::RecordInvalid, KeyError
        nil
      end

      def sync_tracking(status:, proposal:, last_error: nil)
        result = nil
        Decidim::Airtable::SyncImportRecord.call(
          import_configuration:,
          organization: import_configuration.organization,
          airtable_record_id: mapped_record.fetch(:airtable_record_id),
          row_checksum: mapped_record[:row_checksum],
          metadata: {
            "auxiliary_mappings" => auxiliary_mappings,
            "airtable_imported_author_ids" => imported_author_ids_for_tracking
          },
          proposal:,
          status:,
          last_error:
        ) do
          on(:ok) { |record| result = record }
          on(:invalid) { |record| raise ActiveRecord::RecordInvalid, record }
        end
        result
      end

      def imported_author_ids_for_tracking
        @imported_author_ids || previously_imported_author_ids
      end
    end
  end
end
