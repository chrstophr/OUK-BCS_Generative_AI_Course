"""
Code Analysis Utilities
=========================
Focuses on building hierarchical dependency trees and relationship graphs
Features:
1. Identify functions, classes, and their dependencies
2. Build hierarchical relationship trees
3. Generate visualizations
"""

import os
import json
from typing import Dict, List, Optional, Set
from collections import defaultdict
from graphviz import Digraph
from tree_sitter import Parser, Language, Node
import tree_sitter_python as tspython


BUILTIN_FUNCTIONS = {
    'print', 'len', 'str', 'int', 'float', 'bool', 'dict', 'list', 'set', 'tuple', 'open', 'range', 'enumerate', 'zip', 'map', 'filter', 'sum',
    'max', 'min', 'abs', 'isinstance', 'hasattr', 'getattr', 'setattr','type', 'id', 'iter', 'next', 'sorted', 'reversed', 'any', 'all',
    'get', 'items', 'keys', 'values', 'append', 'extend', 'pop', 'remove','join', 'split', 'strip', 'replace', 'format', 'startswith', 'endswith',
    'exists', 'isdir', 'isfile', 'makedirs', 'listdir', 'walk','load', 'dump', 'loads', 'dumps', 'read', 'write', 'readline'
}

# Jac-specific keywords to exclude
JAC_KEYWORDS = {
    'visit', 'spawn', 'disengage', 'report', 'here', 'root', 'edge_in','edge_out', 'refs', 'filter_on', 'OPath', 'jid'
}


# ================================================================
# PARSER INITIALIZATION
# ================================================================

def init_parser() -> Optional[Parser]:
    """Initialize Tree-sitter parser for Python."""
    try:
        PY_LANGUAGE = Language(tspython.language())
        parser = Parser(PY_LANGUAGE)
        return parser
    except Exception as e:
        print(f"❌ Failed to initialize parser: {e}")
        return None


# ================================================================
# JAC CONVERSION
# ================================================================

def convert_jac_to_python(file_path: str) -> Optional[str]:
    """Convert Jac file to Python."""
    import tempfile

   # Create temp directory if it doesn't exist
    temp_dir = os.path.join(tempfile.gettempdir(), "codebase_genius_temp")
    os.makedirs(temp_dir, exist_ok=True)
    
    # Generate temp filename
    filename = os.path.basename(file_path).replace(".jac", "_converted.py")
    temp_path = os.path.join(temp_dir, filename)
    
    try:
        result = os.system(f"jac jac2py {file_path} > {temp_path} 2>/dev/null")
        
        if result == 0 and os.path.exists(temp_path) and os.path.getsize(temp_path) > 0:
            return temp_path
        else:
            return None
    except Exception as e:
        print(f"❌ Conversion error for {file_path}: {e}")
        return None


# ================================================================
# ENTITY EXTRACTION 
# ================================================================

def extract_entities_minimal(tree, source_code: bytes, file_path: str, original_path: str = None) -> Dict:
    """
    Extract only essential information about functions and classes.
    Returns compact structure focused on relationships.
    """
    functions = []
    classes = []
    
    def get_name(node: Node) -> str:
        name_node = node.child_by_field_name('name')
        return name_node.text.decode('utf8') if name_node else "unknown"
    
    def visit_node(node: Node, parent_class: str = None):
        if node.type == 'function_definition':
            func_name = get_name(node)
            functions.append({
                "name": func_name,
                "parent": parent_class,
                "line": node.start_point[0] + 1
            })
            return  # Don't recurse
        
        elif node.type == 'class_definition':
            class_name = get_name(node)
            
            # Extract base classes
            bases = []
            superclasses = node.child_by_field_name('superclasses')
            if superclasses:
                for child in superclasses.children:
                    if child.type == 'identifier':
                        bases.append(child.text.decode('utf8'))
            
            classes.append({
                "name": class_name,
                "bases": bases,
                "line": node.start_point[0] + 1
            })
            
            # Visit methods
            for child in node.children:
                visit_node(child, class_name)
            return
        
        # Recurse
        for child in node.children:
            visit_node(child, parent_class)
    
    visit_node(tree.root_node)
    
    # Use original path if provided (for .jac files), otherwise use actual path
    display_path = original_path if original_path else file_path
    
    return {
        "file": os.path.basename(display_path),  # Use original filename
        "functions": functions,
        "classes": classes
    }


