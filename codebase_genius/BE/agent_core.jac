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

# -----------------------------
# Supervisor walker
# -----------------------------
walker supervisor {
    has utterance: str = "";
    has session_id: str = "";

    obj __specs__ {
        static has auth: bool = False;
    }

    # helper: reflectively find a class by name in loaded modules
    def get_agent_class(class_name: str) {
        main_mod = sys.modules.get("__main__");
        if main_mod and hasattr(main_mod, class_name) {
            return getattr(main_mod, class_name, None);
        }

        for (mod_name, mod) in sys.modules.items() {
            if mod and hasattr(mod, class_name) {
                return getattr(mod, class_name, None);
            }
        }
        return None;
    }

    # abstract: decide which agent to route to (implement in supervisor.impl)
    def route_to_agent(utterance: str, history: str) -> AgentTypes abs;

    can supervise with `root entry {
        # ensure a Memory node exists and a Session is available
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

        routed_agent = self.route_to_agent(self.utterance, self.session.get_history());
        if routed_agent == AgentTypes.NONE {
            report {
                "session_id": jid(self.session),
                "response": "I'm sorry, I couldn't determine how to assist you."
            };
            disengage;
        }

        print("********** Routed agent:", routed_agent);

        # get the walker/class for the agent and spawn it with the current session
        agent_cls = self.get_agent_class(routed_agent.value);
        if not agent_cls {
            report {
                "session_id": jid(self.session),
                "response": "I'm sorry, I couldn't find the appropriate agent."
            };
            disengage;  
        }

        # spawn the agent walker with the same session id so it can access session.current_state
        agent_inst = agent_cls();
        agent_inst(
            utterance = self.utterance,
            session_id = jid(self.session)
        ) spawn root;
    }
}


# -----------------------------
# Generic agent walker (toolbox runner)
# -----------------------------
walker agent {
    has utterance: str = "";
    has session_id: str = "";

    obj __specs__ {
        static has auth: bool = False;
    }

    def get_node_class(class_name: str) {
        main_mod = sys.modules.get("__main__");
        if main_mod and hasattr(main_mod, class_name) {
            return getattr(main_mod, class_name, None);
        }

        for (mod_name, mod) in sys.modules.items() {
            if mod and hasattr(mod, class_name) {
                return getattr(mod, class_name);
            }
        }
        return None;
    }

    # abstract: choose which node (toolbox) this agent should visit
    def route_to_node(utterance: str, history: str) -> RoutingNodes abs;

    can execute with `root entry {
        # bind to session (must exist)
        self.session = &(self.session_id);

        routed_node = self.route_to_node(self.utterance, self.session.get_history());
        node_cls = self.get_node_class(routed_node.value);
        if not node_cls {
            print("Failed to get node class for:", routed_node);
            return;
        }
        node_inst = node_cls();
        visit [-->(`?node_cls)] else {
            attached_routed_node = here ++> node_inst;
            visit attached_routed_node;
        }
    }
}
