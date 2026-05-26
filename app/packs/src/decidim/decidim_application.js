// This file is compiled inside Decidim core pack. Code can be added here and will be executed
// as part of that pack

// Load images
require.context("../../images", true)

// A11y patches over upstream Decidim. Each module documents its removal trigger.
import "./a11y_patches/cookies_h3"
