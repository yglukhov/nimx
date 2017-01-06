import nake
export nake

import tables, osproc, strutils, times, parseopt2, streams, os, pegs
import jester, asyncdispatch, browsers, closure_compiler # Stuff needed for JS target
import plists

type Builder* = ref object
    platform*: string

    appName* : string
    appVersion*: string
    buildNumber*: int
    bundleId* : string
    javaPackageId* : string
    disableClosureCompiler* : bool
    enableClosureCompilerSourceMap*: bool

    androidSdk* : string
    androidNdk* : string
    androidApi* : int
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
    additionalLibsToCopy*: seq[string]

    runAfterBuild* : bool
    targetArchitectures* : seq[string]
    androidPermissions*: seq[string]
    screenOrientation*: string
    androidStaticLibraries*: seq[string]
    additionalAndroidResources*: seq[string]
    activityClassName*: string

    mainFile*: string

    bundleName : string

    codesignIdentity*: string
    teamId*: string
    emscriptenPreloadFiles*: seq[string]
    emscriptenPreJS*: seq[string]

    buildRoot : string
    executablePath : string
    nimcachePath : string
    resourcePath* : string
    originalResourcePath*: string
    nimFlags: seq[string]
    compilerFlags: seq[string]
    linkerFlags: seq[string]

    avoidSDL*: bool # Experimental feature.

proc setBuilderSettingsFromCmdLine(b: Builder) =
    for kind, key, val in getopt():
        case kind
        of cmdLongOption, cmdShortOption:
            case key
            of "define", "d":
                if val in ["js", "android", "ios", "ios-sim", "emscripten", "windows"]:
                    b.platform = val
                elif val == "release":
                    b.debugMode = false
                else:
                    b.additionalNimFlags.add("-d:" & val)
            of "norun":
                b.runAfterBuild = false
            of "parallelBuild":
                b.nimParallelBuild = parseInt(val)
            else: discard
        else: discard

proc replaceInStr(in_str, wh_str : string, by_str: string = ""): string =
    result = in_str
    if in_str.len > 0:
        var pos = in_str.rfind(wh_str)
        result.delete(pos, result.len)
        if by_str.len > 0:
            result &= by_str

proc getEnvErrorMsg(env: string): string =
    result = "\n Environment variable [ " & env & " ] is not set."

const xCodeApp = "/Applications/Xcode.app"

proc macOSSDKPath*(version: string): string =
    result = xCodeApp/"Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX" & version & ".sdk"
proc iOSSDKPath*(version: string): string =
    result = xCodeApp/"Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS" & version & ".sdk"
proc iOSSimulatorSDKPath*(version: string): string =
    result = xCodeApp/"Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator" & version & ".sdk"

proc getiOSSDKVersion(): string =
    for f in walkDir(xCodeApp/"Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/"):
        var dirName = splitFile(f.path).name
        var matches = dirName.findAll(peg"\d+\.\d+")
        if matches.len() > 0:
            return matches[matches.len() - 1]

