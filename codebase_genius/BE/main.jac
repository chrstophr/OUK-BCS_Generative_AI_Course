import os;
import git;
import tempfile;
import json;
import time;
import from typing { List }
#import from agent_core { Memory, Session, agent, get_all_sessions }
import from byllm.llm { Model }
#import from nodes.repo_handler { RepoHandler }
import sys;
import from graphviz { Digraph }
import from tree_sitter { Language, Parser }
include analyzer_utils;
include agent_core;
#import from analyzer_utils { run_analysis }


glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

enum AgentTypes {
    REPO_HANDLER,
    REPO_MAPPER,
    CODE_ANALYZER,
    DOC_GENIE,
    END
}

sem AgentTypes.REPO_HANDLER = "Validates and clones the GitHub repository.";
sem AgentTypes.REPO_MAPPER = "Analyzes the repository structure and summarizes the README.";
sem AgentTypes.CODE_ANALYZER = "Performs call-graph and logic analysis on code modules.";
sem AgentTypes.DOC_GENIE = "Generates the final documentation.";
sem AgentTypes.END = "Workflow termination after documentation is complete.";


enum WorkflowStage {
    INIT,
    CLONING,
    MAPPING,
    ANALYSIS,
    DOCS,
    COMPLETED
}

sem WorkflowStage.INIT = "Workflow starts with a GitHub URL input.";
sem WorkflowStage.CLONING = "RepoHandler validates and clones the repository.";
sem WorkflowStage.MAPPING = "RepoMapper creates structural and README summary.";
sem WorkflowStage.ANALYSIS = "CodeAnalyzer performs deep analysis.";
sem WorkflowStage.DOCS = "DocGenie produces documentation.";
sem WorkflowStage.COMPLETED = "Workflow ends.";


def log_progress(agent: str, message: str) {
    with open("outputs/workflow_log.jsonl", "a") as f {
        rec = {
            "ts": int(time.time()),
            "agent": agent,
            "message": message
        };
        f.write(json.dumps(rec, ensure_ascii=False));
        f.write("\n");
    }
}


node CodeGenius {
    def call_next_agent(current_state: dict) -> AgentTypes by llm(method="Reason");
}


node Agent {
    has agent_type: AgentTypes;
}

