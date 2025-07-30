import nake
export nake

import os, tables, osproc, strutils, times, streams, os, pegs
import nester, asyncdispatch, browsers # Stuff needed for wasm target
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

  nimIncludeDir* {.deprecated.}: string

  macOSSDKPath* : string
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
  additionalPlistAttrs*: JsonNode

  runAfterBuild* : bool
  targetArchitectures* : seq[string]
  androidPermissions*: seq[string]
  screenOrientation*: string
  androidStaticLibraries*: seq[string]
  additionalAndroidResources*: seq[string]
  activityClassName*: string

  mainFile*: string

  bundleName : string

  codesignIdentity*: string # for iOS.
  teamId*: string # Optional
  emscriptenPreloadFiles*: seq[string]
  emscriptenPreJS*: seq[string]

  buildRoot: string
  executablePath : string
  nimcachePath : string
  resourcePath* : string
  originalResourcePath*: string
  nimFlags: seq[string]
  compilerFlags: seq[string]
  linkerFlags: seq[string]

  avoidSDL*: bool # Experimental feature.
  rebuild: bool
  useGradle* {.deprecated.}: bool # Experimental

  iosStatic*: bool # Dont use this

proc setBuilderSettingsFromCmdLine(b: Builder) =
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "define", "d":
        if val in ["js", "android", "ios", "ios-sim", "emscripten", "windows", "wasm"]:
          b.platform = val
        elif val == "release":
          b.debugMode = false
        else:
          b.additionalNimFlags.add("-d:" & val)
      of "norun":
        b.runAfterBuild = false
      of "rebuild":
        b.rebuild = true
      of "parallelBuild":
        b.nimParallelBuild = parseInt(val)
      of "compileOnly", "c":
        b.additionalNimFlags.add("--compileOnly")
      else: discard
    else: discard

proc getEnvErrorMsg(env: string): string =
  result = "\n Environment variable [ " & env & " ] is not set."

const xCodeApp = "/Applications/Xcode.app"

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

proc findNdk(p: string): string =
  # In dir `p` (usually "ANDROID_HOME/ndk") find ndk dir of the form (123.456.789) of most recent version
  type VerTuple = ((int, int, int), string)
  var maxVerNdk: VerTuple
  for k, f in walkDir(p):
    if k == pcDir:
      try:
        var v: seq[int]
        for versionPart in f.lastPathPart.split('.'):
          v.add(parseInt(versionPart))
        if v.len == 3:
          let vt = (v[0], v[1], v[2])
          if vt > maxVerNdk[0]:
            maxVerNdk = (vt, f)
      except:
        discard

  result = maxVerNdk[1]

proc findEnvPaths(b: Builder) =
  b.sdlRoot = getEnv("SDL_HOME")

  if b.platform in ["android", "ios", "ios-sim"]:
    var errorMsg = ""
    if b.platform == "android":
      var sdkPath = getEnv("ANDROID_HOME").expandTilde()
      if sdkPath.len == 0: sdkPath = getEnv("ANDROID_SDK_HOME").expandTilde()
      when not defined(windows):
        if sdkPath.len == 0:
          sdkPath = "~/Library/Android/sdk"
          if not fileExists(expandTilde(sdk_path / "platform-tools/adb")):
            sdkPath = ""
      if sdkPath.len == 0:
        errorMsg &= getEnvErrorMsg("ANDROID_HOME")
      else:
        sdkPath = expandTilde(sdkPath)
        var ndk = sdkPath / "ndk-bundle"
        if dirExists(ndk):
          b.androidNdk = ndk
        else:
          ndk = sdkPath / "ndk"
          if dirExists(ndk):
            b.androidNdk = findNdk(ndk)
            if b.androidNdk.len == 0:
              errorMsg &= "\nNo suitable NDK found in " & ndk
          else:
            errorMsg &= "\nAndroid NDK (ndk or ndk-bundle) not installed in ANDROID_HOME (" & sdkPath & "). To install it run: " & sdkPath & "/tools/bin/sdkmanager ndk-bundle"

      b.androidSdk = sdkPath

    if b.sdlRoot.len == 0: errorMsg &= getEnvErrorMsg("SDL_HOME")

    if error_msg.len > 0:
      raise newException(Exception, errorMsg)

