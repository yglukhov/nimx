import macros

when not defined(windows):
    when not compileOption("noMain"):
        {.error: "Please run Nim with --noMain flag.".}

    {.emit: """
#include <SDL2/SDL_main.h>

extern int cmdCount;
extern char** cmdLine;
extern char** gEnv;

N_CDECL(void, NimMain)(void);

#ifdef _WIN32
#include <windows.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine,
                   int nCmdShow) {
    cmdLine = __argv;
    cmdCount = __argc;
#else
int main(int argc, char** args) {
    cmdLine = args;
    cmdCount = argc;
#endif
    gEnv = NULL;
    NimMain();
    return nim_program_result;
}

""".}

when defined(macosx) or defined (ios):
    macro passToCAndL(s: string): stmt =
        result = newNimNode(nnkStmtList)
        result.add parseStmt("{.passL: \"" & s.strVal & "\".}\n")
        result.add parseStmt("{.passC: \"" & s.strVal & "\".}\n")

    macro useFrameworks(n: varargs[string]): stmt =
        result = newNimNode(nnkStmtList, n)
        for i in 0..n.len-1:
            result.add parseStmt("passToCAndL(\"-framework " & n[i].strVal & "\")")

when defined(ios):
    useFrameworks("OpenGLES", "UIKit")
    when not defined(simulator):
        {.passC:"-arch armv7".}
        {.passL:"-arch armv7".}
elif defined(macosx):
    useFrameworks("OpenGL", "AppKit", "AudioUnit", "ForceFeedback", "IOKit", "Carbon", "CoreServices", "ApplicationServices")

when defined(macosx) or defined(ios):
    useFrameworks("AudioToolbox", "CoreAudio", "CoreGraphics", "QuartzCore")
