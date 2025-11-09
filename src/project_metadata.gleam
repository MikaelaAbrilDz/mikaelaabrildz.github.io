import gleam/list
import gleam/option.{type Option, None, Some}

pub type ProjectMetadata {
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

pub fn get_all_projects() -> List(ProjectMetadata) {
  [
    ProjectMetadata(
      slug: "the-flying-rocket",
      title: "The Flying Rocket",
      description: "An arcade mobile game about infiltrating a mothership with innnovative controls based on forces.",
      bg_color: "bg-gradient-to-b from-blue-900 to-green-400",
      thumbnail: "flying-rocket.jpg",
      display_type: "",
      section_order: 1,
      project_order: 1,
      show_in_sidebar: False,
      sidebar_image: None,
    ),
    ProjectMetadata(
      slug: "ravioli-ravioli",
      title: "Ravioli, Ravioli",
      description: "A funny PC game about hitting clients in an italian restaurant.",
      bg_color: "bg-gradient-to-b from-yellow-200 to-yellow-400",
      thumbnail: "ravioli-ravioli.png",
      display_type: "chef",
      section_order: 2,
      project_order: 1,
      show_in_sidebar: False,
      sidebar_image: None,
    ),
    ProjectMetadata(
      slug: "the-wizards-tower",
      title: "The Wizard's Tower",
      description: "A simple 2D platformer for PC with a challenging mouse input twist.",
      bg_color: "bg-gradient-to-b from-purple-900 to-purple-600",
      thumbnail: "wizards-tower.png",
      display_type: "wizard",
      section_order: 3,
      project_order: 1,
      show_in_sidebar: False,
      sidebar_image: None,
    ),
  ]
}

pub fn get_all_sections() -> List(Section) {
  [
    Section(title: "MOBILE GAMES", order: 1),
    Section(title: "PC GAMES", order: 2),
    Section(title: "OTHER GAMES", order: 3),
  ]
}

pub fn get_sidebar_project() -> Option(ProjectMetadata) {
  get_all_projects()
  |> list.find(fn(p) { p.show_in_sidebar })
  |> option.from_result
}
