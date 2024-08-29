# HotRelodin

Courtesy of [Karl Zylinkski's blog](https://zylinski.se/posts/hot-reload-gameplay-code/) on how to do hot code reloading with Odin. Find his more comprehensive template [here](https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template).

### Requirements

Install the [Odin](https://odin-lang.org/docs/install/) programming language.

### Steps

Build the game DLL:
```shell
odin build game -build-mode:dll -out:game.dll
```

Compile `main` and run it:
```shell
odin run main
```

In `game/game.odin`, modify `game_update`:
```diff
game_update :: proc() -> bool
{
-   memory.some_state += 1
+   memory.some_state -= 1
    fmt.println(memory.some_state)
    return true
}
```

Rebuild the game DLL:
```shell
odin build game -build-mode:dll -out:game.dll
```

Now you're "hot relodin"!

### Compile in "release" mode

```shell
odin build main_release
```
