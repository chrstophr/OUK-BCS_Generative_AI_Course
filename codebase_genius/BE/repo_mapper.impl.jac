# ============================================================
# Implementation for RepoMapper methods using ::py:: inline blocks
# ============================================================

impl RepoMapper.clone_repository {
    ::py::
    import os, subprocess, tempfile, shutil

    base_dir = tempfile.mkdtemp(prefix="repo_")

    if not url or not isinstance(url, str):
        print("❌ Invalid repository URL.")
        return ""

    try:
        print(f"🔁 Cloning repo from: {url}")
        subprocess.run(["git", "clone", "--depth", "1", url, base_dir], check=True)
        print(f"✅ Repo cloned at: {base_dir}")
        return base_dir
    except Exception as e:
        print(f"⚠️ Clone failed: {e}")
        shutil.rmtree(base_dir, ignore_errors=True)
        return ""
    ::py::
}

impl RepoMapper.generate_file_tree {
    ::py::
    import os

    def build_tree(path: str):
        if not path or not os.path.exists(path):
            print(f"❌ Invalid or missing path for file tree generation: {path}")
            return {}

        structure = {}
        print(f"📂 Building file tree for: {path}")

        for root, dirs, files in os.walk(path):
            # Exclude irrelevant directories
            dirs[:] = [d for d in dirs if d not in [".git", "__pycache__", "node_modules", "venv", ".venv", ".mypy_cache", "dist", "build"]]

            rel_root = os.path.relpath(root, path)
            structure[rel_root] = {
                "dirs": sorted(dirs),
                "files": sorted(files)
            }

        print(f"✅ File tree built with {len(structure)} directories")
        return structure

    return build_tree(path)
    ::py::
}


impl RepoMapper.summarize_readme {
    ::py::
    import os

    readme_candidates = ["README.md", "README.rst", "README"]
    for c in readme_candidates:
        p = os.path.join(path, c)
        if os.path.exists(p):
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            lines = "\n".join(content.splitlines()[:10])
            print(f"📝 README found at {p}")
            return lines

    print("ℹ️ No README found.")
    return "No README found."
    ::py::
}
