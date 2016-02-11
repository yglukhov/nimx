import nake
export nake

import tables, osproc, strutils
import jester, asyncdispatch, browsers, closure_compiler # Stuff needed for JS target
import plists

var
    appName* = "MyGame"
    bundleId* = "com.mycompany.MyGame"
    javaPackageId* = "com.mycompany.MyGame"

    disableClosureCompiler* = false

    androidSdk* = "~/Library/Android/sdk"
    androidNdk* = "~/Library/Android/sdk/ndk-bundle"
    sdlRoot* = "~/Projects/SDL"

    # This should point to the Nim include dir, where nimbase.h resides.
    # Needed for android only
    nimIncludeDir* = "~/Projects/nim/lib"

    macOSSDKVersion* = "10.11"
    macOSMinVersion* = "10.6"

    iOSSDKVersion* = "9.1"
    iOSMinVersion* = iOSSDKVersion

    # Simulator device identifier should be set to run the simulator.
    # Available simulators can be listed with the command:
    # $ xcrun simctl list
    iOSSimulatorDeviceId* = "18BE8493-7EFB-4570-BF2B-5F5ACBCCB82B"

    preprocessResources* : proc(originalPath, preprocessedPath: string)
    beforeBuild*: proc(platform: string)
    afterBuild*: proc(platform: string)

    nimVerbosity* = 0
    nimParallelBuild* = 1
    debugMode* = true

    additionalNimFlags*: seq[string] = @[]
    additionalLinkerFlags*: seq[string] = @[]
    additionalCompilerFlags*: seq[string] = @[]

    runAfterBuild* = true
    targetArchitectures* = @["armeabi", "armeabi-v7a", "x86"]

# Build env vars
var
    buildRoot = "build"
    executablePath : string
    nimcachePath : string
    resourcePath : string
    nimFlags : seq[string]
    compilerFlags: seq[string]
    linkerFlags: seq[string]

when defined(windows):
    androidSdk = "D:\\Android\\android-sdk"
    androidNdk = "D:\\Android\\android-ndk-r10e"
    sdlRoot = "D:\\Android\\SDL2-2.0.3"
    nimIncludeDir = "C:\\Nim\\lib"

let bundleName = appName & ".app"
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

proc preprocessResourcesAux(toPath: string) =
    if preprocessResources.isNil:
        copyDir("res", toPath)
    else:
        createDir(toPath)
        preprocessResources("res", toPath)

proc infoPlistSetValueForKey(path, value, key: string) =
    direShell "defaults", "write", path, key, value

proc absPath(path: string): string =
    if path.isAbsolute(): path else: getCurrentDir() / path

proc makeIosBundle() =
    removeDir bundleName
    createDir bundleName
    let infoPlistPath = absPath(bundleName / "Info")
    infoPlistSetValueForKey(infoPlistPath, appName, "CFBundleName")
    infoPlistSetValueForKey(infoPlistPath, bundleId, "CFBundleIdentifier")

proc makeMacOsBundle() =
    let bundlePath = buildRoot / bundleName
    createDir(bundlePath / "Contents")

    let plist = newJObject()
    plist["CFBundleName"] = %appName
    plist["CFBundleIdentifier"] = %bundleId
    plist["CFBundleExecutable"] = %appName
    plist.writePlist(bundlePath / "Contents" / "Info.plist")

proc trySymLink(src, dest: string) =
    try:
        createSymlink(expandTilde(src), dest)
    except:
        echo "ERROR: Could not create symlink from ", src, " to ", dest
        discard

proc runAppInSimulator() =
    var waitForDebugger = "--wait-for-debugger"
    waitForDebugger = ""
    direShell "open", "-b", "com.apple.iphonesimulator"
    shell "xcrun", "simctl", "uninstall", iOSSimulatorDeviceId, bundleId
    direShell "xcrun", "simctl", "install", iOSSimulatorDeviceId, buildRoot / bundleName
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
    result = xcodeProjDir/"build/Release-" & entity
    if not fileExists result/"libSDL2.a":
        direShell "xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-configuration", "Release", "-sdk", entity&iOSSDKVersion, "SYMROOT=build", "ARCHS=\"i386 x86_64\""

proc makeAndroidBuildDir(): string =
    let buildDir = buildRoot / javaPackageId
    if not dirExists buildDir:
        var (nimbleNimxDir, errC) = execCmdEx("nimble path nimx")
        nimbleNimxDir = nimbleNimxDir.strip()
        doAssert(errC == 0, "Error: nimx does not seem to be installed with nimble!")
        createDir(buildDir)
        let templateDir = nimbleNimxDir / "test" / "android" / "template"
        echo "Using Android app template: ", templateDir
        copyDir templateDir, buildDir

        when defined(windows):
            copyDir sdlRoot/"src", buildDir/"jni"/"SDL"/"src"
            copyDir sdlRoot/"include", buildDir/"jni"/"SDL"/"include"
        else:
            trySymLink(sdlRoot/"src", buildDir/"jni"/"SDL"/"src")
            trySymLink(sdlRoot/"include", buildDir/"jni"/"SDL"/"include")

        let mainActivityPath = javaPackageId.replace(".", "/")
        createDir(buildDir/"src"/mainActivityPath)
        let mainActivityJava = """
        package """ & javaPackageId & """;
        import org.libsdl.app.SDLActivity;
        public class MainActivity extends SDLActivity {}
        """
        writeFile(buildDir/"src"/mainActivityPath/"MainActivity.java", mainActivityJava)

        var linkerFlags = ""
        for f in additionalLinkerFlags: linkerFlags &= " " & f

        let vars = {
            "PACKAGE_ID" : javaPackageId,
            "APP_NAME" : appName,
            "ADDITIONAL_LINKER_FLAGS": linkerFlags,
            "TARGET_ARCHITECTURES": targetArchitectures.join(" ")
            }.toTable()

        replaceVarsInFile buildDir/"AndroidManifest.xml", vars
        replaceVarsInFile buildDir/"res/values/strings.xml", vars
        replaceVarsInFile buildDir/"jni/src/Android.mk", vars
        replaceVarsInFile buildDir/"jni/Application.mk", vars
    buildDir

