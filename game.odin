package game

import "core:fmt"

/* Game state lives within this struct.
   In order for hot reloading to work the game's memory
   must be transferrable from one game DLL to another
   when a hot reload occurs. We can do that when all the
   game's memory lives in here */

GameMemory :: struct
{
    some_state: int,
}

memory: ^GameMemory

/* Allocates the GameMemory that we use to store
   our game's state. We assign it to a global
   variable so we can use it from the other procedures. */
@(export)
game_init :: proc()
{
    memory = new(GameMemory)
}

/* Simulation and rendering goes here. Return 
   false when you wish to terminate the program */
@(export)
game_update :: proc() -> bool
{
    memory.some_state += 1
    fmt.println(memory.some_state)
    return true
}

/* Called by the main program when the main loop
   has exited. Clean up your memory here */
@(export)
game_shutdown :: proc()
{
    free(memory)
}

/* Returns a pointer to the game memory. When
   hot reloading, the main program needs a pointer
   to the game memory. It can then load a new game
   DLL and tell it to use the same memory by calling
   game_hot_reloaded on the new game DLL, supplying
   it the game memory pointer */
@(export)
game_memory :: proc() -> rawptr
{
    return memory
}

/* Used to set the game memory pointer after a
   hot reload occurs. See game_memory comments. */
@(export)
game_hot_reloaded :: proc(mem: ^GameMemory)
{
    memory = mem
}