node RepoHandler(Agent) {
    has agent_type: AgentTypes = AgentTypes.REPO_HANDLER;
    """
    Supports Both Local and Remote Repositories
    Features:
    - ✅ Analyzes local directories (relative or absolute paths)
    - ✅ Clones GitHub repositories (https URLs)
    - ✅ Auto-detects input type
    - ✅ Reuses existing clones
    - ✅ Proper error handling
    """
    def validate_and_clone_repo(repo_input: str) -> str {
        
        ::py::
        # Detect input type
        is_url = repo_input.startswith("http://") or repo_input.startswith("https://")
        
        if not is_url:
            # CASE A: Local Path
            print(f"📁 Detected local path: {repo_input}")
            # Convert to absolute path
            repo_path = os.path.abspath(repo_input)
            # Validate it exists
            if not os.path.exists(repo_path):
                print(f"❌ Error: Path does not exist: {repo_path}")
                return ""
            if not os.path.isdir(repo_path):
                print(f"❌ Error: Path is not a directory: {repo_path}")
                return ""
            print(f"✅ Using local repository at {repo_path}")
            return repo_path
        
        else:
            # CASE B: GitHub URL
            print(f"🌐 Detected GitHub URL: {repo_input}")
            # Extract repository name from URL
            repo_name = os.path.basename(repo_input.rstrip("/")).replace(".git", "")
            # Define target directory in outputs/repos/
            base_dir = os.path.join(os.getcwd(), "outputs", "repos")
            os.makedirs(base_dir, exist_ok=True)
            target_dir = os.path.join(base_dir, repo_name)
            
            # Check if already cloned
            if os.path.exists(target_dir) and os.path.isdir(os.path.join(target_dir, ".git")):
                print(f"♻️ Reusing existing clone at {target_dir}")
                return target_dir
            
            # Clone the repository
            try:
                print(f"🚀 Cloning repository from {repo_input}...")
                git.Repo.clone_from(repo_input, target_dir)
                print(f"✅ Repository cloned successfully at {target_dir}")
                return target_dir
            except git.GitCommandError as e:
                print(f"❌ Error cloning repository: {e}")
                print(f"   Possible causes:")
                print(f"   - Invalid URL")
                print(f"   - Private repository (requires authentication)")
                print(f"   - Network connection issues")
                return ""
            except Exception as e:
                print(f"❌ Unexpected error: {e}")
                return ""
        
        ::py::
    }

    can execute_clone with supervisor entry {
        visitor.session.add_agent_execution("REPO_HANDLER");
        repo_input = visitor.utterance;

        print(f"{'='*60}");
        print(f"🔍 REPO HANDLER: Validating input");
        print(f"{'='*60}");
        print(f"Input: {repo_input}");

        # Validate and get repository path
        repo_path = self.validate_and_clone_repo(repo_input);
        
        if repo_path != "" {
            visitor.session.current_state["repo_cloned"] = True;
            visitor.session.current_state["repo_path"] = repo_path;
            visitor.session.current_state["stage"] = WorkflowStage.MAPPING;
            
            print(f"✅ Repository ready for analysis!");
            print(f"📂 Path: {repo_path}");
        } else {
            visitor.session.current_state["repo_cloned"] = False;
            print(f"❌ Repository validation failed. Stopping workflow.");
        }

        visit [<--](`?CodeGenius);
    }
}


node RepoMapper(Agent) {
    has agent_type: AgentTypes = AgentTypes.REPO_MAPPER;

    # ----------------------------------------
    #  Build Clean File Tree
    # ----------------------------------------
    def generate_repo_structure(repo_path: str) -> str {
        # Traverse the repository and return a clean ASCII tree structure.
        def traverse(path: str, prefix: str = "") -> str {
            output = "";
            # read raw entries then filter
            raw_entries = os.listdir(path);
            raw_entries.sort();

            # filter out hidden/irrelevant entries
            visible = [];
            for entry in raw_entries {
                if entry.startswith(".") { continue; }
                if entry in ["__pycache__", "venv", "node_modules", "dist", "build", ".idea", ".vscode"] { continue; }
                visible = visible + [entry];
            }

            for (index, entry) in enumerate(visible) {
                full_path = os.path.join(path, entry);

                connector = "└── " if index == len(visible) - 1 else "├── ";
                output += prefix + connector + entry + "\n";

                if os.path.isdir(full_path) and not os.path.islink(full_path) {
                    extension = "    " if index == len(visible) - 1 else "│   ";
                    output += traverse(full_path, prefix + extension);
                }
            }
            return output;
        }

        print(f"📂 Scanning repository at {repo_path}...");
        return traverse(repo_path);
    }

    # ----------------------------------------
    #  Summarize README or Entry Doc
    # ----------------------------------------
    def summarize_readme(readme_content: str) -> str by llm(method="Reason");


    # ----------------------------------------
    #  Execute Repo Mapping
    # ----------------------------------------
    can execute_mapping with supervisor entry {
        visitor.session.add_agent_execution("REPO_MAPPER");

        repo_path = visitor.session.current_state.get("repo_path", "");
        if not repo_path {
            print("❌ No repository path found — skipping mapping.");
            visit [<--](`?CodeGenius);
            return;
        }

        # ✅ Reuse cached outputs if they already exist
        cached_output = "outputs/repo_mapper_output.json";
        if os.path.exists(cached_output) {
            print(f"♻️ Reusing existing mapping output from {cached_output}");
            with open(cached_output, "r", encoding="utf-8") as f {
                cached = json.load(f);
            }
            visitor.session.current_state["repo_structure"] = cached.get("repo_structure", "");
            visitor.session.current_state["readme_summary"] = cached.get("readme_summary", {"summary": ""});
            visitor.session.current_state["mapping_done"] = True;
            visitor.session.current_state["stage"] = WorkflowStage.ANALYSIS;
            print(f"♻️ Reused mapping output — passing to Supervisor.");
            visit [<--](`?CodeGenius);
            return;
        }

        # Step 1: Build file/folder tree
        repo_structure = self.generate_repo_structure(repo_path);

        # Step 2: Find README or similar entry doc
        readme_summary = {};
        possible_names = ["README.md", "Readme.md", "readme.md", "index.md"];
        readme_file = "";

        for name in possible_names {
            path = os.path.join(repo_path, name);
            if os.path.exists(path) {
                readme_file = path;
                break;
            }
        }

        if readme_file != "" {
            print(f"📖 Found {readme_file} — summarizing content...");

            with open(readme_file, "r", encoding="utf-8") as f {
                readme_content = f.read();
            }

            # Summarize the file using byllm
            readme_summary = self.summarize_readme(readme_content);
        } else {
            print("⚠️ No README.md or entry document found in repository.");
            readme_summary = {"summary": "No README found.", "features": [], "installation": "", "usage": "", "notes": ""};
        }

        # Preview
        print("========== 🧭 REPO MAPPER OUTPUT PREVIEW ==========");
        print("📁 REPO STRUCTURE:");
        print(repo_structure);
        print("📝 README SUMMARY:");
        print(str(readme_summary));
        print("===================================================");


        # Step 3: Save mapping data to session
        visitor.session.current_state["repo_structure"] = repo_structure;
        visitor.session.current_state["readme_summary"] = readme_summary;
        visitor.session.current_state["mapping_done"] = True;
        visitor.session.current_state["stage"] = WorkflowStage.ANALYSIS;


        # save outputs to JSON file

        output_path = os.path.join("outputs", "repo_mapper_output.json");
        with open(output_path, "w", encoding="utf-8") as f {
            json.dump({
                "repo_path": repo_path,
                "repo_structure": repo_structure,
                "readme_summary": readme_summary
            }, f, ensure_ascii=False, indent=2);
        }
        print(f"📁 RepoMapper output saved to {output_path}");


        print("✅ Repo mapping complete. Passing results to Supervisor.");
        visit [<--](`?CodeGenius);
    }
}



