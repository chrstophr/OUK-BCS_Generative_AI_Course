import streamlit as st
import subprocess
import os
import time
import json
from pathlib import Path

# Configuration
OUTPUTS_DIR = Path("outputs")
GRAPHS_DIR = OUTPUTS_DIR / "graphs"
JAC_MAIN = "main.jac"

# Page config
st.set_page_config(
    page_title="Codebase Genius",
    page_icon="🧩",
    layout="wide"
)

# Initialize session state
if 'processing' not in st.session_state:
    st.session_state.processing = False
if 'repo_url' not in st.session_state:
    st.session_state.repo_url = ""
if 'completed' not in st.session_state:
    st.session_state.completed = False

def get_repo_name(url):
    """Extract repository name from GitHub URL."""
    return url.rstrip('/').split('/')[-1].replace('.git', '')

def check_outputs_exist(repo_name):
    """Check if analysis outputs exist for the given repo."""
    mapper_file = OUTPUTS_DIR / "repo_mapper_output.json"
    analyzer_file = OUTPUTS_DIR / "analyzer_output.json"
    docs_file = OUTPUTS_DIR / f"{repo_name}_docs.md"
    graph_file = GRAPHS_DIR / "code_graph.png"
    
    return {
        'mapper': mapper_file.exists(),
        'analyzer': analyzer_file.exists(),
        'docs': docs_file.exists(),
        'graph': graph_file.exists(),
        'all_ready': all([mapper_file.exists(), docs_file.exists()])
    }

def run_jac_pipeline(repo_url):
    """Trigger the Jac pipeline as a subprocess."""
    try:
        result = subprocess.run(
            ["jac", "run", JAC_MAIN],
            capture_output=True,
            text=True,
            timeout=600  # 10 minute timeout
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Process timed out after 10 minutes"
    except Exception as e:
        return False, "", str(e)

def load_markdown_doc(repo_name):
    """Load the generated Markdown documentation."""
    docs_file = OUTPUTS_DIR / f"{repo_name}_docs.md"
    if docs_file.exists():
        return docs_file.read_text(encoding='utf-8')
    return None

def load_json_output(file_name):
    """Load JSON output files."""
    json_file = OUTPUTS_DIR / file_name
    if json_file.exists():
        with open(json_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return None

# Header
st.title("🧩 Codebase Genius")
st.markdown("**Automatic Documentation Generator** — Turn any GitHub repository into structured docs.")
st.divider()

# Main input section
col1, col2 = st.columns([3, 1])
with col1:
    repo_url = st.text_input(
        "📦 GitHub Repository URL",
        placeholder="https://github.com/username/repository",
        disabled=st.session_state.processing
    )
with col2:
    st.markdown("<div style='padding-top: 32px;'></div>", unsafe_allow_html=True)
    analyze_button = st.button(
        "🚀 Analyze Repository",
        type="primary",
        disabled=st.session_state.processing or not repo_url,
        use_container_width=True
    )

# Process analysis
if analyze_button and repo_url:
    st.session_state.processing = True
    st.session_state.repo_url = repo_url
    st.session_state.completed = False
    st.rerun()

if st.session_state.processing:
    repo_name = get_repo_name(st.session_state.repo_url)
    st.markdown("---")
    st.markdown("### 🔄 Processing Pipeline")

    progress_container = st.container()
    status_placeholder = st.empty()

    with progress_container:
        col1, col2, col3, col4 = st.columns(4)
        status_icons = {
            'cloning': col1.empty(),
            'mapping': col2.empty(),
            'analyzing': col3.empty(),
            'generating': col4.empty()
        }
        status_icons['cloning'].info("⏳ Cloning...")
        status_icons['mapping'].warning("⏸️ Mapping")
        status_icons['analyzing'].warning("⏸️ Analyzing")
        status_icons['generating'].warning("⏸️ Docs")

    with status_placeholder.container():
        with st.spinner("🚀 Running Codebase Genius pipeline..."):
            success, stdout, stderr = run_jac_pipeline(st.session_state.repo_url)

    if success:
        max_attempts = 30
        for _ in range(max_attempts):
            outputs = check_outputs_exist(repo_name)
            status_icons['cloning'].success("✅ Cloned")
            if outputs['mapper']:
                status_icons['mapping'].success("✅ Mapped")
            if outputs['analyzer']:
                status_icons['analyzing'].success("✅ Analyzed")
            if outputs['docs']:
                status_icons['generating'].success("✅ Generated")
            if outputs['all_ready']:
                st.session_state.completed = True
                st.session_state.processing = False
                st.success("🎉 Analysis complete!")
                time.sleep(1)
                st.rerun()
                break
            time.sleep(2)
        else:
            st.error("⚠️ Timeout waiting for outputs. Check the outputs/ directory manually.")
            st.session_state.processing = False
    else:
        st.error("❌ Pipeline failed. Check logs below:")
        st.code(stderr if stderr else stdout, language="text")
        st.session_state.processing = False

# Display results
if st.session_state.completed and st.session_state.repo_url:
    repo_name = get_repo_name(st.session_state.repo_url)
    st.markdown("---")
    st.header("📊 Analysis Results")

    # Download buttons
    col1, col2 = st.columns(2)
    docs_file = OUTPUTS_DIR / f"{repo_name}_docs.md"
    graph_file = GRAPHS_DIR / "code_graph.png"

    with col1:
        if docs_file.exists():
            with open(docs_file, 'rb') as f:
                st.download_button("📄 Download Docs (.md)", f, file_name=docs_file.name, mime="text/markdown")
    with col2:
        if graph_file.exists():
            with open(graph_file, 'rb') as f:
                st.download_button("🖼️ Download Graph (.png)", f, file_name=graph_file.name, mime="image/png")

    # Tabs
    tab1, tab2, tab3, tab4 = st.tabs(["📝 Documentation", "🗺️ Repo Map", "🔍 Analysis", "📈 Graph"])

    with tab1:
        st.subheader("Generated Documentation")
        md = load_markdown_doc(repo_name)
        if md:
            st.markdown(md, unsafe_allow_html=True)
        else:
            st.warning("Docs not found.")

    with tab2:
        st.subheader("Repository Map")
        data = load_json_output("repo_mapper_output.json")
        if data:
            st.json(data)
        else:
            st.warning("Mapping data not found.")

    with tab3:
        st.subheader("Analyzer Results")
        data = load_json_output("analyzer_output.json")
        if data:
            st.json(data)
        else:
            st.warning("Analyzer data not found.")

    with tab4:
        st.subheader("Code Structure Graph")
        if graph_file.exists():
            st.image(str(graph_file), use_container_width=True)
        else:
            st.warning("Graph not found.")

    st.divider()
    if st.button("🔄 Analyze Another Repository"):
        st.session_state.processing = False
        st.session_state.completed = False
        st.session_state.repo_url = ""
        st.rerun()

# Footer
st.markdown("---")
st.markdown(
    "<div style='text-align:center; color:#666;'>Built with ❤️ using Streamlit & Jac | Codebase Genius v1.0</div>",
    unsafe_allow_html=True
)
