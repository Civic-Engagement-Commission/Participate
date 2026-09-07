// This file is compiled inside Decidim core pack. Code can be added here and will be executed
// as part of that pack

// Load images
require.context("../../images", true)

import TaxonomyMultiselectController from "./participate/controllers/taxonomy_multiselect_controller"
window.Stimulus?.register("taxonomy-multiselect", TaxonomyMultiselectController)