# ================================================================
# RELATIONSHIP EXTRACTION
# ================================================================

def extract_call_relationships(tree, source_code: bytes) -> Dict[str, List[str]]:
    """ Extract function call relationships."""
    calls = defaultdict(list)
    
    def visit_node(node: Node, current_func: str = None):
        if node.type == 'function_definition':
            name_node = node.child_by_field_name('name')
            func_name = name_node.text.decode('utf8') if name_node else None
            
            if func_name:
                calls[func_name]  # Initialize
                for child in node.children:
                    visit_node(child, func_name)
            return
        
        elif node.type == 'call' and current_func:
            func_node = node.child_by_field_name('function')
            if func_node:
                called = None
                if func_node.type == 'identifier':
                    called = func_node.text.decode('utf8')
                elif func_node.type == 'attribute':
                    attr = func_node.child_by_field_name('attribute')
                    if attr:
                        called = attr.text.decode('utf8')
                        
                # ✅ Filter out built-ins and Jac keywords
                if called and called not in BUILTIN_FUNCTIONS and called not in JAC_KEYWORDS:
                    if called not in calls[current_func]:
                        calls[current_func].append(called)
        
        for child in node.children:
            visit_node(child, current_func)
    
    visit_node(tree.root_node)
    return dict(calls)


# ================================================================
# HIERARCHICAL TREE VISUALIZATION
# ================================================================

def build_dependency_tree(file_data: List[Dict], call_graph: Dict, output_path: str):
    """
    Builds a hierarchical dependency tree showing:
    - Classes within files
    - Functions/methods within classes
    - Call relationships between functions
    """
    dot = Digraph(comment="Code Dependency Tree", format='png')
    dot.attr(rankdir='TB', size='14,10', dpi='250')
    dot.attr('node', fontname='Arial', fontsize='10')
    
    # Track all nodes for relationship drawing
    all_functions = {}
    
    # Create file clusters
    for file_info in file_data:
        filename = file_info["file"]
        
        with dot.subgraph(name=f'cluster_{filename}') as cluster:
            cluster.attr(label=filename, style='rounded', color='blue')
            
            # Add classes
            for cls in file_info.get("classes", []):
                class_node = f"{filename}_{cls['name']}"
                cluster.node(class_node, cls['name'], 
                           shape='box', style='filled', fillcolor='lightblue')
                
                # Add methods under class
                for func in file_info.get("functions", []):
                    if func.get("parent") == cls['name']:
                        func_node = f"{filename}_{func['name']}"
                        cluster.node(func_node, func['name'], 
                                   shape='ellipse', style='filled', fillcolor='lightgreen')
                        cluster.edge(class_node, func_node, style='dotted')
                        all_functions[func['name']] = func_node
            
            # Add standalone functions
            for func in file_info.get("functions", []):
                if not func.get("parent"):
                    func_node = f"{filename}_{func['name']}"
                    cluster.node(func_node, func['name'], 
                               shape='ellipse', style='filled', fillcolor='lightyellow')
                    all_functions[func['name']] = func_node
    
    # Add call relationships (only between defined functions)
    for caller, callees in call_graph.items():
        if caller in all_functions:
            for callee in callees:
                if callee in all_functions:
                    dot.edge(all_functions[caller], all_functions[callee], 
                           color='gray', arrowsize='0.7')
    
    # Render
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    try:
        dot.render(output_path, cleanup=True)
        print(f"✅ Dependency tree rendered: {output_path}.png")
    except Exception as e:
        print(f"❌ Failed to render graph: {e}")


def build_class_hierarchy(file_data: List[Dict], output_path: str):

    dot = Digraph(comment="Class Hierarchy", format='png')
    dot.attr(rankdir='BT', size='10,8', dpi='250')
    dot.attr('node', shape='box', style='rounded,filled', 
             fillcolor='lightblue', fontname='Arial')
    
    # Collect all classes
    all_classes = {}
    for file_info in file_data:
        for cls in file_info.get("classes", []):
            all_classes[cls['name']] = cls
    
    # Add nodes
    for cls_name in all_classes:
        dot.node(cls_name, cls_name)
    
    # Add inheritance edges
    for cls_name, cls_info in all_classes.items():
        for base in cls_info.get("bases", []):
            if base in all_classes:
                dot.edge(cls_name, base, label="inherits", color="red")
    
    # Render
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    try:
        dot.render(output_path, cleanup=True)
        print(f"✅ Class hierarchy rendered: {output_path}.png")
    except Exception as e:
        print(f"❌ Failed to render graph: {e}")


