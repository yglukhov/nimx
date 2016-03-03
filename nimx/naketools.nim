import nake
export nake

import tables, osproc, strutils, times, parseopt2, streams
import jester, asyncdispatch, browsers, closure_compiler # Stuff needed for JS target
import plists

type Builder* = ref object
    platform*: string

    appName* : string
    bundleId* : string
    javaPackageId* : string
    disableClosureCompiler* : bool

    androidSdk* : string
    androidNdk* : string
    sdlRoot* : string

    nimIncludeDir* : string

    macOSSDKVersion* : string
    macOSMinVersion* : string

    iOSSDKVersion* : string
    iOSMinVersion* : string

    appIconName : string

    # Simulator device identifier should be set to run the simulator.
    # Available simulators can be listed with the command:
    # $ xcrun simctl list
    iOSSimulatorDeviceId* : string

    nimVerbosity* : int
    nimParallelBuild* : int
    debugMode* : bool

    additionalNimFlags*: seq[string]
    additionalLinkerFlags*: seq[string]
    additionalCompilerFlags*: seq[string]

    runAfterBuild* : bool
    targetArchitectures* : seq[string]
    androidPermissions*: seq[string]
    screenOrientation*: string

    mainFile*: string

    bundleName : string

    buildRoot : string
    executablePath : string
    nimcachePath : string
    resourcePath* : string
    originalResourcePath*: string
    nimFlags: seq[string]
    compilerFlags: seq[string]
    linkerFlags: seq[string]

proc newBuilder(platform: string): Builder =
    result.new()
    let b = result

    b.platform = platform

    b.appName = "MyGame"
    b.bundleId = "com.mycompany.MyGame"
    b.javaPackageId = "com.mycompany.MyGame"

    b.disableClosureCompiler = false

    when defined(windows):
        b.androidSdk = "D:\\Android\\android-sdk"
        b.androidNdk = "D:\\Android\\android-ndk-r10e"
        b.sdlRoot = "D:\\Android\\SDL2-2.0.3"
        b.nimIncludeDir = "C:\\Nim\\lib"
        b.appIconName = "MyGame.ico"
    else:
        b.androidSdk = "~/Library/Android/sdk"
        b.androidNdk = "~/Library/Android/sdk/ndk-bundle"
        b.sdlRoot = "~/Projects/SDL"
        b.nimIncludeDir = "~/Projects/nim/lib"

    b.macOSSDKVersion = "10.11"
    b.macOSMinVersion = "10.6"

    b.iOSSDKVersion = "9.1"
    b.iOSMinVersion = b.iOSSDKVersion

    # Simulator device identifier should be set to run the simulator.
    # Available simulators can be listed with the command:
    # $ xcrun simctl list
    b.iOSSimulatorDeviceId = "18BE8493-7EFB-4570-BF2B-5F5ACBCCB82B"

    b.nimVerbosity = 0
    b.nimParallelBuild = 0
    b.debugMode = true

    b.additionalNimFlags = @[]
    b.additionalLinkerFlags = @[]
    b.additionalCompilerFlags = @[]

    b.mainFile = "main"

    b.runAfterBuild = true
    b.targetArchitectures = @["armeabi", "armeabi-v7a", "x86"]
    b.androidPermissions = @[]

    b.buildRoot = "build"
    b.originalResourcePath = "res"

proc nimblePath(package: string): string =
    var nimblecmd = "nimble"
    when defined(windows):
        nimblecmd &= ".cmd"
    var (nimbleNimxDir, err) = execCmdEx(nimblecmd & " path " & package)
    if err == 0:
        let lines = nimbleNimxDir.splitLines()
        if lines.len > 1:
            result = lines[^2]

proc newBuilderForCurrentPlatform(): Builder =
    when defined(macosx):
        newBuilder("macosx")
    elif defined(windows):
        newBuilder("windows")
    else:
        newBuilder("linux")

proc newBuilder*(): Builder =
    result = newBuilderForCurrentPlatform()
    for kind, key, val in getopt():
        case kind
        of cmdLongOption, cmdShortOption:
            case key
            of "define", "d":
                if val in ["js", "android", "ios", "ios-sim"]:
                    result.platform = val
                if val == "release":
                    result.debugMode = false
            of "norun":
                result.runAfterBuild = false
            of "parallelBuild":
                result.nimParallelBuild = parseInt(val)
            else: discard
        else: discard

