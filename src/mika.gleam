import content
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import gleam/uri.{type Uri}
import lustre
import lustre/attribute.{alt, class, href, src}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import modem
import project_metadata.{type ProjectMetadata}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type Model {
  Model(route: Route, projects: Dict(String, String))
}

type Route {
  Home
  Project(slug: String)
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let projects = content.get_projects()
  #(Model(route: Home, projects: projects), modem.init(on_route_change))
}

type Msg {
  OnRouteChange(Uri)
}

fn on_route_change(uri: Uri) -> Msg {
  OnRouteChange(uri)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(uri) -> {
      // Check if the path ends with .html and do a hard reload
      case string.ends_with(uri.path, ".html") {
        True -> #(model, modem.load(uri))
        False -> {
          let route = parse_route(uri)
          #(Model(..model, route: route), effect.none())
        }
      }
    }
  }
}

fn parse_route(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    ["project", slug] -> Project(slug: slug)
    _ -> Home
  }
}

fn view(model: Model) -> Element(Msg) {
  case model.route {
    Home -> home_view()
    Project(slug) -> project_view(model, slug)
  }
}

fn home_view() -> Element(Msg) {
  let projects = project_metadata.get_all_projects()
  let sections = project_metadata.get_all_sections()

  // Group projects by section and create elements with section titles
  let project_elements = build_projects_with_sections(projects, sections)

  html.div([class("min-h-screen bg-gray-900 text-white")], [
    html.div([class("container mx-auto px-4 py-6 md:py-12")], [
      html.div([class("flex flex-col lg:grid lg:grid-cols-3 gap-6 lg:gap-8")], [
        // Left column - Profile
        profile_section(),
        // Right column - Projects with section titles
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
) -> List(Element(Msg)) {
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

fn section_title(title: String) -> Element(Msg) {
  html.h2(
    [
      class(
        "text-xl md:text-2xl font-bold text-cyan-400 uppercase tracking-wider mt-6 first:mt-0 mb-4",
      ),
    ],
    [element.text(title)],
  )
}

fn project_card_from_metadata(meta: ProjectMetadata) -> Element(Msg) {
  project_card(
    meta.slug,
    meta.title,
    meta.description,
    meta.bg_color,
    meta.thumbnail,
  )
}

fn project_view(model: Model, slug: String) -> Element(Msg) {
  let content_html = case dict.get(model.projects, slug) {
    Ok(html_content) -> html_content
    Error(_) -> "<p>Project not found</p>"
  }

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
        [unsafe_html(content_html)],
      ),
    ]),
  ])
}

fn unsafe_html(html_string: String) -> Element(Msg) {
  element.unsafe_raw_html("", "div", [], html_string)
}

fn profile_section() -> Element(Msg) {
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
          [html.img([src("pfp.png")])],
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
                        src(img),
                        alt(sidebar_project.title),
                        class("w-full h-auto rounded-lg"),
                      ])
                    option.None ->
                      html.div(
                        [class("bg-yellow-400 rounded-lg p-4 md:p-6 relative")],
                        [
                          html.div(
                            [class("text-4xl md:text-6xl mb-3 md:mb-4")],
                            [element.text("👨‍🍳")],
                          ),
                          html.h3(
                            [
                              class(
                                "text-xl md:text-2xl font-bold text-red-600 mb-2",
                              ),
                            ],
                            [
                              element.text(sidebar_project.title),
                            ],
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
) -> Element(Msg) {
  html.a(
    [
      href("/project/" <> slug),
      class(
        "block bg-gray-800 rounded-lg overflow-hidden hover:transform hover:scale-105 transition-all duration-300 cursor-pointer relative",
      ),
    ],
    [
      html.div([class("flex flex-col sm:grid sm:grid-cols-3 gap-0 sm:gap-4")], [
        // Left - Game preview with thumbnail
        html.div([class("sm:col-span-1 h-20 sm:h-auto")], [
          html.div(
            [
              class(bg_color <> " h-full flex items-center justify-center"),
            ],
            [
              html.img([
                src(thumbnail),
                alt(title),
                class("w-full h-full object-cover"),
              ]),
            ],
          ),
        ]),
        // Right - Content
        html.div(
          [
            class(
              "sm:col-span-2 p-4 sm:p-6 flex flex-col justify-center relative",
            ),
          ],
          [
            html.h2(
              [
                class(
                  "text-xl sm:text-2xl md:text-3xl font-bold mb-2 sm:mb-4 pr-8",
                ),
              ],
              [element.text(title)],
            ),
            html.p(
              [
                class(
                  "text-gray-300 text-sm sm:text-base md:text-lg pr-8 sm:pr-16 line-clamp-3",
                ),
              ],
              [
                element.text(description),
              ],
            ),
            html.div(
              [
                class(
                  "absolute top-4 sm:top-1/2 right-4 sm:right-6 sm:transform sm:-translate-y-1/2",
                ),
              ],
              [
                html.span(
                  [class("text-cyan-400 text-3xl sm:text-4xl md:text-5xl")],
                  [element.text(">")],
                ),
              ],
            ),
          ],
        ),
      ]),
    ],
  )
}
