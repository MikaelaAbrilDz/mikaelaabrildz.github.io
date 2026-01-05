import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import lustre/attribute.{alt, class, href, src}
import lustre/element.{type Element}
import lustre/element/html
import lustre/ssg
import lustre/ssg/djot
import project_metadata.{type ProjectMetadata}
import simplifile
import tom

pub fn main() {
  // Step 1: Regenerate metadata module from TOML
  io.println("Generating metadata...")
  case generate_metadata_module() {
    Ok(_) -> io.println("Metadata generated!")
    Error(err) -> {
      io.println("Error generating metadata: " <> err)
      panic as "Failed to generate metadata"
    }
  }

  // Step 2: Build the static site
  io.println("Building site...")
  let all_projects = project_metadata.get_all_projects()

  let build =
    ssg.new("dist")
    |> ssg.add_static_dir("assets")
    |> ssg.use_index_routes
    |> ssg.add_static_route("/", page_layout("Mikaela's Portfolio", home_view()))
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
// Metadata Generation
// ============================================================================

type MetaProject {
  MetaProject(
    slug: String,
    title: String,
    description: String,
    bg_color: String,
    thumbnail: String,
    display_type: String,
    section_order: Int,
    project_order: Int,
    show_in_sidebar: Bool,
    sidebar_image: Option(String),
  )
}

type Section {
  Section(title: String, order: Int)
}

fn generate_metadata_module() -> Result(Nil, String) {
  use toml_content <- result.try(
    simplifile.read("content/projects.toml")
    |> result.map_error(fn(_) { "Failed to read content/projects.toml" }),
  )

  use parsed <- result.try(
    tom.parse(toml_content)
    |> result.map_error(fn(_) { "Failed to parse TOML" }),
  )

  use sections <- result.try(parse_sections(parsed))
  use projects <- result.try(parse_projects(parsed))

  let module_content = generate_metadata_gleam_module(sections, projects)

  simplifile.write("src/project_metadata.gleam", module_content)
  |> result.map_error(fn(_) { "Failed to write src/project_metadata.gleam" })
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
) -> Result(List(MetaProject), String) {
  case dict.get(toml, "project") {
    Ok(tom.ArrayOfTables(projects)) -> list.try_map(projects, parse_project)
    _ -> Error("No 'project' array of tables found in TOML")
  }
}

fn parse_project(table: Dict(String, tom.Toml)) -> Result(MetaProject, String) {
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

  Ok(MetaProject(
    slug:,
    title:,
    description:,
    bg_color:,
    thumbnail:,
    display_type:,
    section_order:,
    project_order:,
    show_in_sidebar:,
    sidebar_image:,
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

fn escape_string(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

fn generate_metadata_gleam_module(
  sections: List(Section),
  projects: List(MetaProject),
) -> String {
  let imports =
    "import gleam/list
import gleam/option.{type Option, None, Some}

"

  let type_defs =
    "pub type ProjectMetadata {
  ProjectMetadata(
    slug: String,
    title: String,
    description: String,
    bg_color: String,
    thumbnail: String,
    display_type: String,
    section_order: Int,
    project_order: Int,
    show_in_sidebar: Bool,
    sidebar_image: Option(String),
  )
}

pub type Section {
  Section(title: String, order: Int)
}

"

  let sorted_sections =
    list.sort(sections, fn(a, b) { int.compare(a.order, b.order) })
  let sorted_projects =
    list.sort(projects, fn(a, b) {
      case int.compare(a.section_order, b.section_order) {
        order.Eq -> int.compare(a.project_order, b.project_order)
        other -> other
      }
    })

  let function_start =
    "pub fn get_all_projects() -> List(ProjectMetadata) {
  [
"

  let entries =
    sorted_projects
    |> list.map(fn(p) {
      let sidebar_img = case p.sidebar_image {
        Some(img) -> "Some(\"" <> img <> "\")"
        None -> "None"
      }

      "    ProjectMetadata(
      slug: \"" <> p.slug <> "\",
      title: \"" <> escape_string(p.title) <> "\",
      description: \"" <> escape_string(p.description) <> "\",
      bg_color: \"" <> p.bg_color <> "\",
      thumbnail: \"" <> p.thumbnail <> "\",
      display_type: \"" <> p.display_type <> "\",
      section_order: " <> int.to_string(p.section_order) <> ",
      project_order: " <> int.to_string(p.project_order) <> ",
      show_in_sidebar: " <> case p.show_in_sidebar {
        True -> "True"
        False -> "False"
      } <> ",
      sidebar_image: " <> sidebar_img <> ",
    ),"
    })
    |> string.join("\n")

  let sections_start =
    "pub fn get_all_sections() -> List(Section) {
  [
"

  let section_entries =
    sorted_sections
    |> list.map(fn(s) {
      "    Section(title: \""
      <> escape_string(s.title)
      <> "\", order: "
      <> int.to_string(s.order)
      <> "),"
    })
    |> string.join("\n")

  let function_end =
    "
  ]
}

pub fn get_sidebar_project() -> Option(ProjectMetadata) {
  get_all_projects()
  |> list.find(fn(p) { p.show_in_sidebar })
  |> option.from_result
}
"

  imports
  <> type_defs
  <> function_start
  <> entries
  <> "
  ]
}

"
  <> sections_start
  <> section_entries
  <> function_end
}

