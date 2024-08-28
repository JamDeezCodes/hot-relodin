# HotRelodin

Courtesy of (Karl Zylinkski's blog)[https://zylinski.se/posts/hot-reload-gameplay-code/] on how to do hot code reloading with Odin.

Karl's example works with Windows, mine works with macOS.

# Requirements

Install [Odin](https://odin-lang.org/docs/install/)

# Steps

Build the game DLL:
```shell
odin build game.odin -file -build-mode:dll -out:game.dll
```

Compile `main.odin` and run it:
```shell
odin build main.odin -file
./main
```

In `game.odin`, modify `game_update`:
```diff
@(export)
game_update :: proc() -> bool
{
    - memory.some_state += 1
    + memory.some_state -= 1
    fmt.println(memory.some_state)
    return true
}
```

Now you're hot reloadin'!
