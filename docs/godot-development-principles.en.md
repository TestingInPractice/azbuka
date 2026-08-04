# Godot Development Principles: Architecture Reference for the Azbuka Game

## Why Architecture Matters

A children's game looks simple: screens, letters, rewards, sounds. But as soon as levels, progress, voice acting, and animations are added to the project, "quick" code without structure turns into spaghetti where every edit breaks a neighboring feature. Architecture solves this problem in advance: it sets the rules by which code is organized into modules, and modules communicate with each other in predictable ways.

For Azbuka this means concrete benefits:

- a new letter or task can be added without touching the answer-checking logic;
- screens can be reworked without affecting the game systems;
- sounds and animations hook in separately from the game rules;
- the project stays readable for any developer who comes after.

Good architecture does not make the game prettier on screen. It makes it maintainable, and therefore shippable.

## Reference Open-Source Projects

Before designing your own structure, it helps to study finished projects with well-documented architecture. Below are examples that show how different teams solve the same problems: modularity, component wiring, and separation of concerns.

### godot-learning-games (Chris Pritchard)

Learning projects for Godot 3 and 4: dodge-the-creeps, coin-dash, escape-the-maze, space-rocks, jungle-jump.

Link: https://github.com/ChrisPritchard/godot-learning-games

What's inside: a series of small, finished 2D games, each demonstrating one or two specific techniques.

What to learn from it: scene inheritance, global autoloads, working with TileMap, the basics of 2D physics. For Azbuka this is the closest reference in scale: simple 2D projects are easy to adapt to letters and tasks.

### blockbliss (hoveringskull)

A complete walkthrough of refactoring a Tetris-like game prototype: from "spaghetti code" to clean architecture with the single responsibility principle.

Before: https://github.com/hoveringskull/blockbliss/tree/pre-refactor
After: https://github.com/hoveringskull/blockbliss/tree/refactor
Video walkthrough: https://www.youtube.com/watch?v=xPLbrgEQLqA

What's inside: the same game in two states, before and after the refactor, which lets you compare approaches on real code.

What to learn from it: contextually hierarchical scene structure, Dependency Injection instead of global autoloads, separating signals by feature (instead of a single "signal hub"), static typing in GDScript, encapsulating features in folders. This is the most valuable example for Azbuka: it shows how to split a monolith into modules by SRP.

### Modular Architecture from GDQuest

A team of 30+ developers open-sourced the Godot project structure for a 40-hour CRPG.

Link: https://www.gdquest.com/library/modular_game_architecture/

What's inside: a description of a project structure proven on a large game.

What to learn from it: the four-folder project split (Add-ons, Systems, UI, Content), where libraries, game rules, presentation, and content do not mix, plus the gyms folder for experiments without breaking the architecture. This principle is covered in more detail in a separate section below.

### godot-tactical-rpg (ramaureirac)

A tactical RPG with a modular architecture split into Models and Modules.

Link: https://github.com/ramaureirac/godot-tactical-rpg
Architecture documentation: https://github.com/ramaureirac/godot-tactical-rpg/blob/main/docs/0.a.%20Detailed%20Project%20Architecture.md

What's inside: a large game in which logic and data are separated from presentation.

What to learn from it: a modular architecture with a Models/Modules split that scales well. Useful as an example of how a project grows without breaking its structure.

### ECS Examples

Entity Component System, "entity-component-system", is an alternative way to build game objects: instead of deep class hierarchies, behavior is assembled from components. For Azbuka this is more food for thought than a mandatory tool, but the idea is worth understanding.

- ecs-demo (natsu-anon): ECS for Godot in C++ via GDExtension, https://github.com/natsu-anon/ecs-demo
- gd-ecs (jonchun): ECS framework in GDScript, https://github.com/jonchun/gd-ecs
- godot-ecs (GodotHub): ECS framework with demo scenes, https://github.com/godothub/godot-ecs, demo: demo/async/view/main.tscn
- Comedot ECS Template: a project template with ECS in the Godot Asset Library, https://godotengine.org/asset-library/asset/2902

### Open_ami (izoft)

A game with composition, autoloads, and adherence to the single responsibility principle (SRP).

Link: https://github.com/izoft/Open_ami

What's inside: a live project where component composition is combined with careful use of autoloads.

What to learn from it: seeing in practice what SRP looks like not in theory but in a working game.

### first-game-in-godot

An example of a game refactored toward an MVC architecture.

Link: https://gitcode.com/GitHub_Trending/fi/first-game-in-godot

What's inside: a game rebuilt on the Model-View-Controller scheme, where data, presentation, and control are separated.

What to learn from it: separation of concerns in MVC terms, which is useful for Azbuka's UI screens: state, presentation, and input handling live in different layers.

## Modular Architecture: The GDQuest Approach

The main idea of GDQuest's modular architecture: the project is divided into four large folders, each responsible for exactly one area, plus one utility folder for experiments.

- Add-ons: libraries that work in any game. Reusable code goes here: managers, utilities, tools not tied to a specific game.
- Systems: the game rules. Combat, AI, state, progress, answer checking. This is where the logic that determines what happens in the game lives.
- UI: presentation only, no logic. Menu screens, HUD, dialogs receive data from systems and display it, but make no game decisions.
- Content: the game's content. Quests, dialogs, levels, letters and tasks. Content describes WHAT is in the game, unlike Systems, which describe HOW the game works.
- gyms: a folder for experiments. Trial scenes and prototypes that do not break the main architecture and do not affect release code.

This split works at any scale: a small game fits entirely within it, and a large one grows without turning into a monolith.

## Recommended Project Structure for Azbuka

