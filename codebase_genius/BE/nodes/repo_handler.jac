import os;
import git;
import tempfile;
import from utils { get_current_datetime }

node RepoHandler(Agent) {
    has agent_type: AgentTypes = AgentTypes.REPO_HANDLER;

    def validate_and_clone_repo(repo_url: str) -> str {
        temp_dir = tempfile.mkdtemp(prefix="repo_clone_");
        try {
            print(f"Cloning repository from {repo_url}...");
            git.Repo.clone_from(repo_url, temp_dir);
            print(f"Repository cloned successfully at {temp_dir}");
            return temp_dir;
        } catch git.GitCommandError as e {
            print(f"Error cloning repository: {e}");
            return "";
        }
    }

    can execute_clone with agent_executor entry {
        visitor.session.add_agent_execution("REPO_HANDLER");
        repo_url = visitor.utterance;

        clone_path = self.validate_and_clone_repo(repo_url);
        if clone_path != "" {
            visitor.session.current_state["repo_cloned"] = True;
            visitor.session.current_state["repo_path"] = clone_path;
            visitor.session.current_state["stage"] = WorkflowStage.MAPPING;
            print(f"Cloned successfully: {clone_path}");
        } else {
            visitor.session.current_state["repo_cloned"] = False;
            print("Cloning failed. Check the repository URL or network connection.");
        }

        visit [<--](`?CodeGenius);
    }
}
