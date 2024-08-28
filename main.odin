package game

import "core:dynlib"
import "core:os"
import "core:fmt"
import "core:c/libc"

/* The main program loads a game DLL and checks
   once per frame if it changed. If changed, then
   it loads it as a new game DLL. It will feed the
   new DLL the memory the old one used. */
main :: proc()
{
    /* Used to version the game DLL. Incremented on
       each game DLL reload */
    game_api_version := 0
    game_api, game_api_ok := load_game_api(game_api_version)

    if !game_api_ok {
        fmt.println("Failed to load Game API")
        return
    }

    game_api_version += 1

    // Tell the game to start!
    game_api.init()

    // Same as while(true) in c
    for
    {
        /* This updates and renders the game. It
           returns false when we want to exit the
           program (break the main loop) */
        if game_api.update() == false do break

        /* Get the last write date of the game DLL
           and compare it to the date of the DLL used
           by the current game API. If different, then
           try to do a hot reload */
        dll_time, dll_time_err := os.last_write_time_by_name("game.dll")

        full_reset := game_api.reset()

        reload := full_reset || dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

        if reload
        {
            /* Load a new game API. Might fail due to
               game.dll still being written by the compiler.
               In that case it will try again next frame */

            new_api, new_api_ok := load_game_api(game_api_version)

            if new_api_ok 
            {
                if full_reset
                {
                    game_api.shutdown()
                    unload_game_api(game_api)
                    game_api = new_api
                    game_api.init()
                }
                else
                {
                    /* Pointer to game memory used by OLD game DLL */
                    game_memory := game_api.memory()

                    /* Unload the old game DLL. Note that the game
                       memory survives, it will only be deallocated
                       when explicitly freed */
                    unload_game_api(game_api)

                    /* Replace game API with new one. Now any call
                       such as game_api.update() will use the new code */
                    game_api = new_api

                    /* Tell the new game API to use the old one's
                       game memory */
                    game_api.hot_reloaded(game_memory)
                }

                game_api_version += 1
            }
        }
    }

    // Tell the game to deallocate its memory
    game_api.shutdown()
    unload_game_api(game_api)
}

/* Contains pointers to the procedures exposed
   by the game DLL */
GameAPI :: struct {
    init: proc(),
    update: proc() -> bool,
    shutdown: proc(),
    memory: proc() -> rawptr,
    hot_reloaded: proc(rawptr),
    reset: proc() -> bool,

    // The loaded DLL
    lib: dynlib.Library,

    /* Used to compare write date on disk vs when
       game API was created */
    dll_time: os.File_Time,
    api_version: int,
}

/* Load the game DLL and return a new GameAPI
   that contains pointers to the required
   procedures of the game DLL */
load_game_api :: proc(api_version: int) -> (GameAPI, bool)
{
    dll_time, dll_time_err := os.last_write_time_by_name("game.dll")

    if dll_time_err != os.ERROR_NONE
    {
        fmt.println("Could not fetch last write date of game.dll")
        return {}, false
    }

    /* Can't load the game DLL directly. This would
       lock it and prevent hot reload because the compiler
       can no longer write to it. Instead, make a unique
       name based on api_version and copy the DLL to that
       location */
    dll_name := fmt.tprintf("game_{0}.dll", api_version)

    /* Copy the DLL. Sometimes fails since our program
       tries to copy it before the compiler has 
       finished writing it. In that case, try again
       next frame!
        
       NOTE: Here I use macOS copy command, there are
       better ways to copy a file */
    copy_cmd := fmt.ctprintf("cp game.dll {0}", dll_name)
    if libc.system(copy_cmd) != 0
    {
        fmt.println("Failed to copy game.dll to {0}", dll_name)
        return {}, false
    }

    // Load the newly copied game DLL
    lib, lib_ok := dynlib.load_library(dll_name)

    if !lib_ok
    {
        fmt.println("Failed loading game DLL")
        return {}, false
    }

    /* Fetch all procedures marked with @(export)
       inside the game DLL. Note that we can manually
       cast them to the correct signatures */
    api := GameAPI {
        init = cast(proc()) (dynlib.symbol_address(lib, "game_init") or_else nil),
        update = cast(proc() -> bool) (dynlib.symbol_address(lib, "game_update") or_else nil),
        shutdown = cast(proc()) (dynlib.symbol_address(lib, "game_shutdown") or_else nil),
        memory = cast(proc() -> rawptr) (dynlib.symbol_address(lib, "game_memory") or_else nil),
        hot_reloaded = cast(proc(rawptr)) (dynlib.symbol_address(lib, "game_hot_reloaded") or_else nil),
        reset = cast(proc() -> bool) (dynlib.symbol_address(lib, "game_reset") or_else nil),

        lib = lib,
        dll_time = dll_time,
        api_version = api_version,
    }

    if api.init == nil || api.update == nil || api.shutdown == nil || api.memory == nil || api.hot_reloaded == nil || api.reset == nil
    {
        dynlib.unload_library(api.lib)
        fmt.println("Game DLL missing required procedure")
        return {}, false
    }

    return api, true
}

unload_game_api :: proc(api: GameAPI)
{
    if api.lib != nil
    {
        dynlib.unload_library(api.lib)
    }

    /* Delete the copied game DLL

       NOTE: I use the macOS rm command, there are
       better ways to use this */
    del_cmd := fmt.ctprintf("rm game_{0}.dll", api.api_version)
    if libc.system(del_cmd) != 0
    {
        fmt.println("Failed to remove game_{0}.dll", api.api_version)
    }
}
