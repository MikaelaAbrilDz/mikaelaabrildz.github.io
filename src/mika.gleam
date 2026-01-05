import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import lustre/attribute.{alt, class, href, src}
import lustre/element.{type Element}
import lustre/element/html
import lustre/ssg
import lustre/ssg/djot
import simplifile
import tom

// ============================================================================
// Types
// ============================================================================

pub type ProjectMetadata {
  ProjectMetadata(
    slug: String,
    title: String,
    description: String,
    bg_color: String,
    thumbnail: String,
    thumbnail_sidebar: Option(String),
    display_type: String,
    section_order: Int,
    project_order: Int,
    show_in_sidebar: Bool,
    sidebar_image: Option(String),
    roles: List(String),
    build_path: Option(String),
  )
}

pub type Section {
  Section(title: String, order: Int)
}

// ============================================================================
// Main
// ============================================================================

pub fn main() {
  io.println("Building site...")

  let assert Ok(all_projects) = get_all_projects()
  let assert Ok(all_sections) = get_all_sections()

  let build =
    ssg.new("dist")
    |> ssg.add_static_dir("assets")
    |> ssg.use_index_routes
    |> ssg.add_static_route(
      "/",
      page_layout("Mikaela's Portfolio", home_view(all_projects, all_sections)),
    )
    |> ssg.add_static_route(
      "/work",
      page_layout(
        "Work - Mikaela's Portfolio",
        work_view(all_projects, all_sections),
      ),
    )
    |> ssg.add_static_route(
      "/about",
      page_layout("About - Mikaela's Portfolio", about_view()),
    )
    |> add_project_routes(all_projects)
    |> ssg.build

  case build {
    Ok(_) -> io.println("Build successful!")
    Error(e) -> {
      echo e
      panic as "Build unsuccessful"
    }
  }
}

// ============================================================================
// TOML Parsing
// ============================================================================

fn read_toml() -> Result(Dict(String, tom.Toml), String) {
  use toml_content <- result.try(
    simplifile.read("content/projects.toml")
    |> result.map_error(fn(_) { "Failed to read content/projects.toml" }),
  )

  tom.parse(toml_content)
  |> result.map_error(fn(_) { "Failed to parse TOML" })
}

pub fn get_all_projects() -> Result(List(ProjectMetadata), String) {
  use parsed <- result.try(read_toml())
  use projects <- result.try(parse_projects(parsed))

  let sorted =
    list.sort(projects, fn(a, b) {
      case int.compare(a.section_order, b.section_order) {
        order.Eq -> int.compare(a.project_order, b.project_order)
        other -> other
      }
    })

  Ok(sorted)
}

pub fn get_all_sections() -> Result(List(Section), String) {
  use parsed <- result.try(read_toml())
  use sections <- result.try(parse_sections(parsed))

  let sorted = list.sort(sections, fn(a, b) { int.compare(a.order, b.order) })

  Ok(sorted)
}

pub fn get_sidebar_project() -> Option(ProjectMetadata) {
  case get_all_projects() {
    Ok(projects) ->
      projects
      |> list.find(fn(p) { p.show_in_sidebar })
      |> option.from_result
    Error(_) -> None
  }
}

fn parse_sections(toml: Dict(String, tom.Toml)) -> Result(List(Section), String) {
  case dict.get(toml, "section") {
    Ok(tom.ArrayOfTables(sections)) -> list.try_map(sections, parse_section)
    _ -> Ok([])
  }
}

fn parse_section(table: Dict(String, tom.Toml)) -> Result(Section, String) {
  use title <- result.try(get_toml_string(table, "title"))
  use order <- result.try(get_toml_int(table, "order"))
  Ok(Section(title: title, order: order))
}

fn parse_projects(
  toml: Dict(String, tom.Toml),
) -> Result(List(ProjectMetadata), String) {
  case dict.get(toml, "project") {
    Ok(tom.ArrayOfTables(projects)) -> list.try_map(projects, parse_project)
    _ -> Error("No 'project' array of tables found in TOML")
  }
}

fn parse_project(
  table: Dict(String, tom.Toml),
) -> Result(ProjectMetadata, String) {
  use slug <- result.try(get_toml_string(table, "slug"))
  use title <- result.try(get_toml_string(table, "title"))
  use description <- result.try(get_toml_string(table, "description"))
  use bg_color <- result.try(get_toml_string(table, "bg_color"))
  use thumbnail <- result.try(get_toml_string(table, "thumbnail"))
  use display_type <- result.try(get_toml_string(table, "display_type"))
  use section_order <- result.try(get_toml_int(table, "section_order"))
  use project_order <- result.try(get_toml_int(table, "project_order"))

  let show_in_sidebar =
    get_toml_bool(table, "show_in_sidebar") |> result.unwrap(False)
  let sidebar_image =
    get_toml_string(table, "sidebar_image")
    |> result.map(Some)
    |> result.unwrap(None)
  let thumbnail_sidebar =
    get_toml_string(table, "thumbnail_sidebar")
    |> result.map(Some)
    |> result.unwrap(None)
  let roles = get_toml_string_array(table, "roles") |> result.unwrap([])
  let build_path =
    get_toml_string(table, "build_path")
    |> result.map(Some)
    |> result.unwrap(None)

  Ok(ProjectMetadata(
    slug:,
    title:,
    description:,
    bg_color:,
    thumbnail:,
    thumbnail_sidebar:,
    display_type:,
    section_order:,
    project_order:,
    show_in_sidebar:,
    sidebar_image:,
    roles:,
    build_path:,
  ))
}

