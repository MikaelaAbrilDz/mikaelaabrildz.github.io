import gleam/io
import gleam/string
import jot

pub fn main() {
  let doc = "# Heading {style=\"color: red\"}"
  let parsed = jot.parse(doc)
  io.debug(parsed)
}
