describe("extract_yaml_date", {
  it("extracts date from YAML front matter", {
    content <- paste(
      "---",
      "title: My Post",
      "date: 2024-03-15",
      "---",
      "Post body",
      sep = "\n"
    )
    expect_equal(extract_yaml_date(content), "2024-03-15")
  })

  it("handles quoted dates", {
    content <- paste(
      "---",
      "title: My Post",
      "date: '2024-03-15'",
      "---",
      sep = "\n"
    )
    expect_equal(extract_yaml_date(content), "2024-03-15")
  })

  it("handles double-quoted dates", {
    content <- paste(
      "---",
      'title: My Post',
      'date: "2024-03-15"',
      "---",
      sep = "\n"
    )
    expect_equal(extract_yaml_date(content), "2024-03-15")
  })

  it("returns NULL when no YAML front matter", {
    expect_null(extract_yaml_date("Just some text"))
  })

  it("returns NULL when no date field", {
    content <- paste(
      "---",
      "title: My Post",
      "author: Someone",
      "---",
      sep = "\n"
    )
    expect_null(extract_yaml_date(content))
  })

  it("returns NULL for empty content", {
    expect_null(extract_yaml_date(""))
  })

  it("handles date with extra whitespace", {
    content <- paste(
      "---",
      "date:   2024-03-15  ",
      "---",
      sep = "\n"
    )
    expect_equal(extract_yaml_date(content), "2024-03-15")
  })
})