// ============================================================================
// Site Building
// ============================================================================

fn add_project_routes(config, all_projects: List(ProjectMetadata)) {
  list.fold(all_projects, config, fn(acc, project) {
    let content_elements = read_and_render_djot(project.slug)
    let view = project_view(project, content_elements)
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
      html.link([attribute.rel("stylesheet"), href("/mika.css")]),
    ]),
    html.body([], [content]),
  ])
}

fn home_view() -> Element(Nil) {
  let projects = project_metadata.get_all_projects()
  let sections = project_metadata.get_all_sections()
  let project_elements = build_projects_with_sections(projects, sections)

  html.div([class("min-h-screen bg-gray-900 text-white")], [
    html.div([class("container mx-auto px-4 py-6 md:py-12")], [
      html.div([class("flex flex-col lg:grid lg:grid-cols-3 gap-6 lg:gap-8")], [
        profile_section(),
        html.div(
          [class("lg:col-span-2 space-y-4 md:space-y-8")],
          project_elements,
        ),
      ]),
    ]),
  ])
}

fn build_projects_with_sections(
  projects: List(ProjectMetadata),
  sections: List(project_metadata.Section),
) -> List(Element(Nil)) {
  sections
  |> list.flat_map(fn(section) {
    let section_projects =
      projects
      |> list.filter(fn(p) { p.section_order == section.order })
      |> list.map(project_card_from_metadata)

    case section_projects {
      [] -> []
      _ -> [section_title(section.title), ..section_projects]
    }
  })
}

fn section_title(title: String) -> Element(Nil) {
  html.h2(
    [
      class(
        "text-xl md:text-2xl font-bold text-cyan-400 uppercase tracking-wider mt-6 first:mt-0 mb-4",
      ),
    ],
    [element.text(title)],
  )
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
  _project: ProjectMetadata,
  content_elements: List(Element(Nil)),
) -> Element(Nil) {
  html.div([class("min-h-screen bg-gray-900 text-white")], [
    html.div([class("container mx-auto px-4 py-6 md:py-12 max-w-4xl")], [
      html.div([class("mb-6 md:mb-8")], [
        html.a(
          [
            href("/"),
            class(
              "text-cyan-400 hover:text-cyan-300 transition-colors inline-flex items-center gap-2 text-sm md:text-base",
            ),
          ],
          [element.text("← Back to home")],
        ),
      ]),
      html.div(
        [
          class(
            "bg-gray-800 rounded-lg p-4 md:p-8 prose prose-invert prose-cyan max-w-none",
          ),
        ],
        content_elements,
      ),
    ]),
  ])
}

