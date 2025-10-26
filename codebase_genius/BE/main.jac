"""
Codebase Genius - Main Entry
Runs the multi-agent system for automatic code documentation.
"""
import from dotenv { load_dotenv }
import sys;
import os;
import from datetime { datetime }

include agent_core;
include code_genius;
include repo_mapper;
include code_analyzer;
include doc_genie;
include utils;

with entry {
    print("🚀 Codebase Genius backend loaded successfully!");
}

# 🩺 Health Check Walker
walker health_check {
    obj __specs__ {
        static has auth: bool = False;  # 👈 Allow public access
    }
    
    can run with `root entry {
        report {"status": "ok", "message": "Codebase Genius backend is alive"};
    }
}