proc findEnvPaths(b: Builder) =
    if b.platform in ["android", "ios", "ios-sim"]:
        var error_msg = ""
        ## try find binary for android sdk, ndk, and nim
        if b.platform == "android":
            var ndk_path = findExe("ndk-stack")
            var sdk_path = findExe("adb")
            var nim_path = findExe("nim")

            if ndk_path.len > 0:
                ndk_path = replaceInStr(ndk_path, "ndk-stack")
            elif existsEnv("NDK_HOME") or existsEnv("NDK_ROOT"):
                if existsEnv("NDK_HOME"):
                    ndk_path = getEnv("NDK_HOME")
                else:
                    ndk_path = getEnv("NDK_ROOT")

            if sdk_path.len > 0:
                sdk_path = replaceInStr(sdk_path, "platform")
            elif existsEnv("ANDROID_HOME") or existsEnv("ANDROID_SDK_HOME"):
                if existsEnv("ANDROID_HOME"):
                    sdk_path = getEnv("ANDROID_HOME")
                else:
                    sdk_path = getEnv("ANDROID_SDK_HOME")

            if nim_path.len > 0:
                if symlinkExists(nim_path):
                    nim_path = expandSymlink(nim_path)
                nim_path = replaceInStr(nim_path, "bin", "/lib")
            elif existsEnv("NIM_HOME"):
                nim_path = getEnv("NIM_HOME")

            when not defined(windows):
                if ndk_path.len == 0:
                    ndk_path = "~/Library/Android/sdk/ndk-bundle"
                    if not fileExists(expandTilde(ndk_path / "ndk-stack")):
                        echo "NDK DOESNT EXIST"
                        ndk_path = nil
                if sdk_path.len == 0:
                    sdk_path = "~/Library/Android/sdk"
                    if not fileExists(expandTilde(sdk_path / "platform-tools/adb")):
                        sdk_path = nil

            if sdk_path.len == 0: error_msg &= getEnvErrorMsg("ANDROID_HOME")
            if ndk_path.len == 0: error_msg &= getEnvErrorMsg("NDK_HOME")
            if nim_path.len == 0: error_msg &= getEnvErrorMsg("NIM_HOME")

            b.androidSdk = sdk_path
            b.androidNdk = ndk_path
            b.nimIncludeDir = nim_path

        var sdlHome : string
        if existsEnv("SDL_HOME"):
            sdlHome = getEnv("SDL_HOME")
        if sdlHome.len == 0: error_msg &= getEnvErrorMsg("SDL_HOME")

        if error_msg.len > 0:
            raiseOSError(error_msg)

        b.sdlRoot = sdlHome

proc versionCodeWithTime*(t: TimeInfo): int =
    let month = (t.year - 2016) * 12 + (t.month.int + 1)
    result = t.minute + t.hour * 100 + t.monthday * 10000 + month * 1000000

proc versionCodeWithTime*(t: Time): int =
    versionCodeWithTime(getLocalTime(t))

proc versionCodeWithTime*(): int =
    versionCodeWithTime(getTime())

proc newBuilder*(platform: string): Builder =
    result.new()
    let b = result

    b.platform = platform
    b.appName = "NimxApp"
    b.appVersion = "1.0"
    b.buildNumber = versionCodeWithTime()
    b.bundleId = "com.mycompany.NimxApp"
    b.javaPackageId = "com.mycompany.NimxApp"
    b.activityClassName = "io.github.yglukhov.nimx.NimxActivity"
    b.disableClosureCompiler = false

    when defined(windows):
        b.appIconName = "MyGame.ico"

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
    b.additionalLibsToCopy = @[]

    b.mainFile = "main"

    b.runAfterBuild = true
    b.targetArchitectures = @["armeabi", "armeabi-v7a", "x86"]
    b.androidPermissions = @[]
    b.androidStaticLibraries = @[]
    b.additionalAndroidResources = @[]

    b.buildRoot = "build"
    b.originalResourcePath = "res"

    b.emscriptenPreloadFiles = @[]
    b.emscriptenPreJs = @[]

    b.setBuilderSettingsFromCmdLine()
    b.findEnvPaths()

    if b.platform in ["ios", "ios-sim"]:
        b.iOSSDKVersion = getiOSSDKVersion()
        b.iOSMinVersion = b.iOSSDKVersion
    elif b.platform == "macosx":
        b.macOSSDKVersion = "10.12"
        for v in ["10.7", "10.8", "10.9", "10.10", "10.11", "10.12", "10.13"]:
            if dirExists(macOSSDKPath(v)):
                b.macOSSDKVersion = v
                break
        b.macOSMinVersion = "10.7"

proc nimblePath(package: string): string =
    var nimblecmd = "nimble"
    when defined(windows):
        nimblecmd &= ".cmd"
    var (packageDir, err) = execCmdEx(nimblecmd & " path " & package)
    if err == 0:
        let lines = packageDir.splitLines()
        if lines.len > 1:
            result = lines[^2]

proc nimbleNimxPath(): string =
    result = nimblePath("nimx")
    doAssert(not result.isNil, "Error: nimx does not seem to be installed with nimble!")

proc emccWrapperPath(): string =
    when defined(windows):
        let jsbindPath = nimblePath("jsbind")
        result = jsbindPath / "jsbind/emcc_wrapper_win32.exe"
    else:
        result = findExe("emcc")

