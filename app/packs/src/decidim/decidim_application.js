// This file is compiled inside Decidim core pack. Code can be added here and will be executed
// as part of that pack

// Load images
require.context("../../images", true)

import TaxonomyMultiselectController from "./nyc/controllers/taxonomy_multiselect_controller"
import TaxonomyCheckboxLimitController from "./nyc/controllers/taxonomy_checkbox_limit_controller"
import TaxonomyFilterJsonEditorController from "./nyc/controllers/taxonomy_filter_json_editor_controller"
window.Stimulus?.register("taxonomy-multiselect", TaxonomyMultiselectController)
window.Stimulus?.register("taxonomy-checkbox-limit", TaxonomyCheckboxLimitController)
window.Stimulus?.register("taxonomy-filter-json-editor", TaxonomyFilterJsonEditorController)

