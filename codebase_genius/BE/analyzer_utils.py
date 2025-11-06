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


def parse_source(parser, file_path: str):

    #Parse a Python (or converted Jac) file using Tree-sitter.
    #Extracts function, class, and basic call nodes

    if not parser:
        print("⚠️ Parser not available. Skipping analysis.")
        return []

    with open(file_path, "r", encoding="utf-8") as f:
        code = f.read()

    tree = parser.parse(bytes(code, "utf8"))
    root = tree.root_node

    results = []
    for node in root.children:
        # Capture function and class definitions, plus expression statements (simple MVP coverage)
        if node.type in ("function_definition", "class_definition", "expression_statement", "call"):
            snippet = code[node.start_byte:node.end_byte][:200].strip()  # capture short snippet
            results.append({
                "type": node.type,
                "snippet": snippet,
                "start_line": node.start_point[0],
                "end_line": node.end_point[0],
                "file": file_path
            })

    return results

# ---------------------------------------------------------------
# Relationship extraction
# ---------------------------------------------------------------
def extract_relationships(items: list):
    """
    Derive simple function-call relationships based on text pattern matching.
    Output: {"details": [{"from": idxA, "to": idxB, "label": "calls"}]}
    """
    relationships = {"details": []}
    func_names = [item["snippet"].split("(")[0].replace("def ", "").strip() 
                  for item in items if item["type"] == "function_definition"]

    for i, item in enumerate(items):
        snippet = item["snippet"]
        for j, func in enumerate(func_names):
            if func and func in snippet and i != j:
                relationships["details"].append({
                    "from": i,
                    "to": j,
                    "label": f"calls {func}()"
                })
    return relationships


# ================================================================
# Graph Generation
# ================================================================

def build_graphviz(items: list, relationships: dict, output_path: str):

    """
    Build a simple visual Code Context Graph (CCG) as a PNG.
    Each node = function/class/expression found in the source files.
    """
    dot = Digraph(comment="Code Context Graph")
    
    # Add nodes
    for idx, item in enumerate(items):
        label = f"{item['type']}\n{item['snippet'][:40]}"
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
"""  # Add nodes for all parsed elements
    for item in items:
        dot.node(item["snippet"][:30], f"{item['type']}")

    # Add linear edges (MVP; relationships can be added in later phases)
    for i in range(len(items) - 1):
        dot.edge(items[i]["snippet"][:30], items[i + 1]["snippet"][:30])

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    dot.render(output_path, format="png", cleanup=True) """

# ================================================================
# Main Analyzer Entry Point (called from Jac)
# ================================================================

def run_analysis(repo_path: str, cache_path="outputs/analyzer_output.json"):
    """
    Main callable from Jac.
    1. Initializes Tree-sitter parser.
    2. Parses all .py and .jac files.
    3. Generates a simple call graph.
    4. Caches and returns structured output.
    """
    if os.path.exists(cache_path):
        print(f"♻️ Reusing existing analysis output from {cache_path}")
        with open(cache_path, "r") as f:
            return json.load(f)

    print(f"🔍 Starting code analysis for {repo_path}...")
    parser = init_parser()
    all_items = []

    # Traverse all files in repository
    for root, _, files in os.walk(repo_path):
        for f in files:
            if f.endswith(".py") or f.endswith(".jac"):
                path = os.path.join(root, f)
                if f.endswith(".jac"):
                    print(f"🌀 Converting {f} to Python...")
                    path = convert_jac_to_python(path)

                items = parse_source(parser, path)
                print(f"📄 Parsed {f}: {len(items)} items found.")
                all_items += items

    # Build relationships and visual graph
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