proc versionCodeWithTime*(t: DateTime): int =
  let month = (t.year - 2016) * 12 + (t.month.int + 1)
  result = t.minute + t.hour * 100 + t.monthday * 10000 + month * 1000000

proc versionCodeWithTime*(t: Time): int =
  versionCodeWithTime(t.local)

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
  b.enableClosureCompilerSourceMap = false

  when defined(windows):
    b.appIconName = "MyGame.ico"

  # Simulator device identifier should be set to run the simulator.
  # Available simulators can be listed with the command:
  # $ xcrun simctl list
  b.iOSSimulatorDeviceId = "booted"

  b.nimVerbosity = 1
  b.nimParallelBuild = 0
  b.debugMode = true

  b.additionalPlistAttrs = newJObject()

  b.mainFile = "main"

  b.runAfterBuild = true
  b.targetArchitectures = @["arm64-v8a"]

  b.buildRoot = "build"
  b.originalResourcePath = "res"

  b.codesignIdentity = "Apple Development"

  b.setBuilderSettingsFromCmdLine()
  b.findEnvPaths()

  if b.platform in ["ios", "ios-sim"]:
    b.iOSSDKVersion = getiOSSDKVersion()
    b.iOSMinVersion = b.iOSSDKVersion
  elif b.platform == "macosx":
    var macosxSDK = execProcess("xcrun", args=["--show-sdk-path"], options={poUsePath})
    macosxSDK.removeSuffix()
    b.macOSSDKPath = macosxSDK
    var ver = execProcess("xcrun", args=["--show-sdk-version"], options={poUsePath})
    ver.removeSuffix()
    b.macOSMinVersion = "10.7"
    b.macOSSDKVersion = ver
  elif b.platform == "wasm":
    when defined(macosx):
      var macosxSDK = execProcess("xcrun", args=["--show-sdk-path"], options={poUsePath})
      macosxSDK.removeSuffix()
      b.macOSSDKPath = macosxSDK

proc nimblePath(package: string): string =
  var nimblecmd = "nimble"
  var (packageDir, err) = execCmdEx(nimblecmd & " path " & package)
  if err == 0:
    let lines = packageDir.splitLines()
    if lines.len > 1:
      result = lines[^2]

proc nimbleNimxPath(): string =
  result = nimblePath("nimx")
  doAssert(result.len != 0, "Error: nimx does not seem to be installed with nimble!")

proc emccWrapperPath(): string =
  result = findExe("emcc")
  if result.len == 0:
    let p = "/usr/lib/emscripten/emcc"
    if fileExists(p):
      result = p

  if result.len == 0:
    raise newException(Exception, "emcc not found")

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
  elif defined(haiku):
    newBuilder("haiku")
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
  for key, value in b.additionalPlistAttrs:
    plist[key] = value

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

  if b.appIconName.len != 0:
    let appIconPath = b.resourcePath / b.appIconName

    if fileExists(absPath(appIconPath)):
      writeFile(rcPath, "AppIcon ICON \"$#\"" % [b.appIconName])
      if shell("windres", "-i", rcPath, "-o", rcO):
        createResource = true
      else:
        echo "Warning: could not create resource for icon $#" % [appIconPath]
    else:
      echo "Warning: icon was not found: $#" % [appIconPath]
  else:
    echo "Info: you can set your application icon by setting `builder.appIconName` property."

  if createResource:
    b.additionalLinkerFlags.add(absPath(rcO))

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

proc checkSdlRoot(b: Builder) =
  let r = expandTilde(b.sdlRoot)
  if not (dirExists(r / "android-project") and dirExists(r / "Xcode-iOS")):
    echo "Wrong SDL_HOME. The SDL_HOME environment variable must point to SDL2 source code."
    echo "SDL2 source code can be downloaded from https://www.libsdl.org/download-2.0.php"
    raise newException(Exception, "Wrong SDL_HOME")

proc buildSDLForDesktop(b: Builder): string =
  when defined(linux):
    result = "/usr/lib"
  elif defined(macosx):
    proc isValid(dir: string): bool =
      fileExists(dir / "libSDL2.a") or fileExists(dir / "libSDL2.dylib")
    if b.sdlRoot.len != 0:
      b.checkSdlRoot()
      let xcodeProjDir = expandTilde(b.sdlRoot)/"Xcode/SDL"
      result = xcodeProjDir/"build/Release"
      if isValid(result): return result
      # would be cleaner with try/catch, see https://github.com/fowlmouth/nake/issues/63, to give better diagnostics
      direShell "xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-target", "Static\\ Library", "-configuration", "Release", "SYMROOT=build"
      return result

    result = "/usr/local/lib"
    if isValid(result): return result

    if "brew --version".execCmdEx().exitCode == 0:
      # user has homebrew
      let ret = "brew --prefix sdl2".execCmdEx()
      if ret.exitCode == 0:
        result = ret.output.string
        stripLineEnd(result)
        result = result / "lib"
        doAssert isValid(result), result
        return result

    assert(false, "Don't know where to find SDL. Consider setting SDL_HOME environment variable.")
  elif defined(haiku):
    result = "/system/develop/lib"
  else:
    assert(false, "Don't know where to find SDL")

proc buildSDLForIOS(b: Builder, forSimulator: bool = false): string =
  b.checkSdlRoot()
  let entity = if forSimulator: "iphonesimulator" else: "iphoneos"
  let xcodeProjDir = expandTilde(b.sdlRoot)/"Xcode-iOS/SDL"
  let sdlBuildDir = xcodeProjDir/"build/Release-" & entity
  result = b.buildRoot
  if not fileExists result/"libSDL2.a":
    var args = @["xcodebuild", "-project", xcodeProjDir/"SDL.xcodeproj", "-configuration", "Release", "-sdk", entity&b.iOSSDKVersion, "SYMROOT=build"]
    if forSimulator:
      args.add("ARCHS=\"i386 x86_64\"")
    else:
      args.add("ARCHS=\"arm64 armv7\"")
    direShell args
    createDir(result)
    createSymLink(sdlBuildDir / "libSDL2.a", result / "libSDL2.a")

proc makeAndroidBuildDir(b: Builder): string =
  let buildDir = b.buildRoot / b.javaPackageId
  if not dirExists buildDir:
    b.checkSdlRoot()
    let sdlRoot = expandTilde(b.sdlRoot)
    let nimxTemplateDir = nimbleNimxPath() / "assets" / "android/template"
    let sdlDefaultAndroidProjectTemplate =  sdlRoot/"android-project"

    createDir(buildDir)
    copyDirWithPermissions(nimxTemplateDir, buildDir)
    copyDir(sdlDefaultAndroidProjectTemplate / "app/src/main/java", buildDir / "src/main/java")

    let sdlJni = buildDir/"jni"/"SDL"
    createDir(sdlJni)

    copyDir sdlRoot/"src", sdlJni/"src"
    copyDir sdlRoot/"include", sdlJni/"include"

    let sdlmk = sdlJni/"Android.mk"
    copyFile(sdlRoot/"Android.mk", sdlmk)

    var sdlmkData = readFile(sdlmk)
    block cutSDLDLLBuild:
      # Patch SDL's Android.mk so that it doesn't build dynamic lib.
      let startIndex = sdlmkData.find("include $(BUILD_SHARED_LIBRARY)")
      let endIndex = "include $(BUILD_SHARED_LIBRARY)".len
      sdlmkData.delete(startIndex, startIndex + endIndex)

    writeFile(sdlmk, sdlmkData)

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
    if b.screenOrientation.len != 0:
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

    replaceVarsInFile buildDir/"jni/src/Android.mk", vars
    replaceVarsInFile buildDir/"jni/Application.mk", vars
    replaceVarsInFile buildDir/"src/main/AndroidManifest.xml", vars
    replaceVarsInFile buildDir/"src/main/res/values/strings.xml", vars
    replaceVarsInFile buildDir/"build.gradle", vars

    for a in b.targetArchitectures:
      createDir(buildDir/"jni/src"/a)

  buildDir

