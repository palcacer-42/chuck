import random
import os
import time

class ShellLearningGame:
    def __init__(self):
        self.score = 0
        self.level = 1
        self.commands = {
            'ls': 'List directory contents',
            'cd': 'Change directory',
            'pwd': 'Print working directory',
            'mkdir': 'Create a new directory',
            'touch': 'Create a new file',
            'cp': 'Copy files or directories',
            'mv': 'Move or rename files or directories',
            'rm': 'Remove files or directories',
            'cat': 'Display file contents',
            'grep': 'Search for patterns in files',
            'chmod': 'Change file permissions',
            'man': 'Display manual for a command'
        }
        
    def clear_screen(self):
        os.system('cls' if os.name == 'nt' else 'clear')
    
    def print_header(self):
        print("=" * 50)
        print("        SHELL COMMAND LEARNING GAME")
        print("=" * 50)
        print(f"Level: {self.level} | Score: {self.score}")
        print()
    
    def display_welcome(self):
        self.clear_screen()
        self.print_header()
        print("Welcome to the Shell Command Learning Game!")
        print()
        print("In this game, you'll learn essential shell commands")
        print("by completing challenges and answering questions.")
        print()
        print("Commands you'll learn:")
        for cmd, desc in self.commands.items():
            print(f"  {cmd}: {desc}")
        print()
        input("Press Enter to start...")
    
    def multiple_choice_question(self):
        self.clear_screen()
        self.print_header()
        
        # Select a random command
        command = random.choice(list(self.commands.keys()))
        description = self.commands[command]
        
        print(f"What does the '{command}' command do?")
        print()
        
        # Create options
        options = [description]
        wrong_options = []
        
        # Get wrong options from other commands
        other_commands = [cmd for cmd in self.commands.keys() if cmd != command]
        random.shuffle(other_commands)
        
        for cmd in other_commands[:3]:  # Get 3 wrong options
            wrong_options.append(self.commands[cmd])
        
        # Combine and shuffle options
        all_options = options + wrong_options
        random.shuffle(all_options)
        
        # Display options
        for i, option in enumerate(all_options, 1):
            print(f"{i}. {option}")
        
        print()
        try:
            answer = int(input("Enter your choice (1-4): "))
            if all_options[answer-1] == description:
                print("✅ Correct!")
                self.score += 10
                return True
            else:
                print(f"❌ Incorrect. The correct answer is: {description}")
                return False
        except (ValueError, IndexError):
            print("❌ Invalid input. Please enter a number between 1 and 4.")
            return False
    
    def command_matching_challenge(self):
        self.clear_screen()
        self.print_header()
        
        print("Match the command with its description:")
        print()
        
        # Select 4 random commands
        selected_commands = random.sample(list(self.commands.keys()), 4)
        descriptions = [self.commands[cmd] for cmd in selected_commands]
        random.shuffle(descriptions)
        
        # Display commands and descriptions
        for i, cmd in enumerate(selected_commands, 1):
            print(f"{i}. {cmd}")
        
        print()
        print("Descriptions:")
        for i, desc in enumerate(descriptions, 1):
            print(f"  {i}. {desc}")
        
        print()
        print("Enter your matches as command_number:description_number pairs")
        print("Example: 1:3 2:1 3:4 4:2")
        
        try:
            user_input = input("Your answer: ")
            pairs = user_input.split()
            
            correct = 0
            for pair in pairs:
                cmd_idx, desc_idx = map(int, pair.split(':'))
                if self.commands[selected_commands[cmd_idx-1]] == descriptions[desc_idx-1]:
                    correct += 1
            
            if correct == 4:
                print("✅ Perfect! All matches are correct!")
                self.score += 20
                return True
            else:
                print(f"❌ You got {correct}/4 correct. Keep practicing!")
                return False
                
        except (ValueError, IndexError):
            print("❌ Invalid input format. Please try again.")
            return False
    
    def scenario_based_challenge(self):
        self.clear_screen()
        self.print_header()
        
        scenarios = [
            {
                'description': "You want to see what files are in your current directory.",
                'correct': 'ls',
                'options': ['ls', 'pwd', 'cd', 'dir']
            },
            {
                'description': "You need to create a new directory called 'projects'.",
                'correct': 'mkdir projects',
                'options': ['mkdir projects', 'touch projects', 'cd projects', 'newdir projects']
            },
            {
                'description': "You want to see the contents of a file called 'notes.txt'.",
                'correct': 'cat notes.txt',
                'options': ['cat notes.txt', 'ls notes.txt', 'view notes.txt', 'open notes.txt']
            },
            {
                'description': "You need to copy 'file1.txt' to 'file2.txt'.",
                'correct': 'cp file1.txt file2.txt',
                'options': ['cp file1.txt file2.txt', 'mv file1.txt file2.txt', 'copy file1.txt file2.txt', 'dup file1.txt file2.txt']
            },
            {
                'description': "You want to find all lines containing 'error' in a log file.",
                'correct': 'grep error logfile.txt',
                'options': ['grep error logfile.txt', 'find error logfile.txt', 'search error logfile.txt', 'cat error logfile.txt']
            }
        ]
        
        scenario = random.choice(scenarios)
        
        print("Scenario:")
        print(scenario['description'])
        print()
        print("Which command would you use?")
        print()
        
        for i, option in enumerate(scenario['options'], 1):
            print(f"{i}. {option}")
        
        print()
        try:
            answer = int(input("Enter your choice (1-4): "))
            if scenario['options'][answer-1] == scenario['correct']:
                print("✅ Correct! That's the right command for this scenario.")
                self.score += 15
                return True
            else:
                print(f"❌ Incorrect. The correct command is: {scenario['correct']}")
                return False
        except (ValueError, IndexError):
            print("❌ Invalid input. Please enter a number between 1 and 4.")
            return False
    
    def play_round(self):
        challenges = [
            self.multiple_choice_question,
            self.command_matching_challenge,
            self.scenario_based_challenge
        ]
        
        # Randomly select a challenge type
        challenge = random.choice(challenges)
        result = challenge()
        
        print()
        input("Press Enter to continue...")
        
        # Level up after every 3 correct answers
        if result:
            self.level = (self.score // 30) + 1
    
    def display_progress(self):
        self.clear_screen()
        self.print_header()
        
        print("Your Progress:")
        print()
        
        progress = min(self.score / 100, 1.0)  # Cap at 100% for display
        bar_length = 30
        filled_length = int(bar_length * progress)
        bar = '█' * filled_length + '░' * (bar_length - filled_length)
        
        print(f"Progress: [{bar}] {progress*100:.1f}%")
        print()
        
        if self.score >= 100:
            print("🎉 Congratulations! You've mastered the basics!")
        elif self.score >= 70:
            print("Great job! You're becoming a shell expert!")
        elif self.score >= 40:
            print("Good progress! Keep learning!")
        else:
            print("Keep practicing! You're getting the hang of it.")
        
        print()
        input("Press Enter to continue...")
    
    def play_game(self):
        self.display_welcome()
        
        while self.score < 100:  # Game ends at 100 points
            self.play_round()
            
            # Show progress every 2 rounds or when level changes
            if self.score % 20 == 0 or random.random() < 0.3:
                self.display_progress()
        
        self.display_progress()
        print("Thanks for playing! Keep practicing your shell commands!")

# Run the game
if __name__ == "__main__":
    game = ShellLearningGame()
    game.play_game()