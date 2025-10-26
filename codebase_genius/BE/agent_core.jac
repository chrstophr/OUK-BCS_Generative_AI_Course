# ===== agent_core.jac =====
# Core nodes and routing logic for Codebase Genius
# TODO: Add advanced routing and memory management later

import from dotenv { load_dotenv }
import sys;

node Memory {}

node Session {
    has history: list = [];
    has created_at: str = "2025-10-23";  # TODO: use real timestamp

    def add_history(entry: str) {
        self.history = self.history + [entry];
    }

    def get_history -> str {
        return "\n".join(self.history[-10:]);
    }
}

node Toolbox {
    def route_and_run(utterance: str, history: str) -> str abs;
    can execute with code_genius entry {
        # TODO: Implement later
        report {"response": "Placeholder response from Toolbox."};
    }
}

enum RoutingNodes {
    GENERAL_CHAT = "GeneralChat"
}

walker code_genius {
    has utterance: str = "";
    has session_id: str = "";

    obj __specs__ {
        static has auth: bool = False;
    }

    def get_node_class(class_name: str) {
        main_mod = sys.modules.get("main");  # ✅ Avoid __main__ bug
        if main_mod and hasattr(main_mod, class_name) {
            return getattr(main_mod, class_name, None);
        }
        return None;
    }

    def route_to_node(utterance: str, history: str) -> RoutingNodes abs;

    can execute with `root entry {
        memory_list = [root --> (`?Memory)];
        if not memory_list {
            memory_list = root ++> Memory();
        }
        memory = memory_list[0];
        session_list = memory ++> Session();
        self.session = session_list[0];
        print("🧠 Placeholder: Routing utterance ->", self.utterance);
        report {"response": "Codebase Genius core booted successfully!"};
    }
}

with entry {
    load_dotenv();
    print("✅ Environment loaded and Codebase Genius core initialized");
}
