import os
import json
from graphviz import Digraph
from tree_sitter import Parser, Language
import tree_sitter_python as tspython

# Initialize Python grammar for Tree-sitter
PY_LANGUAGE = tspython.language()

def init_parser():
    #Initialize a Tree-sitter parser for Python (modern py-tree-sitter).
    try:
        PY_LANGUAGE = Language(tspython.language())  # ✅ convert capsule to Language
        parser = Parser(PY_LANGUAGE)
        return parser
    except Exception as e:
        print(f"❌ Failed to initialize Tree-sitter parser: {e}")
        return None
    
def convert_jac_to_python(file_path: str) -> str:
    #Convert a Jac file to Python using jac2py CLI.
    temp_path = file_path.replace(".jac", "_converted.py")
    os.system(f"jac jac2py {file_path} > {temp_path}")
    return temp_path

def walk_tree(node, code, results):
    #Recursively walk syntax tree to collect relevant nodes.
    if node.type in ("function_definition", "class_definition", "call", "expression_statement"):
        snippet = code[node.start_byte:node.end_byte].decode("utf8").strip()
        results.append({
            "type": node.type,
            "snippet": snippet[:120] + ("..." if len(snippet) > 120 else ""),
            "start_line": node.start_point[0],
            "end_line": node.end_point[0],
        })
    for i in range(node.child_count):
        walk_tree(node.child(i), code, results)

def parse_source(parser, file_path: str):
    #Parse a source file and extract definitions and calls.
    with open(file_path, "rb") as f:
        code = f.read()
    tree = parser.parse(code)
    root = tree.root_node
    results = []
    walk_tree(root, code, results)
    return results

def build_graphviz(items: list, output_path: str):
    #Generate visual Code Context Graph.
    dot = Digraph(comment="Code Context Graph")
    for i, item in enumerate(items):
        label = f"{item['type']}\\nLines {item['start_line']}-{item['end_line']}"
        dot.node(str(i), label)
        if i > 0:
            dot.edge(str(i - 1), str(i))
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    dot.render(output_path, format="png", cleanup=True)

def run_analysis(repo_path: str, cache_path="outputs/analyzer_output.json"):
    #Main callable used by Jac.
    if os.path.exists(cache_path):
        print(f"♻️ Reusing existing analysis output from {cache_path}")
        with open(cache_path, "r") as f:
            return json.load(f)

    print(f"🔍 Starting code analysis for {repo_path}...")
    parser = init_parser()
    if not parser:
        print("⚠️ Parser not available. Skipping analysis.")
        return {"repo_path": repo_path, "functions_classes": [], "graph_image": ""}

    all_items = []
    for root, _, files in os.walk(repo_path):
        for f in files:
            if f.endswith(".py") or f.endswith(".jac"):
                path = os.path.join(root, f)
                if f.endswith(".jac"):
                    print(f"🌀 Converting {f} to Python...")
                    path = convert_jac_to_python(path)
                try:
                    items = parse_source(parser, path)
                    if items:
                        print(f"📄 Parsed {f}: {len(items)} items found.")
                    all_items += items
                except Exception as e:
                    print(f"⚠️ Failed to parse {f}: {e}")

    graph_path = "outputs/graphs/code_graph"
    build_graphviz(all_items, graph_path)

    analysis_data = {
        "repo_path": repo_path,
        "functions_classes": all_items,
        "graph_image": graph_path + ".png"
    }

    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(analysis_data, f, indent=2)

    print(f"✅ Code analysis complete. Graph saved at {graph_path}.png")
    return analysis_data