node CodeAnalyzer(Agent) {
    has agent_type: AgentTypes = AgentTypes.CODE_ANALYZER;

    """
    Focus:
    1. Parse code
    2. Analyze relationships (calls, inheritance)
    3. Provide query APIs
    """

    # ------------------------------------------------
    # Run analysis via Python module
    # ------------------------------------------------
    def run_code_analysis(repo_path: str) -> dict {
        ::py::
        from analyzer_utils import run_analysis
        result = run_analysis(repo_path)
        return result
        ::py::
    }

    # ------------------------------------------------
    # Query API 1: Who calls this function?
    # ------------------------------------------------
    def get_callers(function_name: str) -> list {

        analysis_data = visitor.session.current_state.get("analysis_data", {});
        call_graph = analysis_data.get("call_graph", {});
        
        callers = [];
        for (caller, callees) in call_graph.items() {
            if function_name in callees {
                callers = callers + [caller];
            }
        }
        
        return callers;
    }

    # ------------------------------------------------
    # Query API 2: What does this function call?
    # ------------------------------------------------
    def get_callees(function_name: str) -> list {

        analysis_data = visitor.session.current_state.get("analysis_data", {});
        call_graph = analysis_data.get("call_graph", {});
        
        return call_graph.get(function_name, []);
    }

    # ------------------------------------------------
    # Query API 3: Get entities from specific file
    # ------------------------------------------------
    def get_file_entities(filename: str) -> dict {

        analysis_data = visitor.session.current_state.get("analysis_data", {});
        files = analysis_data.get("files", []);
        
        for file_info in files {
            if filename in file_info.get("file", "") {
                return file_info;
            }
        }
        
        return {"file": filename, "functions": [], "classes": []};
    }

    # -----------------------------------------------------------------
    # Query API 4: List all functions or classes across the codebase
    # -----------------------------------------------------------------
    def list_entities(entity_type: str = "function") -> list {

        analysis_data = visitor.session.current_state.get("analysis_data", {});
        files = analysis_data.get("files", []);
        
        results = [];
        for file_info in files {
            if entity_type == "function" {
                for func in file_info.get("functions", []) {
                    results = results + [func];
                }
            } elif entity_type == "class" {
                for cls in file_info.get("classes", []) {
                    results = results + [cls];
                }
            }
        }
        
        return results;
    }

    # ------------------------------------------------
    # Query API 5: Get summary statistics
    # ------------------------------------------------
    def get_stats(analysis_data: dict) -> dict {

        return analysis_data.get("stats", {
            "total_files": 0,
            "total_classes": 0,
            "total_functions": 0,
            "total_calls": 0
        });
    }

    # ------------------------------------------------
    # Helper: Print analysis summary
    # ------------------------------------------------
    def print_summary(analysis_data: dict) {
        #Print a formatted summary of the analysis results.
        stats = self.get_stats(analysis_data);
        graphs = analysis_data.get("graphs", {});
        
        print("="*60);
        print("📊 CODE ANALYSIS SUMMARY");
        print("="*60);
        print(f"Files analyzed:      {stats.get('total_files', 0)}");
        print(f"Classes found:       {stats.get('total_classes', 0)}");
        print(f"Functions found:     {stats.get('total_functions', 0)}");
        print(f"Function calls:      {stats.get('total_calls', 0)}");
        print(f"📈 Visualizations:");
        print(f"  Dependency tree:   {graphs.get('dependency_tree', 'N/A')}");
        print(f"  Class hierarchy:   {graphs.get('class_hierarchy', 'N/A')}");
        print("="*60);
    }

    # ------------------------------------------------
    # Main execution entry point (called by Supervisor)
    # ------------------------------------------------
    can execute_analysis with supervisor entry {
        # Log that analyzer is running
        visitor.session.add_agent_execution("CODE_ANALYZER");

        # Get repository path from session
        repo_path = visitor.session.current_state.get("repo_path", "");
        if not repo_path {
            print("❌ No repository path found. Skipping analysis.");
            visit [<--](`?CodeGenius);
            return;
        }

        # Check for cached results
        cache_file = "outputs/analyzer_output.json";
        
        if os.path.exists(cache_file) {
            print(f"♻️ Reusing cached analysis from {cache_file}");
            
            with open(cache_file, "r") as f {
                cached_data = json.load(f);
            }
            
            # Update session state
            visitor.session.current_state["analysis_data"] = cached_data;
            visitor.session.current_state["analysis_done"] = True;
            visitor.session.current_state["stage"] = WorkflowStage.DOCS;
            
            # Print summary
            self.print_summary(cached_data);
            
            visit [<--](`?CodeGenius);
            return;
        }

        # Run fresh analysis
        print(f"🔍 Starting code analysis for {repo_path}...");
        print("   This may take a moment for large repositories...");
        
        analysis_data = self.run_code_analysis(repo_path);

        # Check for errors
        if "error" in analysis_data {
            print(f"❌ Analysis failed: {analysis_data['error']}");
            visitor.session.current_state["analysis_done"] = False;
            visit [<--](`?CodeGenius);
            return;
        }

        # Save to cache
        with open(cache_file, "w") as f {
            json.dump(analysis_data, f, indent=2);
        }

        print("✅ Analysis complete!\n");

        # Update session state
        visitor.session.current_state["analysis_data"] = analysis_data;
        visitor.session.current_state["analysis_done"] = True;
        visitor.session.current_state["stage"] = WorkflowStage.DOCS;

        # Print summary
        self.print_summary(analysis_data);

        # Pass control to next agent
        visit [<--](`?CodeGenius);
    }
}





node DocGenie(Agent) {
    has agent_type: AgentTypes = AgentTypes.DOC_GENIE;

    # --------------------------------------------------------------
    # LLM: Generate overview
    # --------------------------------------------------------------
    def write_overview(readme_summary: str) -> str by llm(method="Reason");

    # --------------------------------------------------------------
    # Main: Generate markdown (all in Python to avoid Jac issues)
    # --------------------------------------------------------------
    def generate_markdown(repo_name: str, analysis_data: dict, readme_summary: str) -> str {
        
        ::py::
        # Extract data
        stats = analysis_data.get("stats", {})
        files = analysis_data.get("files", [])
        call_graph = analysis_data.get("call_graph", {})
        graphs = analysis_data.get("graphs", {})
        
        # Build markdown document
        md = f"# {repo_name} - Documentation\n\n"
        md += "*Auto-generated by Codebase Genius*\n\n"
        md += "---\n\n"
        
        # Section 1: Overview (use LLM later)
        md += "## Project Overview\n\n"
        md += f"{readme_summary}\n\n"
        
        # Section 2: Statistics
        md += "## Codebase Statistics\n\n"
        md += f"- **Files Analyzed**: {stats.get('total_files', 0)}\n"
        md += f"- **Classes**: {stats.get('total_classes', 0)}\n"
        md += f"- **Functions**: {stats.get('total_functions', 0)}\n"
        md += f"- **Function Calls**: {stats.get('total_calls', 0)}\n\n"
        
        # Section 3: File Structure (simple list)
        md += "## Repository Structure\n\n"
        for file_info in files:
            fname = file_info.get("file", "unknown")
            classes = file_info.get("classes", [])
            funcs = file_info.get("functions", [])
            md += f"### {fname}\n\n"
            
            if classes:
                md += "**Classes:**\n"
                for cls in classes:
                    name = cls.get("name", "?")
                    line = cls.get("line", "?")
                    md += f"- `{name}` (line {line})\n"
                md += "\n"
            
            if funcs:
                md += "**Functions:**\n"
                for func in funcs[:10]:  # Limit to 10 per file
                    name = func.get("name", "?")
                    line = func.get("line", "?")
                    md += f"- `{name}()` (line {line})\n"
                if len(funcs) > 10:
                    md += f"- ... and {len(funcs) - 10} more\n"
                md += "\n"
        
        # Section 4: Visualizations
        md += "## Code Dependency Visualizations\n\n"
        
        dep_tree = graphs.get("dependency_tree", "")
        if dep_tree and os.path.exists(dep_tree):
            md += "### Dependency Tree\n\n"
            md += "Shows the hierarchical structure and call relationships.\n\n"
            md += f"![Dependency Tree]({dep_tree})\n\n"
        
        class_hier = graphs.get("class_hierarchy", "")
        if class_hier and os.path.exists(class_hier):
            md += "### Class Hierarchy\n\n"
            md += "Shows inheritance relationships.\n\n"
            md += f"![Class Hierarchy]({class_hier})\n\n"
        
        # Section 5: Key Functions (most called)
        if call_graph:
            md += "## Key Functions\n\n"
            
            # Find most called functions
            call_counts = {}
            for caller, callees in call_graph.items():
                for callee in callees:
                    call_counts[callee] = call_counts.get(callee, 0) + 1
            
            if call_counts:
                sorted_funcs = sorted(call_counts.items(), key=lambda x: x[1], reverse=True)[:10]
                md += "**Most Called Functions:**\n\n"
                for func_name, count in sorted_funcs:
                    md += f"- `{func_name}()` - called {count} times\n"
                md += "\n"
        
        # Footer
        md += "---\n\n"
        md += "*Generated by Codebase Genius - AI-powered code documentation*\n"
        
        ::py::
        
        return md;
    }

    # --------------------------------------------------------------
    # Entry point
    # --------------------------------------------------------------
    can execute_docgen with supervisor entry {
        visitor.session.add_agent_execution("DOC_GENIE");

        repo_path = visitor.session.current_state.get("repo_path", "");
        repo_name = os.path.basename(repo_path) if repo_path else "Unknown";
        
        readme_summary = visitor.session.current_state.get("readme_summary", "No README available");
        analysis_data = visitor.session.current_state.get("analysis_data", {});

        if not analysis_data or not analysis_data.get("files") {
            print("⚠️ No analysis data found. Cannot generate documentation.");
            visitor.session.current_state["stage"] = WorkflowStage.COMPLETED;
            visit [<--](`?CodeGenius);
            return;
        }

        print(f"📚 Generating documentation for {repo_name}...");

        # Generate markdown
        markdown_content = self.generate_markdown(repo_name, analysis_data, readme_summary);
        
        # Optionally enhance overview with LLM
        print("📝 Enhancing overview with AI insights...");
        enhanced_overview = self.write_overview(str(readme_summary));
        
        ::py::
        # Replace placeholder overview with LLM-generated one
        markdown_content = markdown_content.replace(
            f"{readme_summary}",
            enhanced_overview,
            1  # Only replace first occurrence
        )
        ::py::
        
        # Save to file
        output_dir = f"outputs/{repo_name}";
        os.makedirs(output_dir, exist_ok=True);
        output_path = os.path.join(output_dir, "DOCUMENTATION.md");
        
        with open(output_path, "w", encoding="utf-8") as f {
            f.write(markdown_content);
        }
        
        print(f"✅ Documentation generated successfully!");
        print(f"📄 Saved to: {output_path}");
        print(f"📊 Size: {len(markdown_content)} characters");
        
        visitor.session.current_state["final_doc"] = output_path;
        visitor.session.current_state["docs_done"] = True;
        visitor.session.current_state["stage"] = WorkflowStage.COMPLETED;

        visit [<--](`?CodeGenius);
    }
}



walker supervisor {
    has session: Session | None = None;
    has utterance: str = "";     # GitHub URL, Local path or general command
    has session_id: str = "";
    has max_iterations: int = 10;

    can route_workflow with CodeGenius entry {
        if self.session.get_execution_count() >= self.max_iterations {
            # Safety: stop runaway loops
            print("Max iterations reached, stopping workflow.");
            self.session.current_state["done"] = True;
            disengage;
            return;
        }

        # Fetch current workflow stage and determine next agent
        current_stage = self.session.current_state.get("stage", WorkflowStage.INIT);
        next_agent = here.call_next_agent(self.session.current_state);

        print(f"Current stage: {current_stage}, Next agent: {next_agent}");

        if next_agent == AgentTypes.END or self.session.current_state.get("stage") == WorkflowStage.COMPLETED {
            self.session.current_state["done"] = True;
            print("Workflow completed successfully!");
            disengage;
        } else {
            # Route dynamically to the next agent node
            visit [-->](`?Agent)(?agent_type == next_agent);
        }
    }

    can init_graph with `root entry {
        memory_list = [root --> (`?Memory)];
        if not memory_list {
            memory_list = root ++> Memory();
        }
        memory = memory_list[0];

        if not self.session_id {
            session_list = memory ++> Session();
            self.session = session_list[0];
        } else {
            self.session = &(self.session_id);
        }

        self.session.current_state["stage"] = WorkflowStage.INIT;
        self.session.current_state["utterance"] = self.utterance;

        print(f"Starting workflow for repository: {self.utterance}");

        visit [-->](`?CodeGenius) else {
            router_node = here ++> CodeGenius();
            router_node ++> RepoHandler();
            router_node ++> RepoMapper();
            router_node ++> CodeAnalyzer();
            router_node ++> DocGenie();
            visit router_node;
        }
    }
}

with entry {
    utterance = "/home/christopher/code/codebase_genius";
    supervisor(utterance=utterance) spawn root;
    #print("🚀 Codebase Genius backend ready!");
    #print("📡 Waiting for incoming walker requests...");
}
