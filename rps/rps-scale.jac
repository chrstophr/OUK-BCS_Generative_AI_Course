import random;

walker RPSGame {
    has choice: str;

    can start with `root entry;
    can process_choice with turn entry;
}

node turn {
    has computer_choice: str;

    # Assign a fresh random choice every time a turn is created
    def init {
        self.computer_choice = random.choice(["rock","paper","scissors"]);
    }
}

with entry:__main__ {
    root spawn RPSGame("rock");
    root spawn RPSGame("paper");
    root spawn RPSGame("scissors");
    root spawn RPSGame("rock");
    root spawn RPSGame("paper");
    root spawn RPSGame("scissors");
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
        print(f"You chose {self.choice}, Computer chose {here.computer_choice}");

        if self.choice == here.computer_choice {
            print("It’s a tie!");
        } elif (self.choice == "rock" and here.computer_choice == "scissors") or
             (self.choice == "paper" and here.computer_choice == "rock") or
             (self.choice == "scissors" and here.computer_choice == "paper") {
            print("You win!");
        } else {
            print("Computer wins!");
        }

        disengage;
    }
}
