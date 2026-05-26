// A11y: strip <h3> from cookies accordion trigger — accordion JS wraps it in
// role="button", which forbids nested heading semantics.
// Remove when upstream changes the tag in decidim-core/.../data_consent/category.erb.
const swapCookieHeadings = () => {
  document.querySelectorAll("h3.cookies__category-trigger-title").forEach((h3) => {
    const span = document.createElement("span");
    Array.from(h3.attributes).forEach((attr) => span.setAttribute(attr.name, attr.value));
    while (h3.firstChild) span.appendChild(h3.firstChild);
    h3.replaceWith(span);
  });
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", swapCookieHeadings);
} else {
  swapCookieHeadings();
}
