import nake
import tables
import jester, asyncdispatch, browsers, closure_compiler # Stuff needed for JS target

let appName = "MyGame"
let bundleId = "com.mycompany.MyGame"
let javaPackageId = "com.mycompany.MyGame"

let androidSdk = "~/Library/Android/sdk"
let androidNdk = "~/Library/Android/sdk/ndk-bundle"
let sdlRoot = "~/Projects/SDL"

# This should point to the Nim include dir, where nimbase.h resides.
# Needed for android only
let nimIncludeDir = "~/Projects/nim/lib"

let macOSSDKVersion = "10.10"
let macOSMinVersion = "10.6"

let iOSSDKVersion = "8.4"
let iOSMinVersion = iOSSDKVersion

# Simulator device identifier should be set to run the simulator.
# Available simulators can be listed with the command:
# $ xcrun simctl list
let iOSSimulatorDeviceId = "18BE8493-7EFB-4570-BF2B-5F5ACBCCB82B"

let bundleName = appName & ".app"

let parallelBuild = "--parallelBuild:1"
let nimVerbose = "--verbosity:0"

let xCodeApp = "/Applications/Xcode.app"

let macOSSDK = xCodeApp/"Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX" & macOSSDKVersion & ".sdk"
let iOSSDK = xCodeApp/"Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS" & iOSSDKVersion & ".sdk"
let iOSSimulatorSDK = xCodeApp/"Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator" & iOSSDKVersion & ".sdk"

when defined(Windows):
    const silenceStdout = "2>nul"
else:
    const silenceStdout = ">/dev/null"

if dirExists("../.git"): # Install nimx
    withDir "..":
        direShell "nimble", "-y", "install", silenceStdout

proc infoPlistSetValueForKey(path, value, key: string) =
    direShell "defaults", "write", path, key, value

proc absPath(path: string): string =
    if path.isAbsolute(): path else: getCurrentDir() / path

proc makeBundle() =
    removeDir bundleName
    createDir bundleName
    for t, p in walkDir("res"):
        if t == pcDir:
            copyDir(p, bundleName / extractFilename(p))
        else:
            copyFile(p, bundleName / extractFilename(p))
    moveFile "main", bundleName / "main"
    let infoPlistPath = absPath(bundleName / "Info")
    infoPlistSetValueForKey(infoPlistPath, appName, "CFBundleName")
    infoPlistSetValueForKey(infoPlistPath, bundleId, "CFBundleIdentifier")

proc symLink(source, destination: string) =
    direShell "ln", "-sf", source, destination

proc createSDLIncludeLink(dir: string, preferInstalledSDL: bool) =
    createDir dir
    if preferInstalledSDL and dirExists("/usr/local/include/SDL2"):
        symLink("/usr/local/include/SDL2", dir/"SDL2")
    else:
        symLink(sdlRoot/"include", dir/"SDL2")

proc runAppInSimulator() =
    var waitForDebugger = "--wait-for-debugger"
    waitForDebugger = ""
    direShell "open", "-a", "iOS\\ Simulator"
    shell "xcrun", "simctl", "uninstall", iOSSimulatorDeviceId, bundleId
    direShell "xcrun", "simctl", "install", iOSSimulatorDeviceId, bundleName
    direShell "xcrun", "simctl", "launch", waitForDebugger, iOSSimulatorDeviceId, bundleId

proc replaceVarsInFile(file: string, vars: Table[string, string]) =
    var content = readFile(file)
    for k, v in vars:
        content = content.replace("$(" & k & ")", v)
    writeFile(file, content)

proc buildSDLForDesktop(): string =
    when defined(linux):
        result = "/usr/lib"
    elif defined(macosx):
        if fileExists("/usr/local/lib/libSDL2.a") or fileExists("/usr/local/lib/libSDL2.dylib"):
            result = "/usr/local/lib"
        else:
            let xcodeProjDir = expandTilde(sdlRoot)/"Xcode/SDL"
            let libDir = xcodeProjDir/"build/Release"
            if not fileExists libDir/"libSDL2.a":
                direShell "xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-target", "Static\\ Library", "-configuration", "Release", "-sdk", "macosx"&macOSSDKVersion, "SYMROOT=build"
            result = libDir
    else:
        assert(false, "Don't know where to find SDL")


proc buildSDLForIOS(forSimulator: bool = false): string =
    let entity = if forSimulator: "iphonesimulator" else: "iphoneos"
    let xcodeProjDir = expandTilde(sdlRoot)/"Xcode-iOS/SDL"
    let libDir = xcodeProjDir/"build/Release-" & entity
    if not fileExists libDir/"libSDL2.a":
        direShell "xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-configuration", "Release", "-sdk", entity&iOSSDKVersion, "SYMROOT=build", "ARCHS=\"i386 x86_64\""
    libDir