fn get_toml_string(
  table: Dict(String, tom.Toml),
  key: String,
) -> Result(String, String) {
  case dict.get(table, key) {
    Ok(tom.String(value)) -> Ok(value)
    _ -> Error("Missing or invalid string for key: " <> key)
  }
}

fn get_toml_int(
  table: Dict(String, tom.Toml),
  key: String,
) -> Result(Int, String) {
  case dict.get(table, key) {
    Ok(tom.Int(value)) -> Ok(value)
    _ -> Error("Missing or invalid int for key: " <> key)
  }
}

fn get_toml_bool(
  table: Dict(String, tom.Toml),
  key: String,
) -> Result(Bool, String) {
  case dict.get(table, key) {
    Ok(tom.Bool(value)) -> Ok(value)
    _ -> Error("Missing or invalid bool for key: " <> key)
  }
}

fn get_toml_string_array(
  table: Dict(String, tom.Toml),
  key: String,
) -> Result(List(String), String) {
  case dict.get(table, key) {
    Ok(tom.Array(items)) ->
      items
      |> list.try_map(fn(item) {
        case item {
          tom.String(s) -> Ok(s)
          _ -> Error("Array item is not a string")
        }
      })
    _ -> Error("Missing or invalid string array for key: " <> key)
  }
}

// ============================================================================
// Site Building
// ============================================================================

fn add_project_routes(config, all_projects: List(ProjectMetadata)) {
  list.fold(all_projects, config, fn(acc, project) {
    let content_elements = read_and_render_djot(project.slug)
    let view = project_view(project, content_elements, all_projects)
    ssg.add_static_route(
      acc,
      "/project/" <> project.slug,
      page_layout(project.title <> " - Mikaela's Portfolio", view),
    )
  })
}

fn read_and_render_djot(slug: String) -> List(Element(Nil)) {
  let path = "content/projects/" <> slug <> ".dj"
  case simplifile.read(path) {
    Ok(content) -> djot.render(content, djot.default_renderer())
    Error(_) -> [html.p([], [element.text("Project not found")])]
  }
}

fn page_layout(title: String, content: Element(Nil)) -> Element(Nil) {
  html.html([attribute.attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.title([], title),
      html.link([attribute.rel("icon"), href("/favicon.png")]),
      // Google Fonts preconnect
      html.link([
        attribute.rel("preconnect"),
        href("https://fonts.googleapis.com"),
      ]),
      html.link([
        attribute.rel("preconnect"),
        href("https://fonts.gstatic.com"),
        attribute.attribute("crossorigin", ""),
      ]),
      html.link([attribute.rel("stylesheet"), href("/mika.css")]),
    ]),
    html.body([], [content, carousel_init_script()]),
  ])
}

fn carousel_init_script() -> Element(Nil) {
  html.script(
    [],
    "
    document.addEventListener('DOMContentLoaded', function() {
      document.querySelectorAll('.carousel').forEach(function(carousel) {
        var scrollContainer = carousel.querySelector('p');
        if (!scrollContainer) return;

        var images = scrollContainer.querySelectorAll('img');
        if (images.length <= 1) return;

        // Create prev button
        var prevBtn = document.createElement('button');
        prevBtn.className = 'carousel-nav carousel-nav-prev';
        prevBtn.setAttribute('aria-label', 'Previous image');
        prevBtn.innerHTML = '<svg viewBox=\"0 0 24 24\"><polyline points=\"15 18 9 12 15 6\"></polyline></svg>';

        // Create next button
        var nextBtn = document.createElement('button');
        nextBtn.className = 'carousel-nav carousel-nav-next';
        nextBtn.setAttribute('aria-label', 'Next image');
        nextBtn.innerHTML = '<svg viewBox=\"0 0 24 24\"><polyline points=\"9 18 15 12 9 6\"></polyline></svg>';

        carousel.appendChild(prevBtn);
        carousel.appendChild(nextBtn);

        // Create hint text
        var hint = document.createElement('div');
        hint.className = 'carousel-hint';
        hint.textContent = 'Use arrows or scroll to see more';
        carousel.appendChild(hint);

        // Click handlers
        prevBtn.addEventListener('click', function() {
          var scrollAmount = scrollContainer.clientWidth;
          scrollContainer.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
        });

        nextBtn.addEventListener('click', function() {
          var scrollAmount = scrollContainer.clientWidth;
          scrollContainer.scrollBy({ left: scrollAmount, behavior: 'smooth' });
        });
      });
    });
  ",
  )
}