proc packageNameAtPath(d: string): string =
  for file in walkFiles(d / "*.nimble"):
    return file.splitFile.name

proc curPackageNameAndPath(): tuple[name, path: string] =
  var d = getCurrentDir()
  while d.len > 1:
    result.name = packageNameAtPath(d)
    if result.name.len != 0:
      result.path = d
      return
    d = d.parentDir()

proc nimbleOverrideFlags(b: Builder): seq[string] =
  let cp = curPackageNameAndPath()
  if cp.name.len != 0:
    let origNimblePath = nimblePath(cp.name)
    if origNimblePath.len != 0: result.add("--excludePath:" & origNimblePath)
    result.add("--path:" & cp.path)

proc postprocessWebTarget(b: Builder) =
  let sf = splitFile(b.mainFile)
  var mainHTML = sf.dir / sf.name & ".html"
  if not fileExists(mainHTML):
    mainHTML = nimbleNimxPath() / "assets" / "main.html"
  copyFile(mainHTML, b.buildRoot / "main.html")
  if b.runAfterBuild:
    when not defined(windows):
      proc doOpen() {.async.} =
        await sleepAsync(1)
        openDefaultBrowser "http://localhost:5000"
      asyncCheck doOpen()

    let router = newRouter()
    router.routes:
      get "/": redirect "main.html"
    router.serve(staticPath = b.buildRoot)

