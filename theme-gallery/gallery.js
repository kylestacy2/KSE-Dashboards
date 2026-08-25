(() => {
  "use strict";

  const data = window.KSE_THEME_DATA;
  const gallery = document.querySelector("#gallery");
  const emptyState = document.querySelector("#empty-state");
  const search = document.querySelector("#theme-search");
  const filterButtons = [...document.querySelectorAll("[data-filter]")];
  let activeFilter = "all";

  const swatchKeys = ["bg", "panel", "border", "dim", "accent"];

  function makeElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  }

  function themeCard(widget, theme, index) {
    const article = makeElement("article", "theme-card");
    article.dataset.widget = widget.id;
    article.dataset.search = `${widget.name} ${theme.name}`.toLowerCase();

    const link = makeElement("a", "preview-link");
    link.href = `assets/${widget.id}-${theme.slug}.png`;
    link.setAttribute("aria-label", `Open full-size ${widget.name} ${theme.name} preview`);
    const image = document.createElement("img");
    image.src = `assets/${widget.id}-${theme.slug}.png`;
    image.alt = `${widget.name} dashboard using the ${theme.name} theme`;
    image.width = 480;
    image.height = 272;
    image.loading = "lazy";
    link.append(image);

    const body = makeElement("div", "card-body");
    const title = makeElement("div", "card-title");
    title.append(
      makeElement("h3", "", theme.name),
      makeElement("p", "", `${widget.name} · Theme ${String(index + 1).padStart(2, "0")}`),
    );

    const swatches = makeElement("div", "swatches");
    swatches.setAttribute("aria-label", `${theme.name} palette colors`);
    swatchKeys.forEach((key) => {
      const swatch = makeElement("span", "swatch");
      const value = theme.colors[key];
      swatch.style.background = value;
      swatch.title = `${key}: ${value}`;
      swatches.append(swatch);
    });

    body.append(title, swatches);
    article.append(link, body);
    return article;
  }

  data.widgets.forEach((widget) => {
    const section = makeElement("section", "widget-section");
    section.dataset.widgetSection = widget.id;
    const heading = makeElement("div", "section-heading");
    const copy = makeElement("div");
    copy.append(
      makeElement("h2", "", widget.name),
      makeElement("p", "", widget.description),
    );
    const count = makeElement("span", "section-count", `${widget.themes.length} themes`);
    count.dataset.sectionCount = widget.id;
    heading.append(copy, count);

    const grid = makeElement("div", "theme-grid");
    widget.themes.forEach((theme, index) => grid.append(themeCard(widget, theme, index)));
    section.append(heading, grid);
    gallery.append(section);
  });

  const totals = Object.fromEntries(data.widgets.map((widget) => [widget.id, widget.themes.length]));
  document.querySelector("#total-samples").textContent = String(Object.values(totals).reduce((a, b) => a + b, 0));
  document.querySelector("#kse4-total").textContent = String(totals.kse4);
  document.querySelector("#kse5-total").textContent = String(totals.kse5);

  function applyFilters() {
    const query = search.value.trim().toLowerCase();
    let totalVisible = 0;

    document.querySelectorAll(".widget-section").forEach((section) => {
      const widget = section.dataset.widgetSection;
      const widgetEnabled = activeFilter === "all" || activeFilter === widget;
      let sectionVisible = 0;
      section.querySelectorAll(".theme-card").forEach((card) => {
        const visible = widgetEnabled && (!query || card.dataset.search.includes(query));
        card.hidden = !visible;
        if (visible) sectionVisible += 1;
      });
      section.hidden = sectionVisible === 0;
      const count = section.querySelector("[data-section-count]");
      count.textContent = `${sectionVisible} theme${sectionVisible === 1 ? "" : "s"}`;
      totalVisible += sectionVisible;
    });

    emptyState.hidden = totalVisible !== 0;
  }

  filterButtons.forEach((button) => {
    button.addEventListener("click", () => {
      activeFilter = button.dataset.filter;
      filterButtons.forEach((candidate) => {
        const active = candidate === button;
        candidate.classList.toggle("is-active", active);
        candidate.setAttribute("aria-pressed", String(active));
      });
      applyFilters();
    });
  });

  search.addEventListener("input", applyFilters);
})();
