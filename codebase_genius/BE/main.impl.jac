sem CodeGenius.call_next_agent = """
Decide which agent to call based on the workflow stage:

Current state contains a 'stage' field that tracks workflow progress.

Route as follows:
- If stage is INIT or CLONING → REPO_HANDLER
- If stage is MAPPING → REPO_MAPPER  
- If stage is ANALYSIS → CODE_ANALYZER
- If stage is DOCS → DOC_GENIE
- If stage is COMPLETED → END
- Otherwise → END

Always check current_state['stage'] to determine the next agent.
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

# SEM instruction for overview generation
sem DocGenie.write_overview = """
Given a README summary, write a clear 2-3 paragraph project overview.

README Summary:
{readme_summary}

Focus on:
- What problem does this project solve?
- Main features and capabilities
- Target users or use cases

Write in a professional but approachable tone.
Do not use phrases like "This repository" or "This codebase" - just describe what it does.
""";

# SEM instruction for architecture analysis
sem DocGenie.write_architecture_section = """
Analyze the codebase structure and explain the architecture.

Statistics:
{json.dumps(stats, indent=2)}

Files:
{json.dumps(files[:5], indent=2)}  # Show first 5 files as example

Explain:
- Overall organization (how files/modules are structured)
- Key components and their roles
- Design patterns observed (if any)
- How the pieces fit together

Write 2-4 paragraphs. Be specific but concise.
""";