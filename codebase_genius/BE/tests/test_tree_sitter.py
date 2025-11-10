from tree_sitter import Parser, Language
import tree_sitter_python as tspython

# Initialize language + parser
PY_LANGUAGE = Language(tspython.language())
parser = Parser(PY_LANGUAGE)

# Parse a sample Python code
code = b"def foo():\n    print('Hello')"
tree = parser.parse(code)
root = tree.root_node
print("✅ Tree built successfully!")

# Option 1 (newer API)
try:
    print(root.to_sexp())
except AttributeError:
    # Option 2 (fallback pretty printer)
    def walk(node, indent=0):
        print("  " * indent + f"({node.type})")
        for child in node.children:
            walk(child, indent + 1)
    walk(root)


