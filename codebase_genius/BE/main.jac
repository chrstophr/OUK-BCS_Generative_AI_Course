import json;
import time;
import from typing { List }
import from agent_core { Memory, Session }
import from byllm.llm { Model }
import sys;

glob llm = Model(model_name="gpt-4o", verbose=False);

enum AgentTypes {
    REPO_HANDLER,
    REPO_MAPPER,
    CODE_ANALYZER,
    DOC_GENIE,
    END
}

sem AgentTypes.REPO_HANDLER = "Validates and clones the GitHub repository.";
sem AgentTypes.REPO_MAPPER = "Analyzes the repository structure and summarizes the README.";
sem AgentTypes.CODE_ANALYZER = "Performs call-graph and logic analysis on code modules.";
sem AgentTypes.DOC_GENIE = "Generates the final documentation.";
sem AgentTypes.END = "Workflow termination after documentation is complete.";


enum WorkflowStage {
    INIT,
    CLONING,
    MAPPING,
    ANALYSIS,
    DOCS,
    COMPLETED
}

sem WorkflowStage.INIT = "Workflow starts with a GitHub URL input.";
sem WorkflowStage.CLONING = "RepoHandler validates and clones the repository.";
sem WorkflowStage.MAPPING = "RepoMapper creates structural and README summary.";
sem WorkflowStage.ANALYSIS = "CodeAnalyzer performs deep analysis.";
sem WorkflowStage.DOCS = "DocGenie produces documentation.";
sem WorkflowStage.COMPLETED = "Workflow ends.";


def log_progress(agent: str, message: str) {
    with open("outputs/workflow_log.jsonl", "a") as f {
        rec = {
            "ts": int(time.time()),
            "agent": agent,
            "message": message
        };
        f.write(json.dumps(rec, ensure_ascii=False));
        f.write("\n");
    }
}


node CodeGenius {
    def call_next_agent(current_state: dict) -> AgentTypes by llm(method="Reason");
}


node Agent {
    has agent_type: AgentTypes;
}

walker agent_executor {
    has session: Session | None = None;
    has utterance: str = "";     # GitHub URL or general command
    has session_id: str = "";
    has max_iterations: int = 10;

    can route_workflow with CodeGenius entry {
        if self.session.get_execution_count() >= self.max_iterations {
            print("Max iterations reached, stopping workflow.");
            disengage;
            return;
        }

        current_stage = self.session.current_state.get("stage", WorkflowStage.INIT);
        next_agent = here.call_next_agent(self.session.current_state);

        print(f"Current stage: {current_stage}, Next agent: {next_agent}");

        if next_agent == AgentTypes.END or self.session.current_state.get("stage") == WorkflowStage.COMPLETED {
            print("Workflow completed successfully!");
            disengage;
        } else {
            visit [-->](`?Agent)(?agent_type == next_agent);
        }
    }

    can init_graph with `root entry {
        memory_list = [root --> (`?Memory)];
        if not memory_list {
            memory_list = root ++> Memory();
        }
        memory = memory_list[0];

        if not self.session_id {
            session_list = memory ++> Session();
            self.session = session_list[0];
        } else {
            self.session = &(self.session_id);
        }

        self.session.current_state["stage"] = WorkflowStage.INIT;
        self.session.current_state["utterance"] = self.utterance;

        print(f"Starting workflow for repository: {self.utterance}");

        visit [-->](`?CodeGenius) else {
            router_node = here ++> CodeGenius();
            router_node ++> RepoHandler();
            router_node ++> RepoMapper();
            router_node ++> CodeAnalyzer();
            router_node ++> DocGenie();
            visit router_node;
        }
    }
}

with entry {
    utterance = "https://github.com/chrstophr/Rock-Paper-Scissors";
    agent_executor(utterance=utterance) spawn root;
}
