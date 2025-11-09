import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import jot
import simplifile
import tom

pub fn main() {
  io.println("🔨 Building content and metadata modules...")

  let content_result = generate_content_module()
  let metadata_result = generate_metadata_module()

  case content_result, metadata_result {
    Ok(_), Ok(_) -> {
      io.println("✅ All modules generated successfully!")
      Nil
    }
    Error(err), _ -> {
      io.println("❌ Error generating content module:")
      io.println(err)
      Nil
    }
    _, Error(err) -> {
      io.println("❌ Error generating metadata module:")
      io.println(err)
      Nil
    }
  }
}

fn generate_content_module() -> Result(Nil, String) {
  // Read all .dj files from content/projects/
  use files <- result.try(
    simplifile.read_directory("content/projects")
    |> result.map_error(fn(_) { "Failed to read content/projects directory" }),
  )

  // Filter only .dj files
  let djot_files =
    files
    |> list.filter(fn(file) { string.ends_with(file, ".dj") })

  // Read and compile Djot files to HTML
  use content_dict <- result.try(read_and_compile_files(djot_files))

  // Generate Gleam module
  let module_content = generate_gleam_module(content_dict)

  // Write to src/content.gleam
  simplifile.write("src/content.gleam", module_content)
  |> result.map_error(fn(_) { "Failed to write src/content.gleam" })
}

fn read_and_compile_files(
  files: List(String),
) -> Result(Dict(String, String), String) {
  files
  |> list.try_fold(dict.new(), fn(acc, file) {
    let slug = string.replace(file, ".dj", "")
    let path = "content/projects/" <> file

    use djot_content <- result.try(
      simplifile.read(path)
      |> result.map_error(fn(_) { "Failed to read " <> path }),
    )

    // Compile Djot to HTML
    let html_content = echo jot.to_html(djot_content)

    Ok(dict.insert(acc, slug, html_content))
  })
}

fn generate_gleam_module(content: Dict(String, String)) -> String {
  let imports =
    "import gleam/dict.{type Dict}

"

  let function_start =
    "pub fn get_projects() -> Dict(String, String) {
  dict.from_list([
"

  let entries =
    content
    |> dict.to_list()
    |> list.map(fn(entry) {
      let #(slug, content) = entry
      let escaped_content = escape_string(content)
      "    #(\"" <> slug <> "\", \"" <> escaped_content <> "\"),"
    })
    |> string.join("\n")

  let function_end =
    "
  ])
}
"

  imports <> function_start <> entries <> function_end
}

fn escape_string(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

// Metadata generation from TOML

type ProjectMetadata {
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

type Section {
  Section(title: String, order: Int)
}

fn generate_metadata_module() -> Result(Nil, String) {
  // Read TOML config
  use toml_content <- result.try(
    simplifile.read("content/projects.toml")
    |> result.map_error(fn(_) { "Failed to read content/projects.toml" }),
  )

  // Parse TOML
  use parsed <- result.try(
    tom.parse(toml_content)
    |> result.map_error(fn(_) { "Failed to parse TOML" }),
  )

  // Extract sections and projects
  use sections <- result.try(parse_sections(parsed))
  use projects <- result.try(parse_projects(parsed))

  // Generate Gleam module
  let module_content = generate_metadata_gleam_module(sections, projects)

  // Write to src/project_metadata.gleam
  simplifile.write("src/project_metadata.gleam", module_content)
  |> result.map_error(fn(_) { "Failed to write src/project_metadata.gleam" })
}

fn parse_sections(toml: Dict(String, tom.Toml)) -> Result(List(Section), String) {
  case dict.get(toml, "section") {
    Ok(tom.ArrayOfTables(sections)) -> {
      sections
      |> list.try_map(parse_section)
    }
    _ -> Ok([])
    // Sections are optional
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
    Ok(tom.ArrayOfTables(projects)) -> {
      projects
      |> list.try_map(parse_project)
    }
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

  Ok(ProjectMetadata(
    slug: slug,
    title: title,
    description: description,
    bg_color: bg_color,
    thumbnail: thumbnail,
    display_type: display_type,
    section_order: section_order,
    project_order: project_order,
    show_in_sidebar: show_in_sidebar,
    sidebar_image: sidebar_image,
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

fn generate_metadata_gleam_module(
  sections: List(Section),
  projects: List(ProjectMetadata),
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

  imports <> type_defs <> function_start <> entries <> "
  ]
}

" <> sections_start <> section_entries <> function_end
}
