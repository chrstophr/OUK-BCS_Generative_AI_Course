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
  "## Section Title:"

Keep the summary concise and accurate to the provided text.
Do not invent missing details.
""";




sem CodeAnalyzer.summarize_docstring = """
Read the given Python or Jac docstring and produce a concise summary (1-3 lines).  
Focus on purpose, input, and output — avoid restating the entire implementation.  
Example output: "Defines the main training loop and evaluation routine for the model."
""";




sem DocGenie.write_overview = """
Given a README summary, write a clear 2-3 paragraph project overview.

README Summary:
{readme_summary}

Statistics:
- Files: {stats.get('total_files')}
- Classes: {stats.get('total_classes')}
- Functions: {stats.get('total_functions')}

Focus on:
- What problem does this project solve?
- Main features and capabilities
- Target users or use cases

Write in third person. Be concise but informative.
Do not use phrases like "This repository" - just describe what the software does.
""";

sem DocGenie.write_installation = """
Generate installation instructions based on the README summary.

README Summary:
{readme_summary}

Provide clear steps for:
1. Prerequisites (Python version, system requirements)
2. Cloning/downloading the repository
3. Setting up virtual environment
4. Installing dependencies
5. Any environment variables or configuration needed

Format as numbered steps or bullet points. Be specific and actionable.
""";

sem DocGenie.write_usage = """
Generate usage instructions for this codebase.

README Summary:
{readme_summary}

Entry Point Files:
{entry_points}

Explain:
- How to run the main application
- Common use cases or examples
- Command-line arguments (if applicable)
- Expected output

Provide code examples where relevant. Keep it practical and beginner-friendly.
""";

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
- How the modules interact

Be specific about class relationships and file organization.
Write for developers who need to understand the codebase quickly.
""";