proc findEmcc(): string {.tags: [ReadDirEffect, ReadEnvEffect, ReadIOEffect].} =
    result = addFileExt("emcc", ScriptExt)
    if existsFile(result): return
    var path = string(getEnv("PATH"))
    for candidate in split(path, PathSep):
        var x = (if candidate[0] == '"' and candidate[^1] == '"':
                  substr(candidate, 1, candidate.len-2) else: candidate) /
               result
        if existsFile(x):
            return x

proc newBuilder*(): Builder =
    when defined(macosx):
        newBuilder("macosx")
    elif defined(windows):
        newBuilder("windows")
    else:
        newBuilder("linux")

var
    preprocessResources* : proc(b: Builder)
    beforeBuild*: proc(b: Builder)
    afterBuild*: proc(b: Builder)

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

iterator allResources*(b: Builder): string =
    for i in walkDirRec(b.originalResourcePath):
        yield i.substr(b.originalResourcePath.len + 1)

proc forEachResource*(b: Builder, p: proc(path: string)) =
    for i in b.allResources: p(i)

proc copyResources*(b: Builder) =
    copyDir(b.originalResourcePath, b.resourcePath)

proc preprocessResourcesAux(b: Builder) =
    if preprocessResources.isNil:
        b.copyResources()
    else:
        createDir(b.resourcePath)
        preprocessResources(b)

proc absPath(path: string): string =
    if path.isAbsolute(): path else: getCurrentDir() / path

proc fillInfoPlist(b: Builder, plist: JsonNode) =
    plist["CFBundleName"] = %b.appName
    plist["CFBundleIdentifier"] = %b.bundleId
    plist["CFBundleExecutable"] = %b.appName
    plist["CFBundleShortVersionString"] = %b.appVersion
    plist["CFBundleVersion"] = % $b.buildNumber

proc makeIosBundle(b: Builder) =
    let loadPath = b.originalResourcePath / "Info.plist"
    var plist = loadPlist(loadPath)
    if plist.isNil:
        plist = newJObject()
    b.fillInfoPlist(plist)

    let savePath = b.buildRoot / b.bundleName
    createDir savePath
    plist.writePlist(savePath / "Info.plist")

proc makeMacOsBundle(b: Builder) =
    let bundlePath = b.buildRoot / b.bundleName
    createDir(bundlePath / "Contents")

    let plist = newJObject()
    b.fillInfoPlist(plist)
    plist["NSHighResolutionCapable"] = %true
    plist.writePlist(bundlePath / "Contents" / "Info.plist")

proc makeWindowsResource(b: Builder) =
    let
        rcPath = b.buildRoot / "res" / (b.appName & ".rc")
        rcO = b.nimcachePath / (b.appName & "_res.o")
    var createResource = false

    if not isNil(b.appIconName):
        let appIconPath = b.resourcePath / b.appIconName

        if fileExists(absPath(appIconPath)):
            writeFile(rcPath, "AppIcon ICON \"$#\"" % [b.appIconName])
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
        var args = @["xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-configuration", "Release", "-sdk", entity&b.iOSSDKVersion, "SYMROOT=build"]
        if forSimulator:
            args.add("ARCHS=\"i386 x86_64\"")
        else:
            args.add("ARCHS=\"arm64 armv7\"")
        direShell args

