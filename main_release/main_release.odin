package main_release

import "../game"

main :: proc()
{
    game.game_init()

    for
    {
        if game.game_update() == false do break
    }

    game.game_shutdown()
}
