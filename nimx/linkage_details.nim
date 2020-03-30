
template sdlMain*() =
    when defined(ios) or defined(android):
        when not compileOption("noMain"):
            {.error: "Please run Nim with --noMain flag.".}

        import nimx/system_logger
        {.push stackTrace: off.}
        proc setupLogger() {.cdecl.} =
            errorMessageWriter = proc(msg: string) =
                logi msg
        {.pop.}

        when defined(ios):
            {.emit: "#define __IPHONEOS__".}

        {.emit: """
// The following piece of code is a copy-paste from SDL/SDL_main.h
// It is required to avoid dependency on SDL headers
////////////////////////////////////////////////////////////////////////////////


/**
 *  \file SDL_main.h
 *
 *  Redefine main() on some platforms so that it is called by SDL.
 */

#ifndef SDL_MAIN_HANDLED
#if defined(__WIN32__)
/* On Windows SDL provides WinMain(), which parses the command line and passes
   the arguments to your main function.

   If you provide your own WinMain(), you may define SDL_MAIN_HANDLED
 */
#define SDL_MAIN_AVAILABLE

#elif defined(__WINRT__)
/* On WinRT, SDL provides a main function that initializes CoreApplication,
   creating an instance of IFrameworkView in the process.

   Please note that #include'ing SDL_main.h is not enough to get a main()
   function working.  In non-XAML apps, the file,
   src/main/winrt/SDL_WinRT_main_NonXAML.cpp, or a copy of it, must be compiled
   into the app itself.  In XAML apps, the function, SDL_WinRTRunApp must be
   called, with a pointer to the Direct3D-hosted XAML control passed in.
*/
#define SDL_MAIN_NEEDED

#elif defined(__IPHONEOS__)
/* On iOS SDL provides a main function that creates an application delegate
   and starts the iOS application run loop.

   See src/video/uikit/SDL_uikitappdelegate.m for more details.
 */
#define SDL_MAIN_NEEDED

#elif defined(__ANDROID__)
/* On Android SDL provides a Java class in SDLActivity.java that is the
   main activity entry point.

   See README-android.txt for more details on extending that class.
 */
#define SDL_MAIN_NEEDED

#endif
#endif /* SDL_MAIN_HANDLED */

#ifdef __cplusplus
#define C_LINKAGE   "C"
#else
#define C_LINKAGE
#endif /* __cplusplus */

/**
 *  \file SDL_main.h
 *
 *  The application's main() function must be called with C linkage,
 *  and should be declared like this:
 *  \code
 *  #ifdef __cplusplus
 *  extern "C"
 *  #endif
 *  int main(int argc, char *argv[])
 *  {
 *  }
 *  \endcode
 */

#if defined(SDL_MAIN_NEEDED) || defined(SDL_MAIN_AVAILABLE)
#define main    SDL_main
#endif




//#include <SDL2/SDL_main.h>

#include <stdlib.h>

extern int cmdCount;
extern char** cmdLine;
extern char** gEnv;

N_CDECL(void, NimMain)(void);

int main(int argc, char** args) {
    cmdLine = args;
    cmdCount = argc;
    gEnv = NULL;
    `setupLogger`();
    NimMain();
#ifdef __ANDROID__
    /* Prevent SDLActivity from calling main() again until the main lib
    *  is reloaded
    */
    exit(nim_program_result);
#endif
    return nim_program_result;
}

""".}

when not defined(emscripten):
    when defined(macosx) or defined(ios):
        import macros
        macro passToCAndL(s: string): typed =
            result = newNimNode(nnkStmtList)
            result.add parseStmt("{.passL: \"" & s.strVal & "\".}\n")
            result.add parseStmt("{.passC: \"" & s.strVal & "\".}\n")

        macro useFrameworks(n: varargs[string]): typed =
            result = newNimNode(nnkStmtList, n)
            for i in 0..n.len-1:
                result.add parseStmt("passToCAndL(\"-framework " & n[i].strVal & "\")")

    when defined(ios):
        useFrameworks("OpenGLES", "UIKit", "GameController", "CoreMotion", "Metal", "AVFoundation", "CoreBluetooth")
        when not defined(simulator):
            when hostCPU == "arm":
                {.passC:"-arch armv7".}
                {.passL:"-arch armv7".}
            elif hostCPU == "arm64":
                {.passC:"-arch arm64".}
                {.passL:"-arch arm64".}
    elif defined(macosx):
        useFrameworks("OpenGL", "AppKit", "AudioUnit", "ForceFeedback", "IOKit", "Carbon", "CoreServices", "ApplicationServices")

    when defined(macosx) or defined(ios):
        useFrameworks("AudioToolbox", "CoreAudio", "CoreGraphics", "QuartzCore")
