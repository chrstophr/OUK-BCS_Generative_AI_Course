import from dotenv { load_dotenv }
import sys;
import from utils { get_current_datetime }

# -----------------------------
# Agent Core: Memory & Session
# -----------------------------
node Memory {}

node Session {
    has history: list = [];
    has created_at: str = get_current_datetime();
    has current_state: dict = {};
    has agent_execution_sequence: list = [];
    has max_iterations: int = 3;
    has max_consecutive_same_agent: int = 3;

    # append a history string
    def add_history(entry: str) {
        self.history = self.history + [entry];
    }

    # return last 10 history entries as newline-separated string
    def get_history -> str {
        return "\n".join(self.history[-10:]);
    }

    # set entire current_state dict
    def set_current_state(state: dict) {
        self.current_state = state;
    }

    # return the current_state dict
    def get_current_state -> dict {
        return self.current_state;
    }

    # record that an agent has just executed
    def add_agent_execution(agent_name: str) {
        self.agent_execution_sequence = self.agent_execution_sequence + [agent_name];
    }

    # total executions recorded
    def get_execution_count -> int {
        return len(self.agent_execution_sequence);
    }

    # how many times the same agent has run consecutively at the end of the sequence
    def get_consecutive_count(agent_name: str) -> int {
        count = 0;
        for i in range(len(self.agent_execution_sequence) - 1, -1, -1) {
            if self.agent_execution_sequence[i] == agent_name {
                count += 1;
            } else {
                break;
            }
        }
        return count;
    }

    # heuristics to prevent infinite loops / ping-ponging between agents
    def should_prevent_loop(agent_name: str) -> bool {
        # stop if we've run too many total iterations
        if self.get_execution_count() >= self.max_iterations {
            return True;
        }
        # stop if the same agent is running too many times in a row
        if self.get_consecutive_count(agent_name) >= self.max_consecutive_same_agent {
            return True;
        }
        # detect simple ping-pong pattern A->B->A->B and prevent it
        if len(self.agent_execution_sequence) >= 4 {
            recent = self.agent_execution_sequence[-4:];
            if recent[0] == recent[2] and recent[1] == recent[3] and recent[0] != recent[1] {
                return True;
            }
        }
        return False;
    }

    # human readable execution summary
    def get_execution_summary -> str {
        if not self.agent_execution_sequence {
            return "";
        }
        return " -> ".join(self.agent_execution_sequence);
    }
}