var
    preprocessResources* : proc(b: Builder)
    beforeBuild*: proc(b: Builder)
    afterBuild*: proc(b: Builder)

when defined(Windows):
    const silenceStdout = "2>nul"
else:
    const silenceStdout = ">/dev/null"

if dirExists("../.git"): # Install nimx
    withDir "..":
        direShell "nimble", "-y", "install", silenceStdout

proc copyResourceAsIs*(b: Builder, path: string) =
    let destPath = b.resourcePath / path
    let fromPath = b.originalResourcePath / path
    if not fileExists(destPath) or fileNewer(fromPath, destPath):
        echo "Copying resource: ", path
        createDir(parentDir(destPath))
        copyFile(fromPath, destPath)

proc convertResource*(b: Builder, origPath, destExtension: string, conv : proc(fromPath, toPath: string)) =
    let op = b.originalResourcePath / origPath
    let sp = origPath.splitFile()
    let dp = b.resourcePath / sp.dir / sp.name & "." & destExtension
    if not fileExists(dp) or fileNewer(op, dp):
        echo "Converting resource: ", op
        createDir(parentDir(dp))
        conv(op, dp)

proc forEachResource*(b: Builder, p: proc(path: string)) =
    for i in walkDirRec(b.originalResourcePath):
        p(i.substr(b.originalResourcePath.len + 1))

proc copyResources*(b: Builder) =
    copyDir(b.originalResourcePath, b.resourcePath)

proc preprocessResourcesAux(b: Builder) =
    if preprocessResources.isNil:
        b.copyResources()
    else:
        createDir(b.resourcePath)
        preprocessResources(b)

proc infoPlistSetValueForKey(path, value, key: string) =
    direShell "defaults", "write", path, key, value

proc absPath(path: string): string =
    if path.isAbsolute(): path else: getCurrentDir() / path

proc makeIosBundle(b: Builder) =
    let bundlePath = b.buildRoot / b.bundleName
    removeDir bundlePath
    createDir bundlePath
    let infoPlistPath = absPath(bundlePath / "Info")
    infoPlistSetValueForKey(infoPlistPath, b.appName, "CFBundleName")
    infoPlistSetValueForKey(infoPlistPath, b.bundleId, "CFBundleIdentifier")

proc makeMacOsBundle(b: Builder) =
    let bundlePath = b.buildRoot / b.bundleName
    createDir(bundlePath / "Contents")

    let plist = newJObject()
    plist["CFBundleName"] = %b.appName
    plist["CFBundleIdentifier"] = %b.bundleId
    plist["CFBundleExecutable"] = %b.appName
    plist["NSHighResolutionCapable"] = %true
    plist.writePlist(bundlePath / "Contents" / "Info.plist")

proc makeWindowsResource(b: Builder) =
    let
        rcPath = b.buildRoot / "res" / (b.appName & ".rc")
        rcO = b.nimcachePath / (b.appName & "_res.o")
    var createResource: bool = false

    shell "type", "nul", ">", rcPath

    if not isNil(b.appIconName):
        let appIconPath = b.resourcePath / (b.appIconName)

        if fileExists(absPath(appIconPath)):
            shell "echo", "AppIcon ICON \"$#\"" % [b.appIconName], ">>", rcPath
            shell "windres", "-i", rcPath, "-o", rcO
            createResource = true
        else:
            echo "Warning: icon was not found: $#" % [appIconPath]
    else:
        echo "Info: you can set your application icon by setting `builder.appIconName` property."

    if createResource:
        b.additionalLinkerFlags.add(absPath(rcO))

proc trySymLink(src, dest: string) =
    try:
        createSymlink(expandTilde(src), dest)
    except:
        echo "ERROR: Could not create symlink from ", src, " to ", dest
        discard

