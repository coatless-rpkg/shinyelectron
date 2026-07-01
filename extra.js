// Make theme-aware <picture> images follow the pkgdown light switch.
//
// The light switch sets `data-bs-theme` on <html>, but a <picture> only reacts
// to the OS `prefers-color-scheme` media query, so toggling the site theme does
// not swap the logo or the diagrams on its own. We read the light and dark
// sources from each <picture>, drop the <source> so the <img> is fully under our
// control, then point each <img> at the variant that matches the active theme
// (and keep it in sync when the switch changes).
(function () {
  function collect() {
    document.querySelectorAll("picture").forEach(function (pic) {
      var img = pic.querySelector("img");
      var source = pic.querySelector('source[media*="prefers-color-scheme"]');
      if (!img || !source || img.dataset.themeLight) return;
      img.dataset.themeLight = img.getAttribute("src");
      img.dataset.themeDark = source.getAttribute("srcset");
      source.parentNode.removeChild(source);
    });
  }
  function apply() {
    var dark = document.documentElement.getAttribute("data-bs-theme") === "dark";
    document.querySelectorAll("img[data-theme-light]").forEach(function (img) {
      var want = dark ? img.dataset.themeDark : img.dataset.themeLight;
      if (img.getAttribute("src") !== want) img.setAttribute("src", want);
    });
  }
  function init() {
    collect();
    apply();
    new MutationObserver(apply).observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-bs-theme"],
    });
  }
  if (document.readyState !== "loading") init();
  else document.addEventListener("DOMContentLoaded", init);
})();