proc teamIdFromCodesignIdentity(i: string): string =
  # TeamId is the Organizational Unit of codesign identity certificate. To extract it run:
  # security find-certificate -c "Apple Development: me@example.com (12345678)" -p | openssl x509 -noout -text | sed -n 's/.*Subject:.* OU=\([^,]*\).*/\1/p'
  let (o, r) = execCmdEx("""sh -c "security find-certificate -c '""" & i & """' -p | openssl x509 -noout -text | sed -n 's/.*Subject:.* OU=\([^,]*\).*/\1/p'"""")
  if r == 0: result = string(o).strip()

proc signIosBundle(b: Builder) =
  let e = newJObject() # Entitlements
  let entPath = b.buildRoot / "entitlements.plist"
  if b.teamId.len == 0:
    b.teamId = teamIdFromCodesignIdentity(b.codesignIdentity)
    if b.teamId.len == 0:
      raise newException(ValueError, "Could not get Team Id. Wrong codesign identity?")

  let appID = b.teamId & "." & b.bundleId

  e["application-identifier"] = %appID
  e["com.apple.developer.team-identifier"] = %b.teamId
  e["get-task-allow"] = %b.debugMode
  e["keychain-access-groups"] = %*[appID]

  # List available codesign identities with
  # security find-identity -v -p codesigning

  e.writePlist(entPath)
  direShell(["codesign", "-s", "\"" & b.codesignIdentity & "\"", "--force", "--entitlements", entPath, b.buildRoot / b.bundleName])

proc gradleBuild(b: Builder) =
  withDir(b.buildRoot / b.javaPackageId):
    putEnv "ANDROID_HOME", expandTilde(b.androidSdk)
    var args = @[getCurrentDir() / "gradlew"]
    args.add(["--warning-mode", "all"])
    if b.debugMode:
      args.add("assembleDebug")
    else:
      args.add("assembleRelease")
    direShell args

proc makeEmscriptenPreloadData(b: Builder): string =
  let emcc_path = findExe("emcc")
  let emcc = if emcc_path.len > 0: emcc_path else: findEmcc()

  doAssert(emcc.len > 0)
  result = b.nimcachePath / "preload.js"
  let packagerPy = emcc.parentDir() / "tools" / "file_packager.py"
  createDir(b.nimcachePath)
  var args = @["python", packagerPy.quoteShell(), b.buildRoot / "main.data", "--js-output=" & result]
  for p in b.emscriptenPreloadFiles:
    args.add(["--preload", p])
  direShell(args)

proc targetArchToClangTriplet(arch: string): string =
  case arch
  of "armeabi": "arm-linux-androideabi"
  of "armeabi-v7a": "armv7a-linux-androideabi"
  of "arm64-v8a": "aarch64-linux-android"
  of "x86": "i686-linux-android"
  of "x86_64": "x86_64-linux-android"
  else: raise newException(Exception, "Unknown target architecture: " & arch)

proc targetArchToCpuType(arch: string): string =
  case arch
  of "armeabi", "armeabi-v7a": "arm"
  of "arm64-v8a": "arm64"
  of "x86": "i386"
  of "x86_64": "amd64"
  else: raise newException(Exception, "Unknown target architecture: " & arch)

proc configure*(b: Builder) =
  b.buildRoot = b.buildRoot / b.platform
  if b.rebuild and existsDir(b.buildRoot):
    removeDir(b.buildRoot)

  b.nimcachePath = b.buildRoot / "nimcache"
  b.resourcePath = b.buildRoot / "res"

  if not beforeBuild.isNil: beforeBuild(b)

proc androidToolchainBinPath(b: Builder): string =
  # https://developer.android.com/ndk/guides/other_build_systems
  result = b.androidNdk / "toolchains/llvm/prebuilt"
  when defined(windows):
    let w64 = result / "windows-x86_64"
    if dirExists(w64):
      result = w64
    else:
      result = result / "windows"
      if not dirExists(result):
        result = result.parentDir
        raise newException(Exception, "No NDK toolchain found for windows in " & result)
  elif defined(macosx):
    result &= "/darwin-x86_64"
  elif defined(linux):
    result &= "/linux-x86_64"
  else:
    raise newException(Exception, "NDK toolchain is not supported on your platform")
  result &= "/bin"

proc build*(b: Builder) =
  b.configure()

  b.executablePath = b.buildRoot / b.appName
  b.bundleName = b.appName & ".app"

  template addCAndLFlags(f: openarray[string]) =
    b.linkerFlags.add(f)
    b.compilerFlags.add(f)

  case b.platform
  of "macosx":
    let macOSSDK = b.macOSSDKPath
    b.makeMacOsBundle()
    b.executablePath = b.buildRoot / b.bundleName / "Contents" / "MacOS" / b.appName
    b.resourcePath = b.buildRoot / b.bundleName / "Contents" / "Resources"
    addCAndLFlags(["-isysroot", macOSSDK, "-mmacosx-version-min=" & b.macOSMinVersion])
    b.linkerFlags.add(["-fobjc-link-runtime", "-L" & b.buildSDLForDesktop()])
    b.nimFlags.add("--dynlibOverride:SDL2")
    b.linkerFlags.add("-lpthread")


  of "ios", "ios-sim":
    if b.iosStatic:
      b.executablePath = b.buildRoot / "libMain.a"
      b.resourcePath = b.buildRoot / "res"
    else:
      b.executablePath = b.buildRoot / b.bundleName / b.appName
      b.resourcePath = b.buildRoot / b.bundleName

    b.nimFlags.add(["--os:macosx", "-d:ios", "-d:iPhone", "--dynlibOverride:SDL2"])

    var sdkPath: string
    var sdlLibDir: string
    if b.platform == "ios":
      sdkPath = iOSSDKPath(b.iOSSDKVersion)
      sdlLibDir = b.buildSDLForIOS(false)
      b.nimFlags.add(["--cpu:arm64"])
      addCAndLFlags(["-mios-version-min=" & b.iOSMinVersion])
    else:
      sdkPath = iOSSimulatorSDKPath(b.iOSSDKVersion)
      sdlLibDir = b.buildSDLForIOS(true)
      b.nimFlags.add("--cpu:amd64")
      b.nimFlags.add("-d:simulator")
      addCAndLFlags(["-mios-simulator-version-min=" & b.iOSMinVersion])

    b.linkerFlags.add(["-fobjc-link-runtime", "-L" & sdlLibDir])
    addCAndLFlags(["-isysroot", sdkPath])

    if b.iosStatic:
      b.nimFlags.add("--out:" & b.executablePath / "libmain_static.a")
      # b.compilerFlags.add("-fembed-bitcode")
      b.nimFlags.add("--clang.linkerexe:" & "libtool")
      b.nimFlags.add("--listCmd")

      let arch = if b.platform == "ios-sim": "x86_64" else: "arm64"
      # Workaround nim static lib linker
      b.nimFlags.add("--clang.linkTmpl:" & quoteShell("-static -arch_only " & arch & " -D -syslibroot " & sdkPath & " -o $exefile $objfiles"))
      b.compilerFlags.add("-g")
  of "android":
    if b.androidApi == 0:
      b.androidApi = 18

    let buildDir = b.makeAndroidBuildDir()
    b.nimcachePath = buildDir / "nimcache"
    b.resourcePath = buildDir / "src/main/assets"
    b.executablePath = buildDir / "jni/main"


    # It sould be --app:staticLib, but nim static lib "linker" is not configurable, so we hack it with linkTmpl below.

    b.nimFlags.add(["--os:linux", "-d:android", "--cc:clang", "--dynlibOverride:SDL2"])
    b.compilerFlags.add("-fPIC")
    b.compilerFlags.add("-g") # Here we rely on gradle to strip everything debug when needed.
  of "linux":
    b.linkerFlags.add(["-L/usr/local/lib", "-Wl,-rpath,/usr/local/lib", "-lpthread"])
  of "windows":
    b.executablePath &= ".exe"
    if not b.debugMode:
      b.nimFlags.add("--app:gui")
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
  of "js":
    b.nimFlags.add("-d:nimExperimentalAsyncjsThen")
    b.executablePath = b.buildRoot / "main.js"
  of "emscripten", "wasm":
    b.nimFlags.add("-d:nimExperimentalAsyncjsThen")
    b.emscriptenPreloadFiles.add(b.originalResourcePath & "/OpenSans-Regular.ttf@/res/OpenSans-Regular.ttf")
    b.executablePath = b.buildRoot / "main.js"
    b.nimFlags.add(["--cpu:i386", "-d:wasm", "--os:linux", "--cc:clang", "--threads:off", "--mm:orc",
      "-d:noSignalHandler"])
    when defined(macosx):
      let clang = "/opt/homebrew/opt/llvm/bin"
      b.nimFlags.add(["--clang.path=" & clang.quoteShell()])
      let macOSSDK = b.macOSSDKPath
      # addCAndLFlags(["-isysroot", macOSSDK])
      b.additionalCompilerFlags.add(["-I" & macOSSDK & "/usr/include", "-D__i386__"])


    let llTarget = "wasm32-unknown-unknown-wasm"
    addCAndLFlags(["--target=" & llTarget])

    # b.additionalCompilerFlags.add("-I/usr/include")

    # b.emscriptenPreJS.add(b.makeEmscriptenPreloadData())

    var preJsContent = ""
    for js in b.emscriptenPreJS:
      preJsContent &= readFile(js)
    let preJS = b.nimcachePath / "pre.js"
    writeFile(preJS, preJsContent)
    b.additionalLinkerFlags.add(["--pre-js", preJS])

    b.additionalNimFlags.add(["-d:useRealtimeGC"])
    # b.additionalLinkerFlags.add(["-s", "ALLOW_MEMORY_GROWTH=1"])

    if not b.debugMode:
      b.additionalCompilerFlags.add("-Oz")

    if b.platform == "emscripten":
      if not b.disableClosureCompiler:
        b.additionalLinkerFlags.add("-Oz")
      else:
        b.additionalCompilerFlags.add("-g")
        b.additionalLinkerFlags.add("-g4")
        if not b.debugMode:
          b.additionalLinkerFlags.add("-gseparate-dwarf")

      if not b.debugMode:
        b.additionalLinkerFlags.add(["-s", "ELIMINATE_DUPLICATE_FUNCTIONS=1"])
    # elif b.platform == "wasm":
    #   addCAndLFlags(["-s", "WASM=1"])
  else: discard

  if b.platform notin ["js", "emscripten", "wasm"]:
    b.nimFlags.add("--threads:on")
    if not b.avoidSDL:
      b.linkerFlags.add("-lSDL2")

  if b.runAfterBuild and b.platform notin ["android", "ios", "ios-sim",
      "js", "wasm", "emscripten"]:
    b.nimFlags.add("--run")

  b.nimFlags.add(["--warning[LockLevel]:off", "--verbosity:" & $b.nimVerbosity,
        "--hint[Pattern]:off",
        "--parallelBuild:" & $b.nimParallelBuild])

  if b.platform != "android":
    b.nimFlags.add("--out:" & b.executablePath)

  if b.platform in ["android", "ios", "ios-sim"] and not b.avoidSDL:
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

  if b.platform in ["ios", "ios-sim"]:
    b.makeIosBundle()

  createDir(parentDir(b.executablePath))

  let command = case b.platform
    of "js": "js"
    else: "c"

  b.nimFlags.add("--putEnv:NIMX_RES_PATH=" & b.resourcePath)
  # Run Nim
  var args = @[findExe("nim").quoteShell(), command]
  args.add(b.nimFlags)
  args.add(b.nimbleOverrideFlags())

  if b.platform in ["android"]: # multiarch
    let toolchainBin = b.androidToolchainBinPath()
    for a in b.targetArchitectures:
      echo "Running nim for architecture: ", a

      var aargs = args
      aargs.add("--cpu:" & targetArchToCpuType(a))
      aargs.add("--out:" & b.executablePath / a / "libmain_static.a")

      aargs.add("--nimcache:" & b.nimcachePath / a)
      aargs.add("--clang.exe:" & toolchainBin / "clang")
      aargs.add("--clang.linkerexe:" & toolchainBin / "llvm-ar")
      aargs.add("--passC:\"-target " & targetArchToClangTriplet(a) & "21\"")
      aargs.add("--listCmd")

      # Workaround nim static lib linker
      aargs.add("--clang.linkTmpl:" & quoteShell("rcs $exefile $objfiles"))

      # Nim ignores --out path for static libs. Instead it puts result in the current dir
      aargs.add b.mainFile
      echo aargs.join " "
      direShell aargs
  else:
    args.add("--nimcache:" & b.nimcachePath)
    args.add b.mainFile
    echo args.join " "
    direShell args

  if b.platform in ["emscripten", "wasm", "js"]:
    b.postprocessWebTarget()
  elif b.platform == "ios":
    if b.codesignIdentity.len != 0:
      b.signIosBundle()
      direShell "ios-deploy", "--debug", "--bundle", b.buildRoot / b.bundleName, "--no-wifi"

  elif b.platform == "android":
    b.gradleBuild()

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

proc queryStringWithArgs(args: StringTableRef): string =
  if args.isNil:
    result = ""
  else:
    result = "?"
    var i = 0
    for k, v in args:
      if i != 0: result &= '&'
      result &= k
      result &= '='
      result &= v
      inc i

proc runAutotestsInFirefox*(pathToMainHTML: string, args: StringTableRef = nil) =
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

proc runAutotestsInFirefox*(b: Builder, args: StringTableRef = nil) =
  runAutotestsInFirefox(b.buildRoot / "main.html", args)

proc chromeBin(): string =
  when defined(macosx):
    for c in ["/Applications/Chrome.app/Contents/MacOS/Chrome",
          "/Applications/Chromium.app/Contents/MacOS/Chromium",
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"]:
      if fileExists(c): return c
  else:
    for c in ["chrome", "chromium"]:
      let f = findExe(c)
      if f.len > 0: return f

proc runAutotestsInChrome*(pathToMainHTML: string, args: StringTableRef = nil) =
  let cbin = chromeBin()
  doAssert(cbin.len > 0)

  let cp = startProcess(cbin, args = ["--enable-logging=stderr", "--v=1",
    "--allow-file-access", "--allow-file-access-from-files",
    "--no-sandbox", "--user-data-dir",
    "file://" & expandFilename(pathToMainHTML) & queryStringWithArgs(args)])
  let ok = processOutputFromAutotestStream(cp.errorStream)
  cp.kill()
  discard cp.waitForExit()
  doAssert(ok, "Chrome autotest failed")

proc runAutotestsInChrome*(b: Builder, args: StringTableRef = nil) =
  runAutotestsInChrome(b.buildRoot / "main.html", args)

proc adbExe(b: Builder): string =
  expandTilde(b.androidSdk/"platform-tools/adb")

proc adbServerName(b: Builder): string =
  result = getEnv("ADB_SERVER_NAME")
  if result.len == 0: result = "localhost"

proc getConnectedAndroidDevices*(b: Builder): seq[string] =
  # The readLine loop can hang if adb is run without starting the adb server,
  # so we start the server upfront.
  if b.adbServerName == "localhost": direShell b.adbExe, "start-server"
  let logcat = startProcess(b.adbExe, args = ["-H", b.adbServerName, "devices"])
  let so = logcat.outputStream
  var line = ""
  var i = 0
  while so.readLine(line):
    if i > 0:
      let ln = line.split('\t')
      if ln.len == 2:
        result.add(ln[0])
    inc i

proc installAppOnConnectedDevice(b: Builder, devId: string) =
  let conf = if b.debugMode: "debug" else: "release"
  var apkPath = b.buildRoot / b.javaPackageId / "build" / "outputs" / "apk" / conf / b.javaPackageId & "-" & conf & ".apk"

  direShell b.adbExe, "-H", b.adbServerName, "-s", devId, "install", "-r", apkPath
  # direShell b.adbExe, "-H", b.adbServerName, "-s", devId, "install", "--abi", "armeabi-v7a", "-r", apkPath
  if b.runAfterBuild:
    var activityName =  b.javaPackageId & "/" & b.activityClassName
    direShell b.adbExe, "shell", "am", "start", "-n", activityName

proc runAutotestsOnAndroidDevice*(b: Builder, devId: string, install: bool = true, extraArgs: StringTableRef = nil) =
  echo "Running on device: ", devId
  if install: b.installAppOnConnectedDevice(devId)

  let adb = b.adbExe
  let host = b.adbServerName

  let logcat = startProcess(adb, args = ["-H", host, "-s", devId, "logcat", "-T", "1", "-s", "NIM_APP"])

  direShell adb, "-H", host, "-s", devId, "shell", "input", "keyevent", "KEYCODE_WAKEUP"
  let activityName = b.javaPackageId & "/" & b.javaPackageId & ".MainActivity"

  var args = @[adb, "-H", host, "-s", devId, "shell", "am", "start", "-S", "-n", activityName]
  if not extraArgs.isNil:
    for k, v in extraArgs: args.add(["-e", k, v])

  direShell(args)

  let ok = processOutputFromAutotestStream(logcat.outputStream)
  logcat.kill()
  direShell adb, "-H", host, "-s", devId, "shell", "input", "keyevent", "KEYCODE_HOME"
  doAssert(ok, "Android autotest failed")

proc runAutotestsOnConnectedDevices*(b: Builder, install: bool = true, extraArgs: StringTableRef = nil) =
  for devId in b.getConnectedAndroidDevices:
    b.runAutotestsOnAndroidDevice(devId, install, extraArgs)

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
  b.configure()
  withDir b.buildRoot / b.javaPackageId:
    if not fileExists("libs/gdb.setup"):
      for arch in ["armeabi", "armeabi-v7a", "x86"]:
        let p = "libs" / arch / "gdb.setup"
        if fileExists(p):
          copyFile(p, "libs/gdb.setup")
          break
    direShell(b.androidNdk / "ndk-gdb", "--adb=" & b.adbExe, "--force", "--launch")

task "js", "Create Javascript version and run in browser.":
  newBuilder("js").build()

task "emscripten", "Create emscripten version and run in browser.":
  newBuilder("emscripten").build()

task "wasm", "Create WebAssembly version and run in browser.":
  newBuilder("wasm").build()