proc performBuildForPlatform(platform: string) =
    buildRoot = buildRoot / platform
    nimcachePath = buildRoot / "nimcache"
    executablePath = buildRoot / appName
    resourcePath = buildRoot / "res"

    if not beforeBuild.isNil: beforeBuild(platform)

    nimFlags = @[]
    linkerFlags = @[]
    compilerFlags = @[]

    template addCAndLFlags(f: openarray[string]) =
        linkerFlags.add(f)
        compilerFlags.add(f)

    if platform == "macosx":
        makeMacOsBundle()
        executablePath = buildRoot / bundleName / "Contents" / "MacOS" / appName
        resourcePath = buildRoot / bundleName / "Contents" / "Resources"
        addCAndLFlags(["-isysroot", macOSSDK, "-mmacosx-version-min=" & macOSMinVersion])
        linkerFlags.add(["-fobjc-link-runtime", "-L" & buildSDLForDesktop()])
        nimFlags.add("-d:SDL_Static")

    elif platform == "ios" or platform == "ios-sim":
        makeIosBundle()
        executablePath = buildRoot / bundleName / appName
        resourcePath = buildRoot / bundleName

        nimFlags.add(["--os:macosx", "-d:ios", "-d:iPhone", "-d:SDL_Static"])

        var sdkPath : string
        var sdlLibDir : string
        if platform == "ios":
            sdkPath = iOSSDK
            sdlLibDir = buildSDLForIOS(false)
            nimFlags.add("--cpu:arm")
            addCAndLFlags(["-mios-version-min=" & iOSMinVersion])
        else:
            sdkPath = iOSSimulatorSDK
            sdlLibDir = buildSDLForIOS(true)
            nimFlags.add("--cpu:amd64")
            nimFlags.add("-d:simulator")
            addCAndLFlags(["-mios-simulator-version-min=" & iOSMinVersion])

        linkerFlags.add(["-fobjc-link-runtime", "-L" & sdlLibDir])
        addCAndLFlags(["-isysroot", sdkPath])

    elif platform == "android":
        let buildDir = makeAndroidBuildDir()
        nimcachePath = buildDir / "jni/src"
        resourcePath = buildDir / "assets"
        nimFlags.add(["--compileOnly", "--cpu:arm", "--os:linux", "-d:android", "-d:SDL_Static"])

    elif platform == "js":
        executablePath = buildRoot / "main.js"
    elif platform == "linux":
        linkerFlags.add(["-L/usr/local/lib", "-Wl,-rpath,/usr/local/lib", "-lpthread"])
    elif platform == "windows":
        executablePath &= ".exe"

    if platform != "js":
        linkerFlags.add("-lSDL2")
        nimFlags.add("--threads:on")

    if runAfterBuild and platform != "android" and platform != "ios" and
            platform != "ios-sim" and platform != "js":
        nimFlags.add("--run")

    nimFlags.add(["--warning[LockLevel]:off", "--verbosity:" & $nimVerbosity,
                "--parallelBuild:" & $nimParallelBuild, "--out:" & executablePath,
                "--nimcache:" & nimcachePath])

    if platform != "windows":
        nimFlags.add("--noMain")

    if debugMode:
        nimFlags.add(["-d:debug"])
        if platform != "js":
            nimFlags.add(["--stackTrace:on", "--lineTrace:on"])
    else:
        nimFlags.add(["-d:release", "--opt:speed"])

    when defined(windows):
        nimFlags.add("-d:buildOnWindows") # Workaround for JS getEnv in nimx

    nimFlags.add(additionalNimFlags)

    for f in linkerFlags: nimFlags.add("--passL:" & f)
    for f in additionalLinkerFlags: nimFlags.add("--passL:" & f)

    for f in compilerFlags: nimFlags.add("--passC:" & f)
    for f in additionalCompilerFlags: nimFlags.add("--passC:" & f)

    preprocessResourcesAux(resourcePath)

    createDir(parentDir(executablePath))

    let command = if platform == "js": "js" else: "c"

    # Run Nim
    var args = @[nimExe, command]
    args.add(nimFlags)
    args.add "main"
    direShell args

    if not afterBuild.isNil: afterBuild(platform)


task defaultTask, "Build and run":
    when defined(macosx):
        performBuildForPlatform("macosx")
    elif defined(windows):
        performBuildForPlatform("windows")
    else:
        performBuildForPlatform("linux")

task "build", "Build and don't run":
    runAfterBuild = false
    runTask defaultTask

task "ios-sim", "Build and run in iOS simulator":
    performBuildForPlatform("ios-sim")
    if runAfterBuild: runAppInSimulator()

task "ios", "Build for iOS":
    performBuildForPlatform("ios")

task "droid", "Build for android and install on the connected device":
    performBuildForPlatform("android")

    withDir(buildRoot / javaPackageId):
        putEnv "NIM_INCLUDE_DIR", expandTilde(nimIncludeDir)
        direShell androidSdk/"tools/android", "update", "project", "-p", ".", "-t", "android-22" # try with android-16
        direShell androidNdk/"ndk-build"
        #putEnv "ANDROID_SERIAL", "12345" # Target specific device
        direShell "ant", "debug", "install"

task "js", "Create Javascript version and run in browser.":
    performBuildForPlatform("js")

    if not disableClosureCompiler:
        closure_compiler.compileFileAndRewrite(buildRoot / "main.js", ADVANCED_OPTIMIZATIONS)
    copyFile("main.html", buildRoot / "main.html")
    if runAfterBuild:
        let settings = newSettings(staticDir = buildRoot)
        routes:
            get "/": redirect "main.html"
        when not defined(windows):
            openDefaultBrowser "http://localhost:5000"
        runForever()

task "build-js", "Create Javascript version.":
    runAfterBuild = false
    runTask "js"
