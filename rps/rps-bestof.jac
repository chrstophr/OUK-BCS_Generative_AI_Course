import random;

walker RPSGame {
    has rounds: int = 3;
    has wins_needed: int = 0;
    has player_score: int = 0;
    has computer_score: int = 0;

    can start with `root entry;
    can play_round with turn entry;
}

node turn {
    has round_number: int;
}

with entry:__main__ {
    root spawn RPSGame();
}

impl RPSGame.start {
    self.wins_needed = (self.rounds + 1) / 2;
    print(f"Starting Rock-Paper-Scissors best-of-{self.rounds} (first to {self.wins_needed}).");

    end: `root | turn = here;
    for i = 1 to i <= self.rounds by i += 1 {
        end ++> (end := turn(i));
    }
    visit [-->];
}

impl RPSGame.play_round {
    player = input("Choose rock, paper, or scissors (r/p/s allowed): ");
    if player == "r" { player = "rock"; }
    elif player == "p" { player = "paper"; }
    elif player == "s" { player = "scissors"; }

    valid = ["rock","paper","scissors"];
    if player not in valid {
        print("Invalid choice, try again.");
        visit [-->];   # retry same node
        return;
    }

    comp = random.choice(valid);
    print(f"Computer chose {comp}");

    if player == comp {
        print("Tie round.");
    } elif (player == "rock" and comp == "scissors") or
         (player == "scissors" and comp == "paper") or
         (player == "paper" and comp == "rock") {
        self.player_score += 1;
        print("You win the round!");
    } else {
        self.computer_score += 1;
        print("Computer wins the round!");
    }

    print(f"Score: You {self.player_score} - CPU {self.computer_score}");

    if self.player_score >= self.wins_needed or self.computer_score >= self.wins_needed {
        winner = "You" if self.player_score > self.computer_score else "Computer";
        print(f"Match over — {winner} won!");
        disengage;
    } else {
        visit [-->];
    }
}