proc runAppInSimulator(b: Builder) =
    var waitForDebugger = "--wait-for-debugger"
    waitForDebugger = ""
    direShell "open", "-b", "com.apple.iphonesimulator"
    shell "xcrun", "simctl", "uninstall", b.iOSSimulatorDeviceId, b.bundleId
    direShell "xcrun", "simctl", "install", b.iOSSimulatorDeviceId, b.buildRoot / b.bundleName
    direShell "xcrun", "simctl", "launch", waitForDebugger, b.iOSSimulatorDeviceId, b.bundleId

proc replaceVarsInFile(file: string, vars: Table[string, string]) =
    var content = readFile(file)
    for k, v in vars:
        content = content.replace("$(" & k & ")", v)
    writeFile(file, content)

proc buildSDLForDesktop(b: Builder): string =
    when defined(linux):
        result = "/usr/lib"
    elif defined(macosx):
        if fileExists("/usr/local/lib/libSDL2.a") or fileExists("/usr/local/lib/libSDL2.dylib"):
            result = "/usr/local/lib"
        else:
            let xcodeProjDir = expandTilde(b.sdlRoot)/"Xcode/SDL"
            let libDir = xcodeProjDir/"build/Release"
            if not fileExists libDir/"libSDL2.a":
                direShell "xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-target", "Static\\ Library", "-configuration", "Release", "-sdk", "macosx"&b.macOSSDKVersion, "SYMROOT=build"
            result = libDir
    else:
        assert(false, "Don't know where to find SDL")

proc buildSDLForIOS(b: Builder, forSimulator: bool = false): string =
    let entity = if forSimulator: "iphonesimulator" else: "iphoneos"
    let xcodeProjDir = expandTilde(b.sdlRoot)/"Xcode-iOS/SDL"
    result = xcodeProjDir/"build/Release-" & entity
    if not fileExists result/"libSDL2.a":
        direShell "xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-configuration", "Release", "-sdk", entity&b.iOSSDKVersion, "SYMROOT=build", "ARCHS=\"i386 x86_64\""

proc makeAndroidBuildDir(b: Builder): string =
    let buildDir = b.buildRoot / b.javaPackageId
    if not dirExists buildDir:
        let nimbleNimxDir = nimblePath("nimx")
        doAssert(not nimbleNimxDir.isNil, "Error: nimx does not seem to be installed with nimble!")
        createDir(buildDir)
        let templateDir = nimbleNimxDir / "test" / "android" / "template"
        echo "Using Android app template: ", templateDir
        copyDir templateDir, buildDir

        when defined(windows):
            copyDir b.sdlRoot/"src", buildDir/"jni"/"SDL"/"src"
            copyDir b.sdlRoot/"include", buildDir/"jni"/"SDL"/"include"
        else:
            trySymLink(b.sdlRoot/"src", buildDir/"jni"/"SDL"/"src")
            trySymLink(b.sdlRoot/"include", buildDir/"jni"/"SDL"/"include")

        let mainActivityPath = b.javaPackageId.replace(".", "/")
        createDir(buildDir/"src"/mainActivityPath)
        let mainActivityJava = """
        package """ & b.javaPackageId & """;
        import org.libsdl.app.SDLActivity;
        public class MainActivity extends SDLActivity {}
        """
        writeFile(buildDir/"src"/mainActivityPath/"MainActivity.java", mainActivityJava)

        var linkerFlags = ""
        for f in b.additionalLinkerFlags: linkerFlags &= " " & f
        var compilerFlags = ""
        for f in b.additionalCompilerFlags: compilerFlags &= " " & f
        var permissions = ""
        for p in b.androidPermissions: permissions &= "<uses-permission android:name=\"android.permission." & p & "\"/>\L"
        var debuggable = ""
        if b.debugMode:
            debuggable = "android:debuggable=\"true\""

        var screenOrientation = ""
        if not b.screenOrientation.isNil:
            screenOrientation = "android:screenOrientation=\"" & b.screenOrientation & "\""

        let vars = {
            "PACKAGE_ID" : b.javaPackageId,
            "APP_NAME" : b.appName,
            "ADDITIONAL_LINKER_FLAGS": linkerFlags,
            "ADDITIONAL_COMPILER_FLAGS": compilerFlags,
            "TARGET_ARCHITECTURES": b.targetArchitectures.join(" "),
            "ANDROID_PERMISSIONS": permissions,
            "ANDROID_DEBUGGABLE": debuggable,
            "SCREEN_ORIENTATION": screenOrientation
            }.toTable()

        replaceVarsInFile buildDir/"AndroidManifest.xml", vars
        replaceVarsInFile buildDir/"res/values/strings.xml", vars
        replaceVarsInFile buildDir/"jni/src/Android.mk", vars
        replaceVarsInFile buildDir/"jni/Application.mk", vars
    buildDir