proc makeAndroidBuildDir(b: Builder): string =
    let buildDir = b.buildRoot / b.javaPackageId
    if not dirExists buildDir:
        let nimxTemplateDir = nimbleNimxPath() / "test" / "android" / "template"
        let sdlDefaultAndroidProjectTemplate =  b.sdlRoot/"android-project"
        createDir(buildDir)
        echo "Using Android project sdl template: ", sdlDefaultAndroidProjectTemplate
        copyDir sdlDefaultAndroidProjectTemplate, buildDir

        copyDir(nimxTemplateDir, buildDir)
        createDir(buildDir/"jni"/"SDL")

        when defined(windows):
            copyDir b.sdlRoot/"src", buildDir/"jni"/"SDL"/"src"
            copyDir b.sdlRoot/"include", buildDir/"jni"/"SDL"/"include"
        else:
            trySymLink(b.sdlRoot/"src", buildDir/"jni"/"SDL"/"src")
            trySymLink(b.sdlRoot/"include", buildDir/"jni"/"SDL"/"include")

        let sdlmk = buildDir/"jni"/"SDL"/"Android.mk"
        copyFile(b.sdlRoot/"Android.mk", sdlmk)

        # Patch SDL's Android.mk so that it doesn't build dynamic lib.
        writeFile(sdlmk, readFile(sdlmk).replace("include $(BUILD_SHARED_LIBRARY)", "#include $(BUILD_SHARED_LIBRARY)"))

        for libName in b.additionalLibsToCopy:
            let libPath = "lib"/libName
            copyDir libPath, buildDir/"jni"/libName

        for resourcePath in b.additionalAndroidResources:
            copyDir resourcePath, buildDir

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
            "APP_VERSION": b.appVersion,
            "BUILD_NUMBER": $b.buildNumber,
            "ADDITIONAL_LINKER_FLAGS": b.additionalLinkerFlags.join(" "),
            "ADDITIONAL_COMPILER_FLAGS": b.additionalCompilerFlags.join(" "),
            "TARGET_ARCHITECTURES": b.targetArchitectures.join(" "),
            "ANDROID_PERMISSIONS": permissions,
            "ANDROID_DEBUGGABLE": debuggable,
            "SCREEN_ORIENTATION": screenOrientation,
            "TARGET_API": $b.androidApi,
            "STATIC_LIBRARIES": b.androidStaticLibraries.join(" "),
            "ACTIVITY_CLASS_NAME": b.activityClassName
            }.toTable()

        replaceVarsInFile buildDir/"AndroidManifest.xml", vars
        replaceVarsInFile buildDir/"res/values/strings.xml", vars
        replaceVarsInFile buildDir/"jni/src/Android.mk", vars
        replaceVarsInFile buildDir/"jni/Application.mk", vars
        replaceVarsInFile buildDir/"project.properties", vars
        replaceVarsInFile buildDir/"build.xml", vars
    buildDir

proc packageNameAtPath(d: string): string =
    for file in walkFiles(d / "*.nimble"):
        return file.splitFile.name

proc curPackageNameAndPath(): tuple[name, path: string] =
    var d = getCurrentDir()
    while d.len > 1:
        result.name = packageNameAtPath(d)
        if not result.name.isNil:
            result.path = d
            return
        d = d.parentDir()

proc nimbleOverrideFlags(b: Builder): seq[string] =
    result = @[]
    var d = getCurrentDir()
    while d.len > 1:
        let nimbleoverride = d / "nimbleoverride"
        if fileExists(nimbleoverride):
            for ln in lines(nimbleoverride):
                let path = ln.strip()
                if path.len > 0 and path[0] != '#':
                    var absPath = path
                    if not isAbsolute(absPath): absPath = d / absPath
                    let pkgName = packageNameAtPath(absPath)
                    let origNimblePath = nimblePath(pkgName)
                    if not origNimblePath.isNil: result.add("--excludePath:" & origNimblePath)
                    result.add("--NimblePath:" & absPath)
        d = d.parentDir()

    let cp = curPackageNameAndPath()
    if not cp.name.isNil:
        let origNimblePath = nimblePath(cp.name)
        if not origNimblePath.isNil: result.add("--excludePath:" & origNimblePath)
        result.add("--NimblePath:" & cp.path)

proc jsPostBuild(b: Builder) =
    if not b.disableClosureCompiler and b.platform == "js":
        closure_compiler.compileFileAndRewrite(b.buildRoot / "main.js", ADVANCED_OPTIMIZATIONS, b.enableClosureCompilerSourceMap)

    let sf = splitFile(b.mainFile)
    var mainHTML = sf.dir / sf.name & ".html"
    if not fileExists(mainHTML):
        mainHTML = nimbleNimxPath() / "test" / "main.html"
    copyFile(mainHTML, b.buildRoot / "main.html")
    if b.runAfterBuild:
        let settings = newSettings(staticDir = b.buildRoot)
        routes:
            get "/": redirect "main.html"
        when not defined(windows):
            openDefaultBrowser "http://localhost:5000"
        runForever()

