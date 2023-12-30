import gleeunit
import gleeunit/should
import gsv/internal/token.{
  CR, Comma, Doublequote, LF, Location, Textdata, scan, with_location,
}
import gsv/internal/ast.{ParseError, parse}
import gsv.{Unix, Windows}
import gleam/list
import gleam/result
import gleam/int
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn scan_test() {
  "Ben, 25,\" TRUE\r\n\""
  |> scan
  |> should.equal([
    Textdata("Ben"),
    Comma,
    Textdata(" 25"),
    Comma,
    Doublequote,
    Textdata(" TRUE"),
    CR,
    LF,
    Doublequote,
  ])
}

pub fn parse_test() {
  "Ben, 25,\" TRUE\n\r\"\"\"\nAustin, 25, FALSE"
  |> scan
  |> with_location
  |> parse
  |> should.equal(
    Ok([["Ben", " 25", " TRUE\n\r\""], ["Austin", " 25", " FALSE"]]),
  )
}

pub fn parse_empty_string_fail_test() {
  ""
  |> scan
  |> with_location
  |> parse
  |> result.nil_error
  |> should.equal(Error(Nil))
}

pub fn csv_parse_test() {
  "Ben, 25,\" TRUE\n\r\"\"\"\nAustin, 25, FALSE"
  |> gsv.to_lists
  |> should.equal(
    Ok([["Ben", " 25", " TRUE\n\r\""], ["Austin", " 25", " FALSE"]]),
  )
}

pub fn scan_crlf_test() {
  "\r\n"
  |> scan
  |> should.equal([CR, LF])
}

pub fn parse_crlf_test() {
  "test\ntest\r\ntest"
  |> gsv.to_lists
  |> should.equal(Ok([["test"], ["test"], ["test"]]))
}

pub fn parse_lfcr_fails_test() {
  "test\n\r"
  |> gsv.to_lists
  |> should.equal(Error(Nil))
}

pub fn last_line_has_optional_line_ending_test() {
  "test\ntest\r\ntest\n"
  |> gsv.to_lists
  |> should.equal(Ok([["test"], ["test"], ["test"]]))
}

// ---------- Example doing CSV string -> Custom type ------------------------
pub type User {
  User(name: String, age: Int)
}

fn from_list(record: List(String)) -> Result(User, Nil) {
  use name <- result.try(list.at(record, 0))
  use age_str <- result.try(list.at(record, 1))
  use age <- result.try(int.parse(string.trim(age_str)))
  Ok(User(name, age))
}

pub fn decode_to_type_test() {
  let assert Ok(lls) =
    "Ben, 25\nAustin, 21"
    |> gsv.to_lists
  let users =
    list.fold(lls, [], fn(acc, record) { [from_list(record), ..acc] })
    |> list.reverse

  users
  |> should.equal([Ok(User("Ben", 25)), Ok(User("Austin", 21))])
}

// ---------------------------------------------------------------------------

pub fn encode_test() {
  let assert Ok(lls) = gsv.to_lists("Ben, 25\nAustin, 21")
  lls
  |> gsv.from_lists(separator: ",", line_ending: Unix)
  |> should.equal("Ben, 25\nAustin, 21")
}

pub fn encode_with_escaped_string_test() {
  let assert Ok(lls) =
    "Ben, 25,\" TRUE\n\r\"\" \"\nAustin, 25, FALSE"
    |> gsv.to_lists

  lls
  |> gsv.from_lists(separator: ",", line_ending: Unix)
  |> should.equal("Ben, 25,\" TRUE\n\r\"\" \"\nAustin, 25, FALSE")
}

pub fn encode_with_escaped_string_windows_test() {
  let assert Ok(lls) =
    "Ben, 25,\" TRUE\n\r\"\" \"\nAustin, 25, FALSE"
    |> gsv.to_lists

  lls
  |> gsv.from_lists(separator: ",", line_ending: Windows)
  |> should.equal("Ben, 25,\" TRUE\n\r\"\" \"\r\nAustin, 25, FALSE")
}

pub fn for_the_readme_test() {
  let csv_str = "Hello, World\nGoodbye, Mars"

  // Parse a CSV string to a List(List(String))
  let assert Ok(records) = gsv.to_lists(csv_str)

  // Write a List(List(String)) to a CSV string
  records
  |> gsv.from_lists(separator: ",", line_ending: Windows)
  |> should.equal("Hello, World\r\nGoodbye, Mars")
}

pub fn error_cases_test() {
  let produce_error = fn(csv_str) {
    case
      csv_str
      |> scan
      |> with_location
      |> parse
    {
      Ok(_) -> panic as "Expected an error"
      Error(ParseError(loc, msg)) -> #(loc, msg)
    }
  }

  produce_error("Ben, 25,, TRUE")
  |> should.equal(#(
    Location(1, 9),
    "Expected escaped or non-escaped string after comma, found: ,",
  ))
  produce_error("Austin, 25, FALSE\n\"Ben Peinhardt\", 25,, TRUE")
  |> should.equal(#(
    Location(2, 21),
    "Expected escaped or non-escaped string after comma, found: ,",
  ))
}

// pub fn totally_panics_test() {
//   "Ben, 25,, TRUE" |> gsv.to_lists_or_panic
// }

pub fn totally_errors_test() {
  "Ben, 25,, TRUE"
  |> gsv.to_lists_or_error
  |> should.equal(Error(
    "[line 1 column 9] of csv: Expected escaped or non-escaped string after comma, found: ,",
  ))
}
