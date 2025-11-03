sem CodeGenius.call_next_agent = """
Decide which agent to call based on current_state:

- If 'repo_cloned' is False → REPO_HANDLER
- If 'mapping_done' is False → REPO_MAPPER
- If 'analysis_done' is False → CODE_ANALYZER
- If 'docs_done' is False → DOC_GENIE
- Else → END
""";


sem RepoMapper.summarize_readme = """
Read the README.md (or similar entry file) and generate a concise summary.

- Identify all headings and subheadings to form an outline.
- Summarize each section briefly.
- Keep the introduction more detailed (around half of its original depth).
- Gradually shorten later sections.
- Focus on purpose, main features, setup, and structure.
- Output a markdown-style summary: 
  "## Section Title: short summary"

Keep the summary concise and accurate to the provided text.
Do not invent missing details.
""";


sem CodeAnalyzer.summarize_docstring = """
Read the given Python or Jac docstring and produce a concise summary (1-3 lines).  
Focus on purpose, input, and output — avoid restating the entire implementation.  
Example output: "Defines the main training loop and evaluation routine for the model."
""";