proc jsPostBuild(b: Builder) =
    if not b.disableClosureCompiler:
        closure_compiler.compileFileAndRewrite(b.buildRoot / "main.js", ADVANCED_OPTIMIZATIONS)

    let sf = splitFile(b.mainFile)
    copyFile(sf.dir / sf.name & ".html", b.buildRoot / "main.html")
    if b.runAfterBuild:
        let settings = newSettings(staticDir = b.buildRoot)
        routes:
            get "/": redirect "main.html"
        when not defined(windows):
            openDefaultBrowser "http://localhost:5000"
        runForever()

proc build*(b: Builder) =
    b.buildRoot = b.buildRoot / b.platform
    b.nimcachePath = b.buildRoot / "nimcache"
    b.resourcePath = b.buildRoot / "res"

    if not beforeBuild.isNil: beforeBuild(b)

    b.executablePath = b.buildRoot / b.appName
    b.bundleName = b.appName & ".app"

    b.nimFlags = @[]
    b.linkerFlags = @[]
    b.compilerFlags = @[]

    template addCAndLFlags(f: openarray[string]) =
        b.linkerFlags.add(f)
        b.compilerFlags.add(f)

    let xCodeApp = "/Applications/Xcode.app"

    let macOSSDK = xCodeApp/"Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX" & b.macOSSDKVersion & ".sdk"
    let iOSSDK = xCodeApp/"Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS" & b.iOSSDKVersion & ".sdk"
    let iOSSimulatorSDK = xCodeApp/"Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator" & b.iOSSDKVersion & ".sdk"

    case b.platform
    of "macosx":
        b.makeMacOsBundle()
        b.executablePath = b.buildRoot / b.bundleName / "Contents" / "MacOS" / b.appName
        b.resourcePath = b.buildRoot / b.bundleName / "Contents" / "Resources"
        addCAndLFlags(["-isysroot", macOSSDK, "-mmacosx-version-min=" & b.macOSMinVersion])
        b.linkerFlags.add(["-fobjc-link-runtime", "-L" & b.buildSDLForDesktop()])
        b.nimFlags.add("-d:SDL_Static")

    of "ios", "ios-sim":
        b.makeIosBundle()
        b.executablePath = b.buildRoot / b.bundleName / b.appName
        b.resourcePath = b.buildRoot / b.bundleName

        b.nimFlags.add(["--os:macosx", "-d:ios", "-d:iPhone", "-d:SDL_Static"])

        var sdkPath : string
        var sdlLibDir : string
        if b.platform == "ios":
            sdkPath = iOSSDK
            sdlLibDir = b.buildSDLForIOS(false)
            b.nimFlags.add("--cpu:arm")
            addCAndLFlags(["-mios-version-min=" & b.iOSMinVersion])
        else:
            sdkPath = iOSSimulatorSDK
            sdlLibDir = b.buildSDLForIOS(true)
            b.nimFlags.add("--cpu:amd64")
            b.nimFlags.add("-d:simulator")
            addCAndLFlags(["-mios-simulator-version-min=" & b.iOSMinVersion])

        b.linkerFlags.add(["-fobjc-link-runtime", "-L" & sdlLibDir])
        addCAndLFlags(["-isysroot", sdkPath])

    of "android":
        let buildDir = b.makeAndroidBuildDir()
        b.nimcachePath = buildDir / "jni/src"
        b.resourcePath = buildDir / "assets"
        b.nimFlags.add(["--compileOnly", "--cpu:arm", "--os:linux", "-d:android", "-d:SDL_Static"])

    of "js":
        b.executablePath = b.buildRoot / "main.js"
    of "linux":
        b.linkerFlags.add(["-L/usr/local/lib", "-Wl,-rpath,/usr/local/lib", "-lpthread"])
    of "windows":
        b.executablePath &= ".exe"
        b.makeWindowsResource()
    else: discard

    if b.platform != "js":
        b.nimFlags.add("--threads:on")
        if b.platform != "windows":
            b.linkerFlags.add("-lSDL2")

    if b.runAfterBuild and b.platform != "android" and b.platform != "ios" and
            b.platform != "ios-sim" and b.platform != "js":
        b.nimFlags.add("--run")

    b.nimFlags.add(["--warning[LockLevel]:off", "--verbosity:" & $b.nimVerbosity,
                "--parallelBuild:" & $b.nimParallelBuild, "--out:" & b.executablePath,
                "--nimcache:" & b.nimcachePath])

    if b.platform != "windows":
        b.nimFlags.add("--noMain")

    if b.debugMode:
        b.nimFlags.add(["-d:debug"])
        if b.platform != "js":
            b.nimFlags.add(["--stackTrace:on", "--lineTrace:on"])
    else:
        b.nimFlags.add(["-d:release", "--opt:speed"])

    when defined(windows):
        b.nimFlags.add("-d:buildOnWindows") # Workaround for JS getEnv in nimx

    b.nimFlags.add(b.additionalNimFlags)

    for f in b.linkerFlags: b.nimFlags.add("--passL:" & f)
    for f in b.additionalLinkerFlags: b.nimFlags.add("--passL:" & f)

    for f in b.compilerFlags: b.nimFlags.add("--passC:" & f)
    for f in b.additionalCompilerFlags: b.nimFlags.add("--passC:" & f)

    preprocessResourcesAux(b)

    createDir(parentDir(b.executablePath))

    let command = if b.platform == "js": "js" else: "c"

    b.nimFlags.add("--putEnv:NIMX_RES_PATH=" & b.resourcePath)
    # Run Nim
    var args = @[nimExe, command]
    args.add(b.nimFlags)
    args.add b.mainFile
    direShell args

    if b.platform == "js":
        b.jsPostBuild()

    if not afterBuild.isNil: afterBuild(b)