# ================================================================
# MAIN ANALYSIS
# ================================================================

def run_analysis(repo_path: str, cache_path: str = "outputs/analyzer_output.json") -> Dict:
    """
    Main analysis entry point.
    """
    
    # Check cache
    if os.path.exists(cache_path):
        print(f"♻️ Reusing cached analysis from {cache_path}")
        with open(cache_path, "r") as f:
            return json.load(f)
    
    print(f"🔍 Analyzing repository: {repo_path}")
    
    parser = init_parser()
    if not parser:
        return {"error": "Parser initialization failed"}
    
    file_data = []
    all_calls = {}
    
    # Parse files
    for root, _, files in os.walk(repo_path):
        if any(skip in root for skip in ['.git', '__pycache__', 'venv', 'node_modules']):
            continue
        
        for filename in files:
            if not (filename.endswith('.py') or filename.endswith('.jac')):
                continue
            
            # Skip converted files to avoid duplicates
            if '_converted.py' in filename:
                continue
            
            file_path = os.path.join(root, filename)
            original_path = file_path  # Store original path
            
            # Convert Jac if needed
            if filename.endswith('.jac'):
                converted = convert_jac_to_python(file_path)
                if not converted:
                    continue
                file_path = converted # Use converted for parsing
            
            try:
                with open(file_path, 'rb') as f:
                    source_code = f.read()
                
                tree = parser.parse(source_code)
                
                # ✅ Pass both paths - parse converted, store original name
                entities = extract_entities_minimal(tree, source_code, file_path, original_path)
                if entities["functions"] or entities["classes"]:
                    file_data.append(entities)
                
                # Extract call graph
                calls = extract_call_relationships(tree, source_code)
                all_calls.update(calls)
                
                func_count = len(entities["functions"])
                class_count = len(entities["classes"])
                print(f"  📄 {filename}: {class_count} classes, {func_count} functions")
                
            except Exception as e:
                print(f"  ⚠️ Error parsing {filename}: {e}")
    
    # Generate visualizations
    print("\n🎨 Generating dependency visualizations...")
    
    dep_tree_path = "outputs/graphs/dependency_tree"
    build_dependency_tree(file_data, all_calls, dep_tree_path)
    
    class_hier_path = "outputs/graphs/class_hierarchy"
    build_class_hierarchy(file_data, class_hier_path)
    
    # Calculate statistics
    total_functions = sum(len(f["functions"]) for f in file_data)
    total_classes = sum(len(f["classes"]) for f in file_data)
    total_calls = sum(len(calls) for calls in all_calls.values())
    
    # Build output
    result = {
        "repo_path": repo_path,
        "files": file_data,
        "call_graph": all_calls,
        "graphs": {
            "dependency_tree": dep_tree_path + ".png",
            "class_hierarchy": class_hier_path + ".png"
        },
        "stats": {
            "total_files": len(file_data),
            "total_classes": total_classes,
            "total_functions": total_functions,
            "total_calls": total_calls
        }
    }
    
    # Save cache
    os.makedirs(os.path.dirname(cache_path) or ".", exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    
    print(f"\n✅ Analysis complete!")
    print(f"   📊 {total_classes} classes, {total_functions} functions")
    print(f"   📞 {total_calls} function calls tracked")
    print(f"   📁 Output saved to {cache_path}")
    
    return result


# ================================================================
# QUERY HELPERS 
# ================================================================

def get_callers(function_name: str, call_graph: Dict) -> List[str]:
    """Find all functions that call the given function."""
    return [caller for caller, callees in call_graph.items() 
            if function_name in callees]


def get_callees(function_name: str, call_graph: Dict) -> List[str]:
    """Find all functions called by the given function."""
    return call_graph.get(function_name, [])


def get_file_entities(filename: str, file_data: List[Dict]) -> Dict:
    """Get all entities from a specific file."""
    for file_info in file_data:
        if filename in file_info["file"]:
            return file_info
    return {"functions": [], "classes": []}



if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python analyzer_utils.py <repo_path>")
        sys.exit(1)
    
    result = run_analysis(sys.argv[1])
    print("\n" + "="*60)
    print("STATS:")
    print("="*60)
    print(json.dumps(result["stats"], indent=2))