proc signIosBundle(b: Builder) =
    let e = newJObject() # Entitlements
    let entPath = b.buildRoot / "entitlements.plist"
    let appID = b.teamId & "." & b.bundleId

    e["application-identifier"] = %appID
    e["com.apple.developer.team-identifier"] = %b.teamId
    e["get-task-allow"] = %b.debugMode
    e["keychain-access-groups"] = %*[appID]

    e.writePlist(entPath)
    direShell(["codesign", "-s", "\"" & b.codesignIdentity & "\"", "--force", "--entitlements", entPath, b.buildRoot / b.bundleName])

proc ndkBuild(b: Builder) =
    withDir(b.buildRoot / b.javaPackageId):
        putEnv "NIM_INCLUDE_DIR", expandTilde(b.nimIncludeDir)
        putEnv "ANDROID_HOME", expandTilde(b.androidSdk)

        if b.androidApi == 0:
            b.androidApi = 14 #default android-api level
        # this update phase is doesnt look necessary
        #direShell b.androidSdk/"tools/android", "update", "project", "-p", ".", "-t", "android-" & $b.androidApi # try with android-16

        let verbose = false
        var args = @[b.androidNdk/"ndk-build"]
        if verbose: args.add("V=1")
        if b.nimParallelBuild > 0:
            args.add("-j " & $b.nimParallelBuild)
        if b.debugMode:
            args.add(["NDK_DEBUG=1", "APP_OPTIM=debug"])
        else:
            args.add("APP_OPTIM=release")
        direShell args

        if b.debugMode:
            direShell "ant", "debug"
        else:
            direShell "ant", "release"

proc makeEmscriptenPreloadData(b: Builder): string =
    let emcc_path = findExe("emcc")
    let emcc = if emcc_path.len > 0: emcc_path else: findEmcc()

    doAssert(emcc.len > 0)
    result = b.nimcachePath / "preload.js"
    let packagerPy = emcc.parentDir() / "tools" / "file_packager.py"
    var args = @["python", packagerPy.quoteShell(), b.buildRoot / "main.data", "--js-output=" & result]
    for p in b.emscriptenPreloadFiles:
        args.add(["--preload", p])
    direShell(args)

proc preconfigure(b: Builder) =
    b.buildRoot = b.buildRoot / b.platform
    b.nimcachePath = b.buildRoot / "nimcache"
    b.resourcePath = b.buildRoot / "res"

    if not beforeBuild.isNil: beforeBuild(b)

