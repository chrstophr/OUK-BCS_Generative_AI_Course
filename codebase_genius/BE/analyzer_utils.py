import os
import json
from graphviz import Digraph
from tree_sitter import Language, Parser

# Ensure grammar compiled once
LANG_SO = "outputs/tree_sitter_languages.so"
PY_LANG_PATH = "vendor/tree-sitter-python"

def ensure_language_built():
    os.makedirs("outputs", exist_ok=True)
    if not os.path.exists(LANG_SO):
        print("🧩 Building Tree-sitter language library...")
        Language.build_library(LANG_SO, [PY_LANG_PATH])

def init_parser():
    ensure_language_built()
    parser = Parser()
    parser.set_language(Language(LANG_SO, "python"))
    return parser

def convert_jac_to_python(file_path: str) -> str:
    """Convert a Jac file to Python using jac2py CLI."""
    temp_path = file_path.replace(".jac", "_converted.py")
    os.system(f"jac jac2py {file_path} > {temp_path}")
    return temp_path

def parse_source(parser, file_path: str):
    """Parse Python file to extract functions/classes."""
    with open(file_path, "r", encoding="utf-8") as f:
        code = f.read()
    tree = parser.parse(bytes(code, "utf8"))
    root = tree.root_node

    results = []
    for node in root.children:
        if node.type in ("function_definition", "class_definition"):
            name_bytes = code[node.start_point[1]:node.end_point[1]]
            results.append({
                "type": node.type,
                "name": name_bytes.strip(),
                "start_line": node.start_point[0],
                "end_line": node.end_point[0],
            })
    return results

def build_graphviz(items: list, output_path: str):
    """Generate visual Code Context Graph."""
    dot = Digraph(comment="Code Context Graph")
    for item in items:
        dot.node(item["name"], f"{item['name']}\\n({item['type']})")
    for i in range(len(items) - 1):
        dot.edge(items[i]["name"], items[i + 1]["name"])
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    dot.render(output_path, format="png", cleanup=True)

def run_analysis(repo_path: str, cache_path="outputs/analyzer_output.json"):
    """Main callable used by Jac."""
    if os.path.exists(cache_path):
        print(f"♻️ Reusing existing analysis output from {cache_path}")
        with open(cache_path, "r") as f:
            return json.load(f)

    print(f"🔍 Starting code analysis for {repo_path}...")
    parser = init_parser()
    all_items = []

    for root, _, files in os.walk(repo_path):
        for f in files:
            if f.endswith(".py") or f.endswith(".jac"):
                path = os.path.join(root, f)
                if f.endswith(".jac"):
                    print(f"🌀 Converting {f} to Python...")
                    path = convert_jac_to_python(path)
                all_items += parse_source(parser, path)

    graph_path = "outputs/graphs/code_graph"
    build_graphviz(all_items, graph_path)

    analysis_data = {
        "repo_path": repo_path,
        "functions_classes": all_items,
        "graph_image": graph_path + ".png"
    }

    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(analysis_data, f, indent=2)

    print(f"✅ Code analysis complete. Graph saved at {graph_path}.png")
    return analysis_data