// ============================================================================
// SVG Icons
// ============================================================================

fn email_icon() -> Element(Nil) {
  html.svg(
    [
      attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2"),
      class("w-5 h-5"),
    ],
    [
      element.element(
        "path",
        [
          attribute.attribute("stroke-linecap", "round"),
          attribute.attribute("stroke-linejoin", "round"),
          attribute.attribute(
            "d",
            "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
          ),
        ],
        [],
      ),
    ],
  )
}

fn linkedin_icon() -> Element(Nil) {
  html.svg(
    [
      attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("fill", "currentColor"),
      class("w-5 h-5"),
    ],
    [
      element.element(
        "path",
        [
          attribute.attribute(
            "d",
            "M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z",
          ),
        ],
        [],
      ),
    ],
  )
}

fn github_icon() -> Element(Nil) {
  html.svg(
    [
      attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("fill", "currentColor"),
      class("w-5 h-5"),
    ],
    [
      element.element(
        "path",
        [
          attribute.attribute(
            "d",
            "M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z",
          ),
        ],
        [],
      ),
    ],
  )
}

fn itchio_icon() -> Element(Nil) {
  html.svg(
    [
      attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("fill", "currentColor"),
      class("w-5 h-5"),
    ],
    [
      element.element(
        "path",
        [
          attribute.attribute(
            "d",
            "M3.13 1.338C2.08 1.96.02 4.328 0 4.95v1.03c0 1.303 1.22 2.45 2.325 2.45 1.33 0 2.436-1.102 2.436-2.41 0 1.308 1.07 2.41 2.4 2.41 1.328 0 2.362-1.102 2.362-2.41 0 1.308 1.137 2.41 2.466 2.41h.024c1.33 0 2.466-1.102 2.466-2.41 0 1.308 1.034 2.41 2.363 2.41 1.33 0 2.4-1.102 2.4-2.41 0 1.308 1.106 2.41 2.435 2.41C22.78 8.43 24 7.283 24 5.98V4.95c-.02-.62-2.08-2.99-3.13-3.612-3.253-.114-5.508-.134-8.87-.133-3.362 0-7.945.053-8.87.133zm6.376 6.477a2.74 2.74 0 01-.468.602c-.507.49-1.197.762-1.924.762-.727 0-1.418-.272-1.926-.762a2.71 2.71 0 01-.468-.602 2.72 2.72 0 01-.467.602c-.508.49-1.199.762-1.926.762-.18 0-.357-.02-.53-.057v8.462c0 2.456 1.04 4.406 3.91 4.406h.21c.89-1.044 2.376-2.755 2.376-2.755.873 1.012 2.312 2.755 2.312 2.755h4.655c.89-1.044 2.376-2.755 2.376-2.755.873 1.012 2.312 2.755 2.312 2.755h.21c2.87 0 3.91-1.95 3.91-4.406V9.12a3.03 3.03 0 01-.53.057c-.727 0-1.418-.272-1.926-.762a2.72 2.72 0 01-.467-.602 2.72 2.72 0 01-.468.602c-.507.49-1.198.762-1.925.762-.727 0-1.418-.272-1.926-.762a2.72 2.72 0 01-.468-.602 2.72 2.72 0 01-.467.602c-.508.49-1.199.762-1.926.762s-1.417-.272-1.925-.762a2.72 2.72 0 01-.468-.602zm-.387 4.162h5.756v5.756h-5.756v-5.756z",
          ),
        ],
        [],
      ),
    ],
  )
}

// ============================================================================
// Header Component
// ============================================================================