proc build*(b: Builder) =
    b.preconfigure()

    b.executablePath = b.buildRoot / b.appName
    b.bundleName = b.appName & ".app"

    b.nimFlags = @[]
    b.linkerFlags = @[]
    b.compilerFlags = @[]

    template addCAndLFlags(f: openarray[string]) =
        b.linkerFlags.add(f)
        b.compilerFlags.add(f)

    case b.platform
    of "macosx":
        let macOSSDK = macOSSDKPath(b.macOSSDKVersion)
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
            sdkPath = iOSSDKPath(b.iOSSDKVersion)
            sdlLibDir = b.buildSDLForIOS(false)
            b.nimFlags.add("--cpu:arm")
            addCAndLFlags(["-mios-version-min=" & b.iOSMinVersion])
        else:
            sdkPath = iOSSimulatorSDKPath(b.iOSSDKVersion)
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
        when defined(macosx) or defined(linux):
            # We are trying to build for windows, but we're not on windows.
            # Use mxe cross-compiler
            var mxeBin = findExe("i686-w64-mingw32.static-gcc")
            if mxeBin.len == 0:
                mxeBin = getEnv("MXE_BIN")
                if mxeBin.len == 0:
                    echo "Trying to cross-compile for windows, but mxe cross-compiler not found. Set MXE_BIN environment var to mxe gcc path."
                    quit 1
            b.nimFlags.add(["--cpu:i386", "--os:windows", "--cc:gcc", "--gcc.exe:" & mxeBin, "--gcc.linkerexe:" & mxeBin])
        b.makeWindowsResource()
    of "emscripten":
        let emcc_path = findExe("emcc")
        let emcc = if emcc_path.len > 0: emcc_path else: emccWrapperPath()
        b.emscriptenPreloadFiles.add(b.originalResourcePath & "/OpenSans-Regular.ttf@/res/OpenSans-Regular.ttf")
        b.executablePath = b.buildRoot / "main.js"
        b.nimFlags.add(["--cpu:i386", "-d:emscripten", "--os:linux", "--cc:clang",
            "--clang.exe=" & emcc.quoteShell(), "--clang.linkerexe=" & emcc.quoteShell(), "-d:SDL_Static"])

        if b.emscriptenPreloadFiles.len > 0:
            b.emscriptenPreJS.add(b.makeEmscriptenPreloadData())

        if b.emscriptenPreJS.len > 0:
            var preJsContent = ""
            for js in b.emscriptenPreJS:
                preJsContent &= readFile(js)
            let preJS = b.nimcachePath / "pre.js"
            writeFile(preJS, preJsContent)
            b.additionalLinkerFlags.add(["--pre-js", preJS])

        b.additionalNimFlags.add(["-d:useRealtimeGC"])
        b.additionalLinkerFlags.add(["-s", "ALLOW_MEMORY_GROWTH=1"])

        if not b.debugMode:
            b.additionalLinkerFlags.add("-Oz")
            b.additionalCompilerFlags.add("-Oz")

    else: discard

    if b.platform != "js" and b.platform != "emscripten":
        b.nimFlags.add("--threads:on")
        if b.platform != "windows" and not b.avoidSDL:
            b.linkerFlags.add("-lSDL2")

    if b.runAfterBuild and b.platform != "android" and b.platform != "ios" and
            b.platform != "ios-sim" and b.platform != "js" and
            b.platform != "emscripten":
        b.nimFlags.add("--run")

    b.nimFlags.add(["--warning[LockLevel]:off", "--verbosity:" & $b.nimVerbosity,
                "--hint[Pattern]:off",
                "--parallelBuild:" & $b.nimParallelBuild, "--out:" & b.executablePath,
                "--nimcache:" & b.nimcachePath])

    if b.platform != "windows" and not b.avoidSDL:
        b.nimFlags.add("--noMain")

    if b.avoidSDL: b.nimFlags.add("-d:nimxAvoidSDL")

    if b.debugMode:
        b.nimFlags.add(["-d:debug"])
        if b.platform != "js":
            b.nimFlags.add(["--stackTrace:on", "--lineTrace:on"])
    else:
        b.nimFlags.add(["-d:release", "--opt:speed", "-d:noAutoGLerrorCheck"])

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
    args.add(b.nimbleOverrideFlags())
    args.add b.mainFile
    direShell args

    if b.platform == "js" or b.platform == "emscripten":
        b.jsPostBuild()
    elif b.platform == "ios":
        if not b.codesignIdentity.isNil:
            b.signIosBundle()
            direShell "ios-deploy", "--debug", "--bundle", b.buildRoot / b.bundleName, "--no-wifi"

    elif b.platform == "android":
        b.ndkBuild()

    if not afterBuild.isNil:
        afterBuild(b)

proc processOutputFromAutotestStream(s: Stream): bool =
    var line = ""
    while s.readLine(line):
        if line.find("---AUTO-TEST-QUIT---") != -1:
            result = true
            break
        elif line.find("---AUTO-TEST-FAIL---") != -1:
            break
        else:
            echo line

proc runAutotestsInFirefox*(pathToMainHTML: string) =
    let ffbin = when defined(macosx):
            "/Applications/Firefox.app/Contents/MacOS/firefox"
        else:
            findExe("firefox")
    createDir("tempprofile")
    writeFile("tempprofile/user.js", """
    user_pref("browser.shell.checkDefaultBrowser", false);
    user_pref("browser.dom.window.dump.enabled", true);
    user_pref("app.update.auto", false);
    user_pref("app.update.enabled", false);
    user_pref("dom.max_script_run_time", 0);
    user_pref("dom.max_chrome_script_run_time", 0);
    user_pref("extensions.update.enabled", false);
    user_pref("extensions.update.autoUpdateDefault", false);
    user_pref("webgl.disable-fail-if-major-performance-caveat", true);
    """)
    let ffp = startProcess(ffbin, args = ["-profile", "./tempprofile", pathToMainHTML])
    let ok = processOutputFromAutotestStream(ffp.outputStream)
    ffp.kill()
    discard ffp.waitForExit()

    removeDir("tempprofile")
    doAssert(ok, "Firefox autotest failed")

