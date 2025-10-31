sem CodeGenius.call_next_agent = """
Decide which agent to call based on current_state:

- If 'repo_cloned' is False → REPO_HANDLER
- If 'mapping_done' is False → REPO_MAPPER
- If 'analysis_done' is False → CODE_ANALYZER
- If 'docs_done' is False → DOC_GENIE
- Else → END
""";
