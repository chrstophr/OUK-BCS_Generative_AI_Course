import os;
import git;
import tempfile;
import json;
import time;
import from typing { List }
import from agent_core { Memory, Session, agent, get_all_sessions }
import from byllm.llm { Model }
#import from nodes.repo_handler { RepoHandler }
import sys;
import from graphviz { Digraph }
import from tree_sitter { Language, Parser }
include analyzer_utils;


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

    def validate_and_clone_repo(repo_url: str) -> str {
       # temp_dir = tempfile.mkdtemp(prefix="repo_clone_");

        ::py::
        import git, tempfile, os

        repo_name = os.path.basename(repo_url.rstrip("/")).replace(".git", "")
        base_dir = os.path.join(os.getcwd(), "outputs", "repos")
        os.makedirs(base_dir, exist_ok=True)
        target_dir = os.path.join(base_dir, repo_name)

        #  Reuse existing repo if already cloned
        if os.path.exists(target_dir) and os.path.isdir(os.path.join(target_dir, ".git")):
            print(f"♻️ Reusing existing repository at {target_dir}")
            return target_dir

        try:
            #temp_dir = tempfile.mkdtemp(prefix="repo_clone_")
            print(f"🚀 Cloning repository from {repo_url}...")
            git.Repo.clone_from(repo_url, target_dir)
            print(f"✅ Repository cloned successfully at {target_dir}")
            return target_dir
        except git.GitCommandError as e:
            print(f"❌ Error cloning repository: {e}")
            return ""
        ::py::
    }

    can execute_clone with supervisor entry {
        visitor.session.add_agent_execution("REPO_HANDLER");
        repo_url = visitor.utterance;

        clone_path = self.validate_and_clone_repo(repo_url);
        if clone_path != "" {
            visitor.session.current_state["repo_cloned"] = True;
            visitor.session.current_state["repo_path"] = clone_path;
            visitor.session.current_state["stage"] = WorkflowStage.MAPPING;
            print(f"Cloned successfully: {clone_path}");
        } else {
            visitor.session.current_state["repo_cloned"] = False;
            print("❌Cloning failed. Check the repository URL or network connection.");
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
            entries = os.listdir(path);
            entries.sort();

            for (index, entry) in enumerate(entries) {
                full_path = os.path.join(path, entry);

                # Skip irrelevant folders & hidden files
                if entry.startswith(".") or entry in [
                    "__pycache__",
                    "venv",
                    "node_modules",
                    "dist",
                    "build",
                    ".idea",
                    ".vscode"
                ]{
                    continue;
                }

                connector = "└── " if index == len(entries) - 1 else "├── ";
                output += prefix + connector + entry + "\n";

                # If folder, recursively go deeper
                if os.path.isdir(full_path) {
                    extension = "    " if index == len(entries) - 1 else "│   ";
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
            with open(cached_output, "r") as f {
                cached = json.load(f);
        }
        visitor.session.current_state["repo_structure"] = cached.get("repo_structure", "");
        visitor.session.current_state["readme_summary"] = cached.get("readme_summary", "");
        visitor.session.current_state["mapping_done"] = True;
        visitor.session.current_state["stage"] = WorkflowStage.ANALYSIS;
        visit [<--](`?CodeGenius);
        return;
        }

        # Step 1: Build file/folder tree
        repo_structure = self.generate_repo_structure(repo_path);

        # Step 2: Find README or similar entry doc
        readme_summary = "";
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

            f = open(readme_file, "r", encoding="utf-8");
            readme_content = f.read();
            f.close();

            # Summarize the file using byllm
            readme_summary = self.summarize_readme(readme_content);
        } else {
            print("⚠️ No README.md or entry document found in repository.");
        }

        # Step 3: Save mapping data to session
        visitor.session.current_state["repo_structure"] = repo_structure;
        visitor.session.current_state["readme_summary"] = readme_summary;
        visitor.session.current_state["mapping_done"] = True;
        visitor.session.current_state["stage"] = WorkflowStage.ANALYSIS;


        # Step 4: Preview outputs before passing to Supervisor
        print("========== 🧭 REPO MAPPER OUTPUT PREVIEW ==========");
        print("📁 REPO STRUCTURE:");
        print(repo_structure);
        print("\n📝 README SUMMARY:");
        print(readme_summary);
        print("===================================================");

        # save outputs to JSON file
        output_path = os.path.join("outputs", "repo_mapper_output.json");
        with open(output_path, "w", encoding="utf-8") as f{
            json.dump({
                "repo_path": repo_path,
                "repo_structure": visitor.session.current_state.get("repo_structure", ""),
                "readme_summary": visitor.session.current_state.get("readme_summary", "")
            }, f, ensure_ascii=False, indent=2);
        }
        print(f"📁 RepoMapper output saved to {output_path}");


        print("✅ Repo mapping complete. Passing results to Supervisor.");
        visit [<--](`?CodeGenius);
    }
}


node CodeAnalyzer(Agent) {
    has agent_type: AgentTypes = AgentTypes.CODE_ANALYZER;



    # ----------------------------------------
    # Convert Jac file to Python
    # ----------------------------------------
    def convert_jac_to_python(file_path: str) -> str {
        temp_path = file_path.replace(".jac", "_converted.py");
        cmd = f"jac jac2py {file_path} > {temp_path}";
        os.system(cmd);
        return temp_path;
    }

    # ----------------------------------------
    # Initialize Tree-sitter parser (Python grammar)
    # ----------------------------------------
    def init_parser() -> Parser {
        lang_path = "outputs/tree_sitter_languages.so";
        if not os.path.exists(lang_path) {
            os.system("tree-sitter build-wasm");
        }
        Language.build_library(lang_path, ["vendor/tree-sitter-python"]);
        parser = Parser();
        parser.set_language(Language(lang_path, "python"));
        return parser;
    }

    # ----------------------------------------
    # Extract function and class definitions
    # ----------------------------------------
    def parse_source(parser: Parser, file_path: str) -> list {
        with open(file_path, "r") as f {
            code = f.read();
        }
        tree = parser.parse(bytes(code, "utf8"));
        root = tree.root_node;

        results = [];
        for node in root.children {
            if node.type == "function_definition" or node.type == "class_definition" {
                results.append({
                    "type": node.type,
                    "name": code[node.start_point[1]:node.end_point[1]],
                    "start_line": node.start_point[0],
                    "end_line": node.end_point[0]
                });
            }
        }
        return results;
    }

    # ----------------------------------------
    # Summarize docstring content using byllm
    # ----------------------------------------
    def summarize_docstring(docstring: str) -> str by llm(method="Reason");

    # ----------------------------------------
    # Build visual call graph and save PNG
    # ----------------------------------------
    def build_graphviz(items: list, output_path: str) {
        dot = Digraph(comment="Code Context Graph");
        for item in items {
            dot.node(item["name"], f"{item['name']}\\n({item['type']})");
        }

        for (i, src) in enumerate(items) {
            if i + 1 < len(items) {
                dot.edge(src["name"], items[i + 1]["name"]);
            }
        }

        os.makedirs(os.path.dirname(output_path), exist_ok=True);
        dot.render(output_path, format="png", cleanup=True);
    }

    # ----------------------------------------
    # Run analyzer
    # ----------------------------------------
    can execute_analysis with supervisor entry {
        visitor.session.add_agent_execution("CODE_ANALYZER");

        repo_path = visitor.session.current_state.get("repo_path", "");
        if not repo_path {
            print("❌ No repo path found. Skipping analysis.");
            visit [<--](`?CodeGenius);
            return;
        }
        
        #cache path
        output_json = f"outputs/analyzer_output.json";
        graph_path = f"outputs/graphs/code_graph";

        # 🧩 Load existing analysis if already done
        if os.path.exists(output_json) {
            print(f"♻️ Reusing existing analysis output from {output_json}");
            with open(output_json, "r") as f {
                cached_data = json.load(f);
            }
            visitor.session.current_state["analysis_data"] = cached_data;
            visitor.session.current_state["analysis_done"] = True;
            visitor.session.current_state["stage"] = WorkflowStage.DOCS;
            visit [<--](`?CodeGenius);
            return;
        }

        print(f"🔍 Starting code analysis for {repo_path}...");
        parser = self.init_parser();

        all_items = [];
        for entry in os.walk(repo_path) {
            root = entry[0];
            files = entry[2];
            for f in files {
                if f.endswith(".py") or f.endswith(".jac") {
                    path = os.path.join(root, f);
                    if f.endswith(".jac") {
                        print(f"🌀 Converting {f} to Python...");
                        path = self.convert_jac_to_python(path);
                    }
                    items = self.parse_source(parser, path);
                    all_items = all_items + items;
                }
            }
        }

        # 🧠 Generate graph and doc summaries
        self.build_graphviz(all_items, graph_path);

        analysis_data = {
            "repo_path": repo_path,
            "functions_classes": all_items,
            "graph_image": graph_path + ".png"
        };

        with open(output_json, "w") as f {
            json.dump(analysis_data, f, indent=2);
        }

        print("✅ Code analysis complete. Graph saved at outputs/graphs/code_graph.png");

        visitor.session.current_state["analysis_data"] = analysis_data;
        visitor.session.current_state["analysis_done"] = True;
        visitor.session.current_state["stage"] = WorkflowStage.DOCS;

        visit [<--](`?CodeGenius);
    }
}



walker supervisor {
    has session: Session | None = None;
    has utterance: str = "";     # GitHub URL or general command
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
           # router_node ++> DocGenie(); 
            visit router_node;
        }
    }
}

with entry {
    utterance = "https://github.com/chrstophr/Rock-Paper-Scissors";
    supervisor(utterance=utterance) spawn root;
}