proc runAutotestsInFirefox*(b: Builder) =
    runAutotestsInFirefox(b.buildRoot / "main.html")

proc chromeBin(): string =
    when defined(macosx):
        for c in ["/Applications/Chrome.app/Contents/MacOS/Chrome",
                    "/Applications/Chromium.app/Contents/MacOS/Chromium"]:
            if fileExists(c): return c
    else:
        for c in ["chrome", "chromium"]:
            let f = findExe(c)
            if f.len > 0: return f

proc runAutotestsInChrome*(pathToMainHTML: string) =
    let cbin = chromeBin()
    doAssert(cbin.len > 0)
    let cp = startProcess(cbin, args = ["--enable-logging=stderr", "--v=1",
        "--allow-file-access", "--allow-file-access-from-files",
        "--no-sandbox", "--user-data-dir",
        pathToMainHTML])
    let ok = processOutputFromAutotestStream(cp.errorStream)
    cp.kill()
    discard cp.waitForExit()
    doAssert(ok, "Chrome autotest failed")

proc runAutotestsInChrome*(b: Builder) =
    runAutotestsInChrome(b.buildRoot / "main.html")

proc adbExe(b: Builder): string =
    expandTilde(b.androidSdk/"platform-tools/adb")

proc adbServerName(b: Builder): string =
    result = getEnv("ADB_SERVER_NAME")
    if result.len == 0: result = "localhost"

proc getConnectedAndroidDevices*(b: Builder): seq[string] =
    let logcat = startProcess(b.adbExe, args = ["-H", b.adbServerName, "devices"])
    let so = logcat.outputStream
    var line = ""
    var i = 0
    result = @[]
    while so.readLine(line):
        if i > 0:
            let ln = line.split('\t')
            if ln.len == 2:
                result.add(ln[0])
        inc i

proc installAppOnConnectedDevice(b: Builder, devId: string) =
    let conf = if b.debugMode: "debug" else: "release"
    let apkPath = b.buildRoot / b.javaPackageId / "bin" / b.appName & "-" & conf & ".apk"
    direShell b.adbExe, "-H", b.adbServerName, "-s", devId, "install", "-r", apkPath

proc runAutotestsOnConnectedDevices*(b: Builder) =
    let adb = b.adbExe
    let host = b.adbServerName

    for devId in b.getConnectedAndroidDevices:
        echo "Running on device: ", devId
        b.installAppOnConnectedDevice(devId)

        let logcat = startProcess(adb, args = ["-H", host, "-s", devId, "logcat", "-T", "1", "-s", "NIM_APP"])

        direShell adb, "-H", host, "-s", devId, "shell", "input", "keyevent", "KEYCODE_WAKEUP"
        let activityName = b.javaPackageId & "/" & b.javaPackageId & ".MainActivity"
        direShell adb, "-H", host, "-s", devId, "shell", "am", "start", "-n", activityName

        let ok = processOutputFromAutotestStream(logcat.outputStream)
        logcat.kill()
        direShell adb, "-H", host, "-s", devId, "shell", "input", "keyevent", "KEYCODE_HOME"
        doAssert(ok, "Android autotest failed")

task defaultTask, "Build and run":
    newBuilder().build()

task "build", "Build and don't run":
    let b = newBuilder()
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
    let devs = b.getConnectedAndroidDevices()
    if devs.len > 0:
        b.installAppOnConnectedDevice(devs[0])

task "droid-debug", "Start application on Android device and connect with debugger":
    let b = newBuilder("android")
    b.preconfigure()
    withDir b.buildRoot / b.javaPackageId:
        if not fileExists("libs/gdb.setup"):
            for arch in ["armeabi", "armeabi-v7a", "x86"]:
                let p = "libs" / arch / "gdb.setup"
                if fileExists(p):
                    copyFile(p, "libs/gdb.setup")
                    break
        direShell(b.androidNdk / "ndk-gdb", "--adb=" & expandTilde(b.androidSdk) / "platform-tools" / "adb", "--force", "--launch")

task "js", "Create Javascript version and run in browser.":
    newBuilder("js").build()

task "emscripten", "Create emscripten version and run in browser.":
    newBuilder("emscripten").build()
