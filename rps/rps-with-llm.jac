"""Rock Paper Scissors with AI Commentary"""

#import from litellm { completion }
import random;
import from byllm.llm { Model }

# Use an LLM for fun contextual hints
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

"""Provide commentary based on moves"""
def give_hint(player: str, comp: str, result: str) -> str by llm();


walker RPSGame {
    has choice: str;  # "rock", "paper", or "scissors"

    can start with `root entry;
    can process_choice with turn entry;
}

node turn { }

# CLI execution (not cloud mode)
with entry:__main__ {
    root spawn RPSGame("rock");
    root spawn RPSGame("paper");
    root spawn RPSGame("scissors");
    root spawn RPSGame("rock"); # you can add more for extra rounds
}


impl RPSGame.start {
    if not [root --> (`?turn)] {
        next = root ++> turn();
    } else {
        next = [root --> (`?turn)];
    }
    visit next;
}


impl RPSGame.process_choice {
    if [-->] {
        visit [-->];
    } else {
        # Generate fresh computer choice each round
        comp = random.choice(["rock", "paper", "scissors"]);

        print(f"You chose {self.choice}, Computer chose {comp}");

        if self.choice == comp {
            result = "tie";
            print(give_hint(self.choice, comp, result));
        } elif (self.choice == "rock" and comp == "scissors") or
             (self.choice == "paper" and comp == "rock") or
             (self.choice == "scissors" and comp == "paper") {
            result = "win";
            print(give_hint(self.choice, comp, result));
        } else {
            result = "lose";
            print(give_hint(self.choice, comp, result));
        }

        disengage;
    }
}
