import os
import json
from graphviz import Digraph
from tree_sitter import Parser, Language
import tree_sitter_python as tspython

# Initialize Python grammar for Tree-sitter
PY_LANGUAGE = tspython.language()

# ---------------------------------------------------------------
# Initialize parser
# ---------------------------------------------------------------

def init_parser():
    #Initialize a Tree-sitter parser for Python (modern py-tree-sitter).
    try:
        PY_LANGUAGE = Language(tspython.language())  # ✅ convert capsule to Language
        parser = Parser(PY_LANGUAGE)
        return parser
    except Exception as e:
        print(f"❌ Failed to initialize Tree-sitter parser: {e}")
        return None
    
    
# ---------------------------------------------------------------
# Convert Jac → Python for mixed repos
# ---------------------------------------------------------------
    
def convert_jac_to_python(file_path: str) -> str:
    #Convert a Jac file to Python using jac2py CLI.
    temp_path = file_path.replace(".jac", "_converted.py")
    os.system(f"jac jac2py {file_path} > {temp_path}")
    return temp_path

# ---------------------------------------------------------------
# Deep traversal helpers
# ---------------------------------------------------------------
def walk_tree(node, code: str, results: list):
    """Recursively walk all AST nodes to extract functions, classes, and calls."""
    node_type = node.type

    if node_type in ("function_definition", "class_definition"):
        snippet = code[node.start_byte:node.end_byte][:250].strip()
        results.append({
            "type": node_type,
            "name": extract_name(node, code),
            "snippet": snippet,
            "start_line": node.start_point[0],
            "end_line": node.end_point[0],
        })

    elif node_type == "call":
        snippet = code[node.start_byte:node.end_byte][:120].strip()
        results.append({
            "type": "call",
            "name": extract_name(node, code),
            "snippet": snippet,
            "start_line": node.start_point[0],
            "end_line": node.end_point[0],
        })

    # Recurse into children
    for child in node.children:
        walk_tree(child, code, results)


def extract_name(node, code: str):
    """Extracts function or class name if present."""
    try:
        for child in node.children:
            if child.type == "identifier":
                return code[child.start_byte:child.end_byte]
        return node.type
    except Exception:
        return node.type


def parse_source(parser, file_path: str):

    #Parse a Python (or converted Jac) file using Tree-sitter.
    #Extracts function, class, and calls.

    if not parser:
        print("⚠️ Parser not available. Skipping analysis.")
        return []

    with open(file_path, "r", encoding="utf-8") as f:
        code = f.read()

    tree = parser.parse(bytes(code, "utf8"))
    root = tree.root_node

    results = []
    walk_tree(root, code, results)
    return results

# ---------------------------------------------------------------
# Relationship extraction
# ---------------------------------------------------------------
def extract_relationships(items: list):
    """
    Builds call relationships between defined functions/classes and call sites.
    """
    relationships = {"details": []}
    defined_funcs = {i: x["name"] for i, x in enumerate(items) if x["type"] == "function_definition"}

    for i, item in enumerate(items):
        if item["type"] == "call":
            call_name = item["name"]
            for j, func_name in defined_funcs.items():
                if call_name == func_name:
                    relationships["details"].append({
                        "from": i,
                        "to": j,
                        "label": f"calls {call_name}()"
                    })
    return relationships


# ================================================================
# Graph Generation
# ================================================================

def build_graphviz(items: list, relationships: dict, output_path: str):

    """ Build visual Graphviz PNG showing real relationships."""
    dot = Digraph(comment="Code Context Graph")
    
    # Add nodes
    for idx, item in enumerate(items):
        label = f"{item['type']}\\n{item['name']}"
        dot.node(f"N{idx}", label)

    # Add relationship edges if found
    rels = relationships.get("details", [])
    if rels:
        for rel in rels:
            dot.edge(f"N{rel['from']}", f"N{rel['to']}", label=rel["label"])
    else:
        # fallback to sequential edges
        for i in range(len(items) - 1):
            dot.edge(f"N{i}", f"N{i+1}")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    dot.render(output_path, format="png", cleanup=True)


# ================================================================
# Main Analyzer Entry Point (called from Jac)
# ================================================================

def run_analysis(repo_path: str, cache_path="outputs/analyzer_output.json"):
    """
    Full repo analysis: traverse, parse, extract calls, build graph, save.
    """
    if os.path.exists(cache_path):
        print(f"♻️ Reusing existing analysis output from {cache_path}")
        with open(cache_path, "r") as f:
            return json.load(f)

    print(f"🔍 Deep Tree-sitter analysis for {repo_path}...")
    parser = init_parser()
    all_items = []

    # Traverse all files in repository
    for root, _, files in os.walk(repo_path):
        for f in files:
            if f.endswith((".py", ".jac")):
                path = os.path.join(root, f)
                if f.endswith(".jac"):
                    path = convert_jac_to_python(path)
                items = parse_source(parser, path)
                print(f"📄 Parsed {f}: {len(items)} nodes.")
                all_items += items

    # Extract relationships and visual graph
    relationships = extract_relationships(all_items)
    graph_path = "outputs/graphs/code_graph"
    build_graphviz(all_items, relationships, graph_path)

    # Combine and Save results for Supervisor/DocGenie
    analysis_data = {
        "repo_path": repo_path,
        "functions_classes": all_items,
        "relationships": relationships,
        "graph_image": graph_path + ".png"
    }

    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(analysis_data, f, indent=2)

    print(f"✅ Code analysis complete. Graph saved at {graph_path}.png")
    return analysis_data
