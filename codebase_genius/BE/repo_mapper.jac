"""
Repo Mapper Agent
Responsible for cloning a GitHub repository, generating its file tree, 
and summarizing its README.
"""

import os;
import json;
import from byllm.llm { Model }
include utils;
include agent_core;

# Global LLM model (Gemini for summarization)
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

node RepoMapper(Toolbox) {
    has repo_url: str = "";
    has local_path: str = "";
    has file_tree: dict = {};
    has readme_summary: str = "";

    def clone_repository(url: str) -> str;
    def generate_file_tree(path: str) -> dict;
    def summarize_readme(path: str) -> str;  # simplified for now

    can execute with repo_mapper entry {
        if not visitor.repo_url {
            report "❌ Missing repository URL.";
            disengage;
        }

        self.repo_url = visitor.repo_url;
        print(f"🌀 Cloning repository: {self.repo_url}");
        self.local_path = self.clone_repository(self.repo_url);

        if not self.local_path {
            report "❌ Failed to clone repository.";
            disengage;
        }

        print(f"📁 Generating file tree for: {self.local_path}");
        self.file_tree = self.generate_file_tree(self.local_path);

        print(f"📝 Summarizing README (if present)...");
        self.readme_summary = self.summarize_readme(self.local_path);

        report {
            "repo_url": self.repo_url,
            "local_path": self.local_path,
            "file_tree": self.file_tree,
            "readme_summary": self.readme_summary
        };
    }
}

walker repo_mapper {
    has repo_url: str = "";

    obj __specs__ {
        static has auth: bool = False;
    }

    can execute with `root entry {
        if not self.repo_url {
            report "❌ Missing repository URL.";
            disengage;
        }

        print(f"🔧 Starting RepoMapper for: {self.repo_url}");
        mapper = RepoMapper(repo_url=self.repo_url);

        # ✅ Clone repository and store the result
        mapper.local_path = mapper.clone_repository(mapper.repo_url);
        if not mapper.local_path {
            report "❌ Failed to clone repository.";
            disengage;
        }

        print(f"📁 Repo cloned to: {mapper.local_path}");

        # ✅ Generate file tree
        mapper.file_tree = mapper.generate_file_tree(mapper.local_path);
        if not mapper.file_tree {
            print("⚠️ No file tree generated — check path or permissions.");
        }

        # ✅ Summarize README
        mapper.readme_summary = mapper.summarize_readme(mapper.local_path);

        # ✅ Final report
        report {
            "repo_url": mapper.repo_url,
            "local_path": mapper.local_path,
            "file_tree": mapper.file_tree,
            "readme_summary": mapper.readme_summary
        };
    }
}