For the children's game Azbuka, the GDQuest four-folder model adapts into the following structure:

```
res://
├── addons/          # Utilities (sound manager, object pool)
├── systems/         # Game logic (level state, progress)
├── ui/              # Menu screens, HUD, dialogs
├── content/         # Levels, letters, tasks
├── scenes/          # Scenes grouped by feature (player, letters, rewards)
└── scripts/         # Scripts grouped by feature
```

- addons: reusable utilities, for example a sound manager and an object pool. These modules know nothing about Azbuka; they can be moved to another game.
- systems: game logic, level state, progress, answer-checking rules.
- ui: menu screens, HUD, dialogs. Presentation only, no game decisions.
- content: levels, letters, tasks. The game's data itself.
- scenes: scenes grouped by feature: player, letters, rewards.
- scripts: scripts, also grouped by feature.

The key rule: a folder is defined by the role of the code. Logic does not hide inside UI, content does not describe rules, and utilities know nothing about the specific game.

## SOLID and the Single Responsibility Principle in Godot

The single responsibility principle (SRP) states: each node or script does one thing. In Godot this is especially natural, because a node is already a natural unit of modularity. Separation of responsibilities does not mean "one class per file"; it means that each node has one reason to change.

An example for Azbuka: the flow "clicked a letter, got a result, saved progress, heard a sound" is split into four nodes, each with its own single responsibility:

- LetterButton: presentation and the click on the letter only. The node shows the letter, catches the press, and reports it outward. It does not know whether the answer is right or wrong.
- LetterManager: answer-checking logic only. The node receives the selected letter, compares it against the expected answer, and reports the result. It does no drawing and saves no data.
- ProgressTracker: progress saving only. The node writes and reads the game state: completed letters, earned rewards. It does not take part in answer checking.
- SoundManager: sound playback only. The node receives events and plays the corresponding audio files. It does not decide when or why a sound should play.

If the answer-checking logic moves into LetterButton, the button starts to be responsible for both presentation and game rules. Any change to the rules becomes a change to the button, and any change to the button risks breaking the rules. The separation removes this risk.

## Composition over Inheritance

Deep class hierarchies in games quickly become fragile. A hierarchy like Letter, then VowelLetter, then ConsonantLetter, then a couple more levels down multiplies the number of classes and turns every inheritance step into a bundle of decisions that is hard to change.

Composition offers another path: behavior is assembled from components. Instead of deriving subclasses for every variant of a letter, a single base Letter node is created, and capabilities are added as components.

```
Letter (base node)
├── Collision   # collision component
├── Animation   # animation component
└── Audio       # sound component
```

Behavior is added through signals and attachable scripts rather than through inheritance. A letter with animation and sound differs from a plain letter by its set of components, not by a new class in the hierarchy. This lets you assemble different object variants from ready-made parts without multiplying classes.

## Signals for Loose Coupling

Signals in Godot let nodes communicate without knowing about each other. The sender declares an event and does not care who listens to it. The listener subscribes to the event and does not know who emits it. This kind of coupling is called loose, and it makes the system flexible.

An example from Azbuka: the flow "letter selection, check, reward".

```
LetterButton.emit("letter_selected", letter_id)
        │
        ▼
LetterManager  listens for letter_selected, checks the answer
        │
        ├── emit("answer_correct", letter_id)
        │            │
        │            ▼
        │       UI  listens for answer_correct, shows an animation
        │
        └── emit("answer_wrong", letter_id)
                     │
                     ▼
                SoundManager listens and plays the right sound
```

The letter button emits the signal letter_selected(letter_id). The level manager listens for it and checks the answer. UI listens for the answer_correct signal and shows an animation. Each participant only knows about its own signals and holds no references to the others.

A separate rule from blockbliss: signals are split by feature rather than collected into a single "signal hub". A central signal hub turns into a hidden coupling of all nodes: any change touches everyone. Signals spread across features stay local and understandable.

## Recommendations: What to Study for a Children's Game

For Azbuka there is no need to study everything at once. Three sources cover the main needs:

- godot-learning-games: simple 2D projects, easy to adapt to letters and tasks. This is where to start: small finished games give an understanding of how scenes, nodes, and physics come together into a finished product.
- blockbliss (refactor): an example of how to split a monolith into modules by SRP. The refactor branch shows the target architecture; the pre-refactor branch shows what we are moving away from. It is worth checking against it on every refactor of Azbuka.
- godot-tactical-rpg: a modular architecture with Models/Modules that scales well. A reference for how the project can grow as Azbuka gains more levels and rewards.

While working on Azbuka, it is worth following a set of rules gathered from these examples:

- stick to the four-folder structure: addons, systems, ui, content;
- keep each node responsible for one thing (SRP);
- assemble behavior from components rather than from deep inheritance hierarchies;
- communicate through feature-based signals rather than global calls;
- prefer Dependency Injection over global autoloads whenever possible;
- use static typing in GDScript: it catches errors before runtime and makes the code self-documenting;
- encapsulate features in folders: letters, rewards, and levels do not mix;
- build scenes contextually and hierarchically: each node knows its context, not the whole scene tree.

## Additional Resources

Three resources are enough to solidify the basics:

1. The official Godot 4 tutorial "Dodge the Creeps": a basic 2D game that walks through scenes, nodes, and physics. Most beginners start with it.
2. An article on Godot architecture: an overview of ECS, MVC, DI, and Event-Driven patterns with GDScript examples. A good follow-up after the tutorial, to move from "how to make a game" to "how to organize code".
3. A Godot 4 course on Stepik: a full course on building a platformer from scratch. It gives practice running a project from an empty window to a playable level.