proc makeAndroidBuildDir(): string =
    let buildDir = "android"/javaPackageId
    if not dirExists buildDir:
        copyDir "android/template", buildDir
        symLink(sdlRoot/"src", buildDir/"jni/SDL/src")
        symLink(sdlRoot/"include", buildDir/"jni/SDL/include")
        createSDLIncludeLink(buildDir/"jni/src", false)

        let mainActivityPath = javaPackageId.replace(".", "/")
        createDir(buildDir/"src"/mainActivityPath)
        let mainActivityJava = """
        package """ & javaPackageId & """;
        import org.libsdl.app.SDLActivity;
        public class MainActivity extends SDLActivity {}
        """
        writeFile(buildDir/"src"/mainActivityPath/"MainActivity.java", mainActivityJava)

        let vars = {
            "PACKAGE_ID" : javaPackageId,
            "APP_NAME" : appName
            }.toTable()

        replaceVarsInFile buildDir/"AndroidManifest.xml", vars
        replaceVarsInFile buildDir/"res/values/strings.xml", vars
    buildDir

proc runNim(arguments: varargs[string]) =
    var args = @[nimExe, "c", "--noMain", parallelBuild, "--stackTrace:on", "--lineTrace:off",
                nimVerbose, "-d:noAutoGLerrorCheck", "-d:release", "--opt:speed", "--passC:-g",
                "--threads:on", "--warning[LockLevel]:off"]
    args.add arguments
    args.add "main"
    direShell args

task defaultTask, "Build and run":
    createSDLIncludeLink("nimcache", true)
    when defined(macosx):
        if not dirExists(macOSSDK):
            echo "MacOSX SDK not found: ", macOSSDK
            return
        runNim "--passC:-Inimcache", "--passC:-isysroot", "--passC:" & macOSSDK, "--passL:-isysroot", "--passL:" & macOSSDK,
            "--passC:-mmacosx-version-min=" & macOSMinVersion, "--passL:-mmacosx-version-min=" & macOSMinVersion,
            "--passL:-fobjc-link-runtime", "-d:SDL_Static", "--passL:-L"&buildSDLForDesktop(), "--passL:-lSDL2",
            "--run"
    elif defined(windows):
        # dynamic link sdl2
        direShell nimExe, "c",
            "-d:noAutoGLerrorCheck", "-d:release",
            "--opt:speed", "--threads:on",
            "main"
    else:
        runNim "--run", "--passL:-L/usr/local/lib", "--passL:-Wl,-rpath,/usr/local/lib", "--passL:-lSDL2", "--passL:-lpthread"

task "ios-sim", "Build and run in iOS simulator":
    if not dirExists(iOSSimulatorSDK):
        echo "iOS Simulator SDK not found: ", iOSSimulatorSDK
        return
    createSDLIncludeLink("nimcache", false)
    runNim "--passC:-Inimcache", "--cpu:amd64", "--os:macosx", "-d:ios", "-d:iPhone", "-d:simulator", "-d:SDL_Static",
        "--passC:-isysroot", "--passC:" & iOSSimulatorSDK, "--passL:-isysroot", "--passL:" & iOSSimulatorSDK,
        "--passL:-L" & buildSDLForIOS(true), "--passL:-lSDL2",
        "--passC:-mios-simulator-version-min=" & iOSMinVersion, "--passL:-mios-simulator-version-min=" & iOSMinVersion,
        "--passL:-fobjc-link-runtime"
    makeBundle()
    runAppInSimulator()

task "ios", "Build for iOS":
    if not dirExists(iOSSDK):
        echo "iOS SDK not found: ", iOSSDK
        return

    createSDLIncludeLink("nimcache", false)
    runNim "--passC:-Inimcache", "--cpu:arm", "--os:macosx", "-d:ios", "-d:iPhone", "-d:SDL_Static",
        "--passC:-isysroot", "--passC:" & iOSSDK, "--passL:-isysroot", "--passL:" & iOSSDK,
        "--passL:-L" & buildSDLForIOS(false), "--passL:-lSDL2",
        "--passC:-mios-version-min=" & iOSMinVersion, "--passL:-mios-version-min=" & iOSMinVersion,
        "--passL:-fobjc-link-runtime"
    echo "TODO: Codesign!"
    makeBundle()

task "droid", "Build for android and install on the connected device":
    let buildDir = makeAndroidBuildDir()
    let droidSrcDir = buildDir / "jni/src"
    runNim "--compileOnly",  "--cpu:arm", "--os:linux", "-d:android", "-d:SDL_Static", "--nimcache:" & droidSrcDir

    # Copy resources. TODO: This is a quick mock of how it should work.
    direShell "mkdir", "-p", buildDir / "assets"
    direShell "cp", "-vR", "res/*", buildDir / "assets"

    cd buildDir
    putEnv "NIM_INCLUDE_DIR", expandTilde(nimIncludeDir)
    direShell androidSdk/"tools/android", "update", "project", "-p", ".", "-t", "android-22"
    direShell androidNdk/"ndk-build"
    #putEnv "ANDROID_SERIAL", "12345" # Target specific device
    direShell "ant", "debug", "install"

task "js", "Create Javascript version.":
    direShell nimExe, "js", "--stackTrace:off", "--warning[LockLevel]:off", "main"
    closure_compiler.compileFileAndRewrite("nimcache/main.js", ADVANCED_OPTIMIZATIONS)
    let settings = newSettings(staticDir = getCurrentDir())
    routes:
        get "/": redirect "main.html"
    openDefaultBrowser "http://localhost:5000"
    runForever()