proc runAutotestsInFirefox*(pathToMainHTML: string) =
    let ffbin = when defined(macosx):
            "/Applications/Firefox.app/Contents/MacOS/firefox"
        else:
            findExe("firefox")
    createDir("tempprofile")
    writeFile("tempprofile/user.js", """
    pref("browser.shell.checkDefaultBrowser", false);
    pref("browser.dom.window.dump.enabled", true);""")
    let ffp = startProcess(ffbin, args = ["-profile", "./tempprofile", pathToMainHTML])
    let so = ffp.outputStream
    var line = ""
    var ok = true
    while so.readLine(line):
        if line == "---AUTO-TEST-QUIT---":
            break
        elif line == "---AUTO-TEST-FAIL---":
            ok = false
        else:
            echo line
    ffp.kill()
    removeDir("tempprofile")
    doAssert(ok, "Firefox autotest failed")

proc runAutotestsInFirefox*(b: Builder) =
    runAutotestsInFirefox(b.buildRoot / "main.html")

task defaultTask, "Build and run":
    newBuilder().build()

task "build", "Build and don't run":
    let b = newBuilderForCurrentPlatform()
    b.runAfterBuild = false
    b.build()

task "ios-sim", "Build and run in iOS simulator":
    let b = newBuilder("ios-sim")
    b.build()
    if b.runAfterBuild: b.runAppInSimulator()

task "ios", "Build for iOS":
    newBuilder("ios").build()

task "droid", "Build for android and install on the connected device":
    let b = newBuilder("android")
    b.build()

    withDir(b.buildRoot / b.javaPackageId):
        putEnv "NIM_INCLUDE_DIR", expandTilde(b.nimIncludeDir)
        direShell b.androidSdk/"tools/android", "update", "project", "-p", ".", "-t", "android-22" # try with android-16

        var args = @[b.androidNdk/"ndk-build", "V=1"]
        if b.debugMode:
            args.add(["NDK_DEBUG=1", "APP_OPTIM=debug"])
        else:
            args.add("APP_OPTIM=release")
        direShell args
        #putEnv "ANDROID_SERIAL", "12345" # Target specific device
        direShell "ant", "debug", "install"

task "js", "Create Javascript version and run in browser.":
    newBuilder("js").build()