fn header_view() -> Element(Nil) {
  html.header(
    [
      class(
        "fixed top-0 left-0 right-0 z-50 bg-gray-900/80 backdrop-blur-md border-b border-gray-800",
      ),
    ],
    [
      html.nav(
        [
          class(
            "container mx-auto px-4 md:px-6 h-16 flex items-center justify-between",
          ),
        ],
        [
          // Logo/Name
          html.a(
            [href("/"), class("text-xl font-semibold tracking-tight group")],
            [
              element.text("MikaelaAbril"),
              html.span(
                [
                  class(
                    "text-cyan-400 group-hover:text-cyan-300 transition-colors",
                  ),
                ],
                [element.text("Dz")],
              ),
            ],
          ),
          // Navigation Links
          html.div([class("flex items-center gap-6")], [
            html.ul([class("hidden md:flex items-center gap-8")], [
              nav_link("Work", "/work"),
              nav_link("About", "/about"),
            ]),
            // Contact button
            html.a(
              [
                href("mailto:mikaelaabrildiazvlc@gmail.com"),
                class(
                  "inline-flex items-center gap-2 px-4 py-2 bg-cyan-400 hover:bg-cyan-300 text-gray-900 font-semibold text-sm rounded-lg transition-colors",
                ),
              ],
              [
                email_icon(),
                html.span([class("hidden sm:inline")], [element.text("Contact")]),
              ],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn nav_link(label: String, href_attr: String) -> Element(Nil) {
  html.li([], [
    html.a(
      [
        href(href_attr),
        class(
          "text-sm font-medium text-gray-400 hover:text-white transition-colors duration-200",
        ),
      ],
      [element.text(label)],
    ),
  ])
}

// ============================================================================
// Footer Component
// ============================================================================

fn footer_view() -> Element(Nil) {
  html.footer(
    [attribute.id("contact"), class("mt-24 border-t border-gray-800")],
    [
      html.div([class("container mx-auto px-4 md:px-6 py-12 md:py-16")], [
        html.div([class("grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-12")], [
          // Left: Brand & tagline
          html.div([class("space-y-4")], [
            html.a([href("/"), class("text-xl font-semibold")], [
              element.text("MikaelaAbril"),
              html.span([class("text-cyan-400")], [element.text("Dz")]),
            ]),
          ]),
          // Center: Quick links
          html.div([class("space-y-4")], [
            html.h3(
              [
                class(
                  "text-sm font-semibold text-white uppercase tracking-wider",
                ),
              ],
              [element.text("Navigation")],
            ),
            html.ul([class("space-y-2")], [
              footer_link("Work", "/work"),
              footer_link("About", "/about"),
              footer_link("Contact", "mailto:mikaelaabrildiazvlc@gmail.com"),
            ]),
          ]),
          // Right: Social & Contact
          html.div([class("space-y-4")], [
            html.h3(
              [
                class(
                  "text-sm font-semibold text-white uppercase tracking-wider",
                ),
              ],
              [element.text("Connect")],
            ),
            html.div([class("flex items-center gap-3")], [
              social_icon_link(
                "mailto:mikaelaabrildiazvlc@gmail.com",
                "Email",
                email_icon(),
              ),
              social_icon_link(
                "https://www.linkedin.com/in/mikaela-abril-diaz",
                "LinkedIn",
                linkedin_icon(),
              ),
              social_icon_link(
                "https://github.com/mikaelaabrildz",
                "GitHub",
                github_icon(),
              ),
              social_icon_link(
                "https://mikaelaabrildz.itch.io/",
                "Itch.io",
                itchio_icon(),
              ),
            ]),
          ]),
        ]),
        // Bottom bar
        html.div(
          [
            class(
              "mt-12 pt-8 border-t border-gray-800 flex flex-col md:flex-row justify-between items-center gap-4",
            ),
          ],
          [
            html.p([class("text-gray-500 text-sm")], [
              element.text("© 2025 Mikaela Abril Dz. All rights reserved."),
            ]),
            html.p([class("text-gray-600 text-xs")], [
              element.text("Built with "),
              html.a(
                [
                  href("https://gleam.run"),
                  class("text-cyan-400/60 hover:text-cyan-400"),
                ],
                [element.text("Gleam")],
              ),
              element.text(" & "),
              html.a(
                [
                  href("https://hexdocs.pm/lustre/"),
                  class("text-cyan-400/60 hover:text-cyan-400"),
                ],
                [element.text("Lustre")],
              ),
            ]),
          ],
        ),
      ]),
    ],
  )
}

fn footer_link(label: String, href_attr: String) -> Element(Nil) {
  html.li([], [
    html.a(
      [
        href(href_attr),
        class("text-gray-400 text-sm hover:text-white transition-colors"),
      ],
      [element.text(label)],
    ),
  ])
}

fn social_icon_link(
  url: String,
  label: String,
  icon: Element(Nil),
) -> Element(Nil) {
  html.a(
    [
      href(url),
      attribute.attribute("aria-label", label),
      attribute.attribute("target", "_blank"),
      attribute.attribute("rel", "noopener noreferrer"),
      class(
        "p-2 text-gray-400 hover:text-cyan-400 transition-colors duration-200",
      ),
    ],
    [icon],
  )
}

fn home_view(
  all_projects: List(ProjectMetadata),
  all_sections: List(Section),
) -> Element(Nil) {
  let project_elements =
    build_projects_with_sections(all_projects, all_sections)

  html.div([class("min-h-screen bg-gray-900 text-white")], [
    // Header
    header_view(),
    // Main content with top padding for fixed header
    html.main([class("pt-24 pb-12")], [
      html.div([class("container mx-auto px-4 md:px-6")], [
        html.div(
          [class("flex flex-col lg:grid lg:grid-cols-12 gap-8 lg:gap-12")],
          [
            // Profile sidebar (narrower on desktop)
            html.aside([class("lg:col-span-4 xl:col-span-3")], [
              profile_section(),
            ]),
            // Projects section (wider)
            html.section(
              [
                attribute.id("work"),
                class("lg:col-span-8 xl:col-span-9 space-y-6"),
              ],
              project_elements,
            ),
          ],
        ),
      ]),
    ]),
    // Footer
    footer_view(),
  ])
}

// ============================================================================
// Work Page
// ============================================================================

fn work_view(
  all_projects: List(ProjectMetadata),
  all_sections: List(Section),
) -> Element(Nil) {
  let project_elements =
    build_projects_with_sections(all_projects, all_sections)

  html.div([class("min-h-screen bg-gray-900 text-white")], [
    header_view(),
    html.main([class("pt-24 pb-12")], [
      html.div([class("container mx-auto px-4 md:px-6 max-w-6xl")], [
        // Page header
        html.div([class("text-center mb-12")], [
          html.h1([class("text-4xl md:text-5xl font-bold text-white mb-4")], [
            element.text("My "),
            html.span([class("text-cyan-400")], [element.text("Work")]),
          ]),
          html.p([class("text-gray-400 text-lg max-w-2xl mx-auto")], [
            element.text(
              "A collection of games I've designed and developed, showcasing my skills in game design, development, and creative problem-solving.",
            ),
          ]),
        ]),
        // Projects grid
        html.div([class("space-y-8")], project_elements),
      ]),
    ]),
    footer_view(),
  ])
}

// ============================================================================
// About Page
// ============================================================================

fn about_view() -> Element(Nil) {
  html.div([class("min-h-screen bg-gray-900 text-white")], [
    header_view(),
    html.main([class("pt-24 pb-12")], [
      html.div([class("container mx-auto px-4 md:px-6 max-w-4xl")], [
        // Hero section
        html.div([class("text-center mb-12")], [
          html.div([class("mb-8")], [
            html.div(
              [
                class(
                  "w-32 h-32 md:w-40 md:h-40 mx-auto rounded-full overflow-hidden ring-4 ring-cyan-400/20 ring-offset-4 ring-offset-gray-900",
                ),
              ],
              [
                html.img([
                  src("/pfp.png"),
                  alt("Mikaela Abril Dz"),
                  class("w-full h-full object-cover"),
                ]),
              ],
            ),
          ]),
          html.h1([class("text-4xl md:text-5xl font-bold text-white mb-2")], [
            element.text("MikaelaAbril"),
            html.span([class("text-cyan-400")], [element.text("Dz")]),
          ]),
          html.p([class("text-cyan-400/80 text-xl font-medium mb-6")], [
            element.text("Game Designer & Developer"),
          ]),
        ]),
        // About content
        html.div(
          [
            class(
              "bg-gray-800/50 backdrop-blur-sm rounded-2xl p-6 md:p-10 border border-gray-700/50",
            ),
          ],
          [
            html.div([class("prose prose-invert prose-cyan max-w-none")], [
              html.h2([class("text-2xl font-bold text-cyan-400 mb-4")], [
                element.text("About Me"),
              ]),
              html.p([class("text-gray-300 leading-relaxed mb-6")], [
                element.text(
                  "I'm a 25-year-old passionate about videogame design, currently studying to turn my love for games into a career. I believe in creating experiences that bring together technical excellence and artistic vision.",
                ),
              ]),
              html.p([class("text-gray-300 leading-relaxed mb-8")], [
                element.text(
                  "My journey in game development has allowed me to explore various aspects of creation, from initial concept to final implementation. I enjoy the challenge of solving complex problems while maintaining a focus on player experience.",
                ),
              ]),
              html.h2([class("text-2xl font-bold text-cyan-400 mb-4")], [
                element.text("Skills & Tools"),
              ]),
              html.div([class("grid grid-cols-2 md:grid-cols-3 gap-4 mb-8")], [
                skill_card("Unity", "Game Engine"),
                skill_card("C#", "Programming"),
                skill_card("Game Design", "Design"),
                skill_card("Level Design", "Design"),
                skill_card("UI/UX", "Design"),
                skill_card("Prototyping", "Development"),
              ]),
              html.h2([class("text-2xl font-bold text-cyan-400 mb-4")], [
                element.text("Get in Touch"),
              ]),
              html.p([class("text-gray-300 leading-relaxed mb-6")], [
                element.text(
                  "I'm always open to discussing new projects, creative ideas, or opportunities to be part of your vision. Feel free to reach out!",
                ),
              ]),
              html.div([class("flex flex-wrap gap-4")], [
                contact_button(
                  "mailto:mikaelaabrildiazvlc@gmail.com",
                  "Email Me",
                  email_icon(),
                ),
                contact_button(
                  "https://www.linkedin.com/in/mikaela-abril-diaz",
                  "LinkedIn",
                  linkedin_icon(),
                ),
                contact_button(
                  "https://github.com/mikaelaabrildz",
                  "GitHub",
                  github_icon(),
                ),
              ]),
            ]),
          ],
        ),
      ]),
    ]),
    footer_view(),
  ])
}

fn skill_card(name: String, category: String) -> Element(Nil) {
  html.div(
    [
      class(
        "bg-gray-700/30 rounded-xl p-4 border border-gray-600/30 hover:border-cyan-400/30 transition-colors",
      ),
    ],
    [
      html.p([class("text-white font-medium")], [element.text(name)]),
      html.p([class("text-gray-500 text-sm")], [element.text(category)]),
    ],
  )
}

fn contact_button(
  url: String,
  label: String,
  icon: Element(Nil),
) -> Element(Nil) {
  html.a(
    [
      href(url),
      attribute.attribute("target", "_blank"),
      attribute.attribute("rel", "noopener noreferrer"),
      class(
        "inline-flex items-center gap-2 px-4 py-2 bg-gray-700/50 hover:bg-cyan-400/20 border border-gray-600/50 hover:border-cyan-400/30 rounded-lg text-gray-300 hover:text-cyan-400 transition-all",
      ),
    ],
    [icon, html.span([], [element.text(label)])],
  )
}

fn build_projects_with_sections(
  projects: List(ProjectMetadata),
  sections: List(Section),
) -> List(Element(Nil)) {
  sections
  |> list.flat_map(fn(section) {
    let section_projects =
      projects
      |> list.filter(fn(p) { p.section_order == section.order })
      |> list.map(project_card_from_metadata)

    case section_projects {
      [] -> []
      _ -> [
        section_title(section.title),
        html.div(
          [class("grid grid-cols-1 md:grid-cols-2 gap-4")],
          section_projects,
        ),
      ]
    }
  })
}

fn section_title(title: String) -> Element(Nil) {
  html.div([class("mb-6 mt-10 first:mt-0")], [
    html.h2(
      [
        class(
          "text-2xl md:text-3xl font-extrabold text-white uppercase tracking-tight",
        ),
      ],
      [
        element.text(title),
        html.span([class("text-cyan-400")], [element.text(" ―")]),
      ],
    ),
  ])
}

fn project_card_from_metadata(meta: ProjectMetadata) -> Element(Nil) {
  project_card(
    meta.slug,
    meta.title,
    meta.description,
    meta.bg_color,
    meta.thumbnail,
  )
}

fn project_view(
  project: ProjectMetadata,
  content_elements: List(Element(Nil)),
  all_projects: List(ProjectMetadata),
) -> Element(Nil) {
  html.div([class("min-h-screen bg-gray-900 text-white")], [
    // Header
    header_view(),
    // Main content
    html.main([class("pt-24 pb-12")], [
      html.div([class("container mx-auto px-4 md:px-6")], [
        // Breadcrumbs
        breadcrumbs(project),
        // Two-column layout
        html.div([class("grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12")], [
          // Main content - 8 columns on desktop
          html.article([class("lg:col-span-8 order-2 lg:order-1")], [
            html.div(
              [
                class(
                  "bg-gray-800/50 backdrop-blur-sm rounded-2xl p-4 md:p-8 border border-gray-700/50 prose prose-invert prose-cyan max-w-none",
                ),
              ],
              content_elements,
            ),
          ]),
          // Sidebar - 4 columns on desktop
          html.aside([class("lg:col-span-4 order-1 lg:order-2")], [
            project_sidebar(project, all_projects),
          ]),
        ]),
      ]),
    ]),
    // Footer
    footer_view(),
    // Prefetch Unity build if available
    build_prefetch_script(project.build_path),
  ])
}

fn build_prefetch_script(build_path: Option(String)) -> Element(Nil) {
  case build_path {
    option.None -> element.none()
    option.Some(path) -> html.script([], "
        // Prefetch Unity build files for faster loading
        (function() {
          var buildPath = '" <> path <> "';
          var files = [
            buildPath + '.loader.js',
            buildPath + '.framework.js',
            buildPath + '.data',
            buildPath + '.wasm'
          ];
          files.forEach(function(file) {
            var link = document.createElement('link');
            link.rel = 'prefetch';
            link.href = file;
            link.as = file.endsWith('.js') ? 'script' : 'fetch';
            document.head.appendChild(link);
          });
        })();
      ")
  }
}

fn breadcrumbs(project: ProjectMetadata) -> Element(Nil) {
  html.nav([class("mb-8"), attribute.attribute("aria-label", "Breadcrumb")], [
    html.ol([class("flex items-center space-x-2 text-sm")], [
      html.li([], [
        html.a(
          [
            href("/"),
            class("text-gray-400 hover:text-cyan-400 transition-colors"),
          ],
          [element.text("Portfolio")],
        ),
      ]),
      html.li([class("text-gray-600")], [element.text("/")]),
      html.li([], [
        html.span([class("text-gray-300")], [
          element.text(section_name(project.section_order)),
        ]),
      ]),
      html.li([class("text-gray-600")], [element.text("/")]),
      html.li([], [
        html.span([class("text-cyan-400 font-medium")], [
          element.text(project.title),
        ]),
      ]),
    ]),
  ])
}

fn section_name(order: Int) -> String {
  case order {
    1 -> "Mobile Games"
    2 -> "PC Games"
    _ -> "Other Games"
  }
}

fn project_sidebar(
  project: ProjectMetadata,
  all_projects: List(ProjectMetadata),
) -> Element(Nil) {
  let sidebar_thumb = case project.thumbnail_sidebar {
    option.Some(t) -> t
    option.None -> project.thumbnail
  }

  html.div([class("lg:sticky lg:top-24 space-y-6")], [
    // Project info card
    html.div(
      [
        class(
          "bg-gray-800/50 backdrop-blur-sm rounded-2xl p-6 border border-gray-700/50",
        ),
      ],
      [
        // Thumbnail (uses vertical if available)
        html.div([class("mb-6 rounded-xl overflow-hidden")], [
          html.img([
            src("/" <> sidebar_thumb),
            alt(project.title),
            class("w-full h-auto"),
          ]),
        ]),
        // Platform badge
        html.div([class("mb-4")], [
          html.span(
            [
              class(
                "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium "
                <> platform_badge_color(project),
              ),
            ],
            [element.text(platform_label(project))],
          ),
        ]),
        // Roles section (only show if roles exist)
        roles_section(project.roles),
        // Tech stack
        html.div([class("mb-6")], [
          html.h3(
            [
              class(
                "text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3",
              ),
            ],
            [element.text("Built with")],
          ),
          html.div([class("flex flex-wrap gap-2")], [
            tech_tag("Unity"),
            tech_tag("C#"),
          ]),
        ]),
      ],
    ),
    // Related projects
    related_projects_section(project, all_projects),
  ])
}

fn roles_section(roles: List(String)) -> Element(Nil) {
  case roles {
    [] -> element.none()
    _ ->
      html.div([class("mb-6")], [
        html.h3(
          [
            class(
              "text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3",
            ),
          ],
          [element.text("My Role")],
        ),
        html.div([class("flex flex-wrap gap-2")], list.map(roles, role_tag)),
      ])
  }
}

fn role_tag(name: String) -> Element(Nil) {
  html.span(
    [
      class(
        "px-3 py-1 bg-cyan-400/10 text-cyan-400 rounded-lg text-sm border border-cyan-400/20 font-medium",
      ),
    ],
    [element.text(name)],
  )
}

fn platform_badge_color(project: ProjectMetadata) -> String {
  case project.section_order {
    1 -> "bg-green-500/20 text-green-400 border border-green-500/30"
    2 -> "bg-blue-500/20 text-blue-400 border border-blue-500/30"
    _ -> "bg-purple-500/20 text-purple-400 border border-purple-500/30"
  }
}

fn platform_label(project: ProjectMetadata) -> String {
  case project.section_order {
    1 -> "Mobile Game"
    2 -> "PC Game"
    _ -> "Game"
  }
}

fn tech_tag(name: String) -> Element(Nil) {
  html.span(
    [
      class(
        "px-3 py-1 bg-gray-700/50 text-gray-300 rounded-lg text-sm border border-gray-600/50",
      ),
    ],
    [element.text(name)],
  )
}

fn related_projects_section(
  current: ProjectMetadata,
  all_projects: List(ProjectMetadata),
) -> Element(Nil) {
  let related =
    all_projects
    |> list.filter(fn(p) {
      p.slug != current.slug && p.section_order == current.section_order
    })
    |> list.take(3)

  case related {
    [] -> element.none()
    projects ->
      html.div(
        [class("bg-gray-800/30 rounded-xl p-6 border border-gray-700/30")],
        [
          html.h3(
            [
              class(
                "text-sm font-semibold text-gray-400 uppercase tracking-wider mb-4",
              ),
            ],
            [element.text("Related Projects")],
          ),
          html.div(
            [class("space-y-3")],
            list.map(projects, related_project_card),
          ),
        ],
      )
  }
}

fn related_project_card(project: ProjectMetadata) -> Element(Nil) {
  html.a(
    [
      href("/project/" <> project.slug),
      class(
        "flex items-center gap-3 p-3 rounded-lg bg-gray-800/50 border border-transparent hover:border-cyan-400/30 transition-all group",
      ),
    ],
    [
      html.div([class("w-12 h-12 rounded-lg overflow-hidden flex-shrink-0")], [
        html.img([
          src("/" <> project.thumbnail),
          alt(project.title),
          class("w-full h-full object-cover"),
        ]),
      ]),
      html.div([class("flex-1 min-w-0")], [
        html.p(
          [
            class(
              "text-sm font-medium text-white truncate group-hover:text-cyan-400 transition-colors",
            ),
          ],
          [element.text(project.title)],
        ),
        html.p([class("text-xs text-gray-500 truncate")], [
          element.text(project.description),
        ]),
      ]),
    ],
  )
}

fn profile_section() -> Element(Nil) {
  html.section([attribute.id("about"), class("lg:sticky lg:top-24 space-y-6")], [
    // Profile card with glass effect
    html.div(
      [
        class(
          "bg-gray-800/50 backdrop-blur-sm rounded-2xl p-6 md:p-8 border border-gray-700/50 text-center",
        ),
      ],
      [
        // Avatar with ring effect
        html.div([class("mb-6")], [
          html.div(
            [
              class(
                "w-28 h-28 md:w-36 md:h-36 mx-auto rounded-full overflow-hidden ring-2 ring-cyan-400/20 ring-offset-4 ring-offset-gray-900",
              ),
            ],
            [
              html.img([
                src("/pfp.png"),
                alt("Mikaela Abril Dz"),
                class("w-full h-full object-cover"),
              ]),
            ],
          ),
        ]),
        // Name
        html.h1([class("text-2xl md:text-3xl font-bold mb-1")], [
          element.text("Mikaela Abril"),
          html.span([class("text-cyan-400")], [element.text("Dz")]),
        ]),
        // Role/Title
        html.p([class("text-cyan-400/80 text-sm font-medium mb-4")], [
          element.text("Game Designer & Developer"),
        ]),
        // Bio
        html.p([class("text-gray-400 text-sm leading-relaxed mb-6")], [
          element.text(
            "25 years old studying videogame design with a passion for creating experiences that bring together technical and artistic skills.",
          ),
        ]),
        // Skills tags
        html.div([class("mb-6")], [
          html.div([class("flex flex-wrap justify-center gap-2")], [
            skill_tag("Unity"),
            skill_tag("C#"),
            skill_tag("Game Design"),
            skill_tag("Level Design"),
            skill_tag("UI/UX"),
          ]),
        ]),
        // Social links row
        html.div([class("flex items-center justify-center gap-3")], [
          social_icon_link(
            "mailto:mikaelaabrildiazvlc@gmail.com",
            "Email",
            email_icon(),
          ),
          social_icon_link(
            "https://www.linkedin.com/in/mikaela-abril-diaz",
            "LinkedIn",
            linkedin_icon(),
          ),
          social_icon_link(
            "https://github.com/mikaelaabrildz",
            "GitHub",
            github_icon(),
          ),
          social_icon_link(
            "https://mikaelaabrildz.itch.io/",
            "Itch.io",
            itchio_icon(),
          ),
        ]),
      ],
    ),
    // Featured project (if exists)
    case get_sidebar_project() {
      option.Some(sidebar_project) ->
        html.div([], [
          html.a(
            [
              href("/project/" <> sidebar_project.slug),
              class(
                "block rounded-xl overflow-hidden hover:opacity-90 transition-opacity hover-glow",
              ),
            ],
            [
              html.div([class("relative")], [
                case sidebar_project.sidebar_image {
                  option.Some(img) ->
                    html.img([
                      src("/" <> img),
                      alt(sidebar_project.title),
                      class("w-full h-auto rounded-xl"),
                    ])
                  option.None ->
                    html.div(
                      [class("bg-yellow-400 rounded-xl p-4 md:p-6 relative")],
                      [
                        html.div([class("text-4xl md:text-6xl mb-3 md:mb-4")], [
                          element.text("👨‍🍳"),
                        ]),
                        html.h3(
                          [
                            class(
                              "text-xl md:text-2xl font-bold text-red-600 mb-2",
                            ),
                          ],
                          [element.text(sidebar_project.title)],
                        ),
                        html.div(
                          [
                            class(
                              "absolute bottom-3 right-3 md:bottom-4 md:right-4 w-12 h-12 md:w-16 md:h-16 bg-white rounded-full flex items-center justify-center",
                            ),
                          ],
                          [
                            html.span([class("text-3xl md:text-4xl")], [
                              element.text("▶"),
                            ]),
                          ],
                        ),
                      ],
                    )
                },
              ]),
            ],
          ),
        ])
      option.None -> element.none()
    },
  ])
}

fn skill_tag(label: String) -> Element(Nil) {
  html.span(
    [
      class(
        "px-3 py-1 text-xs font-medium text-cyan-400 bg-cyan-400/10 rounded-full border border-cyan-400/20 hover:bg-cyan-400/20 transition-colors",
      ),
    ],
    [element.text(label)],
  )
}

fn project_card(
  slug: String,
  title: String,
  description: String,
  _bg_color: String,
  thumbnail: String,
) -> Element(Nil) {
  html.a(
    [
      href("/project/" <> slug),
      class(
        "group block relative overflow-hidden rounded-xl aspect-[16/10] hover-glow",
      ),
    ],
    [
      // Background image
      html.img([
        src("/" <> thumbnail),
        alt(title),
        class(
          "absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105",
        ),
      ]),
      // Gradient overlay
      html.div(
        [
          class(
            "absolute inset-0 bg-gradient-to-t from-gray-900 via-gray-900/60 to-transparent",
          ),
        ],
        [],
      ),
      // Content at bottom
      html.div([class("absolute inset-x-0 bottom-0 p-4 md:p-6")], [
        html.h2(
          [
            class(
              "text-xl md:text-2xl font-bold text-white mb-2 group-hover:text-cyan-400 transition-colors",
            ),
            attribute.style("view-transition-name", "project-" <> slug),
          ],
          [element.text(title)],
        ),
        html.p(
          [
            class(
              "text-gray-300 text-sm md:text-base line-clamp-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300",
            ),
          ],
          [element.text(description)],
        ),
      ]),
      // Arrow indicator
      html.div(
        [
          class(
            "absolute top-4 right-4 w-10 h-10 bg-white/10 backdrop-blur-sm rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-300",
          ),
        ],
        [html.img([src("/Arrow.svg"), alt(""), class("w-5 h-5")])],
      ),
    ],
  )
}
