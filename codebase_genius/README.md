# Codebase Genius

**AI-Powered Multi-Agent Code Documentation System**

Codebase Genius is an intelligent documentation generator that automatically analyzes software repositories and produces comprehensive markdown documentation. Built with JacLang and powered by LLM agents, it creates structured documentation complete with dependency graphs, code analysis, and architectural insights.

---

## 🌟 Features

- **Multi-Agent Architecture**: Four specialized agents work together to analyze and document code
- **Automatic Code Analysis**: Parse Python and Jac files to extract functions, classes, and relationships
- **Dependency Visualization**: Generate hierarchical dependency trees and class inheritance graphs
- **LLM-Enhanced Documentation**: AI-generated project overviews and architectural analysis
- **Support for Multiple Languages**: Primary support for Python and Jac, extensible to other languages
- **Markdown Output**: Clean, readable documentation that integrates seamlessly with GitHub

---

## 📁 Project Structure

```
codebase_genius/
│
├── BE/                          # Backend (Multi-Agent System)
│   ├── main.jac                 # Core workflow orchestration & agent definitions
│   ├── main.impl.jac            # Semantic LLM instructions for agents
│   ├── agent_core.jac           # Base agent classes & session management
│   ├── utils.jac                # Utility functions (datetime, etc.)
│   ├── analyzer_utils.py        # Tree-sitter code parsing & graph generation
│   ├── outputs/                 # Generated documentation & graphs
│   │   ├── repos/               # Cloned repositories
│   │   ├── graphs/              # Dependency visualizations (PNG)
│   │   └── <repo_name>/         # Final documentation per repo
│   ├── requirements.txt         # Python dependencies
│   └── README.md                # This file
│
└── FE/                          # Frontend (Streamlit Interface)
    ├── app.py                   # Web UI for interacting with agents
    └── requirements.txt         # Frontend dependencies
```

---

## 🏗️ Architecture

Codebase Genius uses a **multi-agent workflow** where specialized agents collaborate to produce documentation:

### **1. Code Genius (Supervisor)**
- **Role**: Orchestrates the entire workflow
- **Responsibilities**: 
  - Accepts GitHub repository URLs
  - Routes tasks to subordinate agents
  - Manages workflow stages (INIT → CLONING → MAPPING → ANALYSIS → DOCS → COMPLETED)
  - Ensures agents execute in the correct order

### **2. Repo Handler**
- **Role**: Repository validation and cloning
- **Responsibilities**:
  - Validates GitHub URLs
  - Clones repositories to local storage
  - Handles authentication and network errors
  - Reuses existing clones when available

### **3. Repo Mapper**
- **Role**: High-level repository structure analysis
- **Responsibilities**:
  - Generates file tree (excludes `.git`, `node_modules`, etc.)
  - Locates and summarizes README files
  - Provides structural overview for subsequent analysis

### **4. Code Analyzer**
- **Role**: Deep code parsing and relationship extraction
- **Responsibilities**:
  - Uses Tree-sitter to parse Python and Jac files
  - Extracts functions, classes, and their relationships
  - Builds call graphs (who calls whom)
  - Identifies class inheritance hierarchies
  - Generates dependency visualizations
  - Provides query APIs for code exploration

### **5. Doc Genie**
- **Role**: Documentation synthesis and generation
- **Responsibilities**:
  - Combines analysis results into structured markdown
  - Uses LLM to generate project overviews
  - Embeds dependency graphs and class diagrams
  - Creates API reference sections
  - Outputs final `DOCUMENTATION.md`

---

## 🚀 Installation

### **Prerequisites**
- Python 3.10+
- JacLang (latest version)
- Git
- Graphviz (for visualization)

### **Backend Setup**

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/codebase_genius.git
   cd codebase_genius/BE
   ```

2. **Create virtual environment:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables:**
   Create a `.env` file in the `BE/` directory:
   ```bash
   # For Gemini (default)
   GEMINI_API_KEY=your_gemini_api_key_here
   
   # Or for OpenAI
   OPENAI_API_KEY=your_openai_api_key_here
   ```

5. **Install Graphviz:**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install graphviz
   
   # macOS
   brew install graphviz
   
   # Windows
   # Download from https://graphviz.org/download/
   ```

### **Frontend Setup (Optional)**

1. **Navigate to frontend:**
   ```bash
   cd ../FE
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run Streamlit app:**
   ```bash
   streamlit run app.py
   ```

---

## 📖 Usage

### **Command Line (Backend)**

Analyze a repository directly:

```bash
cd BE
jac run main.jac
```

**Note:** Edit the `with entry` block in `main.jac` to specify your target repository:
```jac
with entry {
    utterance = "https://github.com/username/repository";
    supervisor(utterance=utterance) spawn root;
}
```

### **Web Interface (Frontend)**

1. Start the Streamlit app:
   ```bash
   cd FE
   streamlit run app.py
   ```

2. Open your browser to `http://localhost:8501`

3. Enter a GitHub repository URL

4. View generated documentation and download results

---

## 🔧 Configuration

### **Change LLM Provider**

Edit `main.jac`:
```jac
# Use Gemini (default)
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

# Or use OpenAI
glob llm = Model(model_name="openai/gpt-4", verbose=False);
```

### **Adjust Analysis Depth**

Edit `analyzer_utils.py` to control:
- Maximum functions per file to display
- Graph complexity (number of nodes)
- Filtering of built-in functions

---

## 📊 Output Examples

After running analysis on a repository, you'll find:

```
outputs/
└── <repo_name>/
    ├── DOCUMENTATION.md          # Main documentation
    └── graphs/
        ├── dependency_tree.png   # Hierarchical code structure
        └── class_hierarchy.png   # Inheritance relationships
```

### **Sample Documentation Structure:**
1. Project Overview (AI-generated)
2. Codebase Statistics
3. Repository Structure
4. Architecture Analysis
5. Dependency Visualizations
6. Class Reference
7. Function Reference
8. Key Function Relationships

---

## 🛠️ Technologies Used

- **JacLang**: Data-spatial programming for agent orchestration
- **Tree-sitter**: Fast, incremental code parsing
- **Graphviz**: Dependency graph visualization
- **byllm**: LLM integration for Jac
- **Gemini AI**: Natural language generation
- **Streamlit**: Web interface (frontend)
- **Python 3.10+**: Core implementation language

---

## 🧪 Testing

Run queries on analyzed data:

```bash
cd BE
jac run test_queries.jac
```

This tests the CodeAnalyzer query APIs:
- `get_callers(function_name)` - Find who calls a function
- `get_callees(function_name)` - Find what a function calls
- `get_file_entities(filename)` - Get all code from a file
- `list_entities(type)` - List all functions or classes

---

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Support for additional programming languages (JavaScript, Go, Rust)
- Enhanced graph layouts and styling
- Better error handling for edge cases
- Performance optimization for large repositories
- Additional LLM providers

---

## 📝 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

- Built as part of an AI agents coursework assignment
- Inspired by the byLLM Task Manager example from Jaseci Labs
- Uses Tree-sitter parsers from the open-source community

---

## 📧 Contact

For questions or issues, please open a GitHub issue or contact the maintainer.

---

*Generated documentation helps developers understand codebases faster. Codebase Genius makes documentation effortless.*