fn profile_section() -> Element(Nil) {
  html.div(
    [class("bg-gray-800 rounded-lg p-6 md:p-8 text-center mobile-sticky")],
    [
      html.div([class("mb-4 md:mb-6")], [
        html.div(
          [
            class(
              "w-32 h-32 md:w-48 md:h-48 mx-auto rounded-full overflow-hidden bg-gray-700",
            ),
          ],
          [html.img([src("/pfp.png")])],
        ),
      ]),
      html.h1([class("text-2xl md:text-3xl font-bold mb-2")], [
        element.text("MikaelaAbril"),
        html.span([class("text-cyan-400")], [element.text("Dz")]),
      ]),
      html.p([class("text-gray-300 text-xs md:text-sm leading-relaxed")], [
        element.text(
          "25 years old studying videogame design with a passion for creating experiences and bring together technical and artistic skills.",
        ),
      ]),
      html.a(
        [
          class(
            "inline-block mt-4 md:mt-6 text-cyan-400 underline hover:text-cyan-300 transition-colors text-sm md:text-base",
          ),
          attribute.href("mailto:mikaelaabrildiazvlc@gmail.com"),
        ],
        [element.text("Contact me")],
      ),
      case project_metadata.get_sidebar_project() {
        option.Some(sidebar_project) ->
          html.div([class("mt-6 md:mt-8")], [
            html.a(
              [
                href("/project/" <> sidebar_project.slug),
                class(
                  "block rounded-lg overflow-hidden hover:opacity-90 transition-opacity",
                ),
              ],
              [
                html.div([class("relative")], [
                  case sidebar_project.sidebar_image {
                    option.Some(img) ->
                      html.img([
                        src("/" <> img),
                        alt(sidebar_project.title),
                        class("w-full h-auto rounded-lg"),
                      ])
                    option.None ->
                      html.div(
                        [class("bg-yellow-400 rounded-lg p-4 md:p-6 relative")],
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
    ],
  )
}

fn project_card(
  slug: String,
  title: String,
  description: String,
  bg_color: String,
  thumbnail: String,
) -> Element(Nil) {
  html.a(
    [
      href("/project/" <> slug),
      class(
        "block bg-gray-800 rounded-lg overflow-hidden hover:transform hover:scale-105 transition-all duration-300 cursor-pointer relative",
      ),
    ],
    [
      html.div([class("flex flex-col sm:grid sm:grid-cols-3 gap-0 sm:gap-4")], [
        html.div([class("sm:col-span-1 h-20 sm:h-auto")], [
          html.div(
            [class(bg_color <> " h-full flex items-center justify-center")],
            [
              html.img([
                src("/" <> thumbnail),
                alt(title),
                class("w-full h-full object-cover"),
              ]),
            ],
          ),
        ]),
        html.div(
          [
            class(
              "sm:col-span-2 p-4 sm:p-6 flex flex-col justify-center relative",
            ),
          ],
          [
            html.h2(
              [
                class("project-title pr-8"),
                attribute.style("view-transition-name", "project-" <> slug),
              ],
              [element.text(title)],
            ),
            html.p(
              [
                class(
                  "text-gray-300 text-sm sm:text-base md:text-lg pr-8 sm:pr-16 line-clamp-3",
                ),
              ],
              [element.text(description)],
            ),
            html.div(
              [
                class(
                  "absolute top-4 sm:top-1/2 right-4 sm:right-6 sm:transform sm:-translate-y-1/2",
                ),
              ],
              [
                html.img([
                  src("/Arrow.svg"),
                  alt(""),
                  class("w-6 h-6 sm:w-8 sm:h-8 md:w-10 md:h-10"),
                ]),
              ],
            ),
          ],
        ),
      ]),
    ],
  )
}
