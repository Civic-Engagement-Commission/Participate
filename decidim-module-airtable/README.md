# Decidim::Airtable

Import Airtable records into Decidim proposals. Administrators configure a base, table, view, target proposals component, and field mappings in the admin UI. Imports run asynchronously and provide a per-run status and result page.

## Requirements

- Ruby 3.3 or later.
- Decidim and `decidim-proposals` 0.31.x.
- An Airtable personal access token with access to the selected base.
- A working ActiveJob backend and worker. This application uses Sidekiq when `QUEUE_ADAPTER=sidekiq`.

## Installation

Add the module to the host application's `Gemfile`:

```ruby
gem "decidim-airtable", path: "decidim-module-airtable"
```

Then install dependencies and migrate the host application database:

```sh
bundle install
bundle exec rails db:migrate
```

The engine disables automatic migration discovery. This repository includes the Airtable migrations in the host app's `db/migrate` as well as in the module. When integrating the module into another host app, make sure the module migrations are copied into that app's `db/migrate` before running migrations.

Set the Airtable token in every web and worker environment:

```sh
AIRTABLE_PERSONAL_TOKEN=pat_...
```

Do not commit the token. The token needs Airtable's `schema.bases:read` and `data.records:read` scopes to list bases/tables and import records. Add `data.records:write` if you configure proposal ID or URL write-back fields. Grant the token access to the base being imported.

The module reads `AIRTABLE_PERSONAL_TOKEN` at runtime. Restart the web and worker processes after changing it.

## Configure an Import

1. Sign in as an organization administrator and open **Admin → Airtable**.
2. Select **Add configuration**.
3. Choose the Airtable base, table, and view, then choose the target proposals component. The component must belong to the current organization.
4. Save the configuration, then open **Configure** to map Airtable fields to proposal fields.
5. Mark the configuration active when it is ready to run.

The base/table/view selectors use Airtable metadata. If bases cannot be listed, verify the token scopes and base access. A base ID can be entered manually when the selector cannot load bases.

## Field Mappings

Each Airtable field can be mapped to one Decidim target. Available mappings depend on the target organization and Airtable field type.

| Mapping | Behavior |
| --- | --- |
| Title, body, address, latitude, longitude, reference, cost, state, created at, published at | Updates the corresponding proposal field. Title and body are written in the organization's default locale. State must match a state configured for the selected component. Created at and published at require an Airtable date/time-compatible field. |
| Author by nickname or email | Finds Decidim users in the same organization. Nicknames may include a leading `@`. Multiple values can be separated by commas, semicolons, or newlines. When users are mapped, they replace the previously Airtable-managed authors; unrelated manual coauthors are preserved. If the configured author field is blank, the organization remains the author fallback when no other authors remain. |
| Taxonomy | Maps text to a taxonomy item under the selected root. The item name must match, ignoring case. Blank values clear the Airtable-managed selection under that root. |
| Decidim Awesome custom field | Maps to a configured public or private proposal custom field. The relevant Decidim Awesome field must still exist when the import runs. |
| Attachments | Imports Airtable attachment URLs as Decidim attachments. Previously imported attachments from the same Airtable field are replaced on re-import. Downloads are restricted to HTTPS Airtable attachment hosts and limited to 20 MB; Decidim's own upload validation also applies. |
| Write Decidim proposal ID | Writes the proposal's numeric ID to the selected writable Airtable field. A writable number field is recommended. |
| Write Decidim proposal URL | Writes the proposal URL to the selected writable Airtable field. |

Write-back mappings require `data.records:write`. Each write-back target can only be mapped once.

Blank values in standard mappings such as title, body, address, or cost are ignored, so they do not clear existing proposal values. Taxonomy, custom-field, attachment, and configured author mappings have their own clearing/replacement behavior as described above.

## Run and Monitor

From the imports index, open a configuration's actions menu and select **Run now**. Confirm the action to enqueue the import. The browser opens that run's status page, which refreshes while the run is queued or active.

The run page shows queued/running/completed/failed status, fetched/created/updated/failed counts, and row errors. Row errors include the Airtable record ID and, when available, the mapped proposal title and reference. The imports index links to each configuration's latest run.

Imports process the selected Airtable view. A tracking record links each Airtable record ID to its Decidim proposal. On re-run, the importer updates the linked proposal; if no tracking link exists, it can also match by a mapped write-back proposal ID or mapped reference in the target component. If no identifier matches, it creates a proposal. It does not deduplicate by title.

A SHA-256 checksum of the Airtable fields is stored on the tracking record for diagnostics, but unchanged rows are not currently skipped: each fetched row is processed on every run.

## Stop and Reset

**Stop run** requests cooperative cancellation. A queued run is cancelled immediately. A running import finishes its current row, then stops before the next row. A long-running row may include Airtable write-back or attachment downloads, so the status can remain **Stopping after the current row** while that work finishes.

**Force reset status** marks an active run cancelled and permits another run to be queued. It does not terminate the worker process. Use it only after confirming the worker has stopped; otherwise that worker may still finish its current row.

## Worker Setup

The job uses the host application's ActiveJob adapter. In this repository, Docker Compose sets `QUEUE_ADAPTER=sidekiq` and runs a Sidekiq service using Redis. Ensure the worker is running in any deployment that uses Sidekiq; otherwise runs remain queued. For another ActiveJob adapter, follow the host application's worker setup.



