#!/usr/bin/env python3
"""
Aggiunge il target watchOS 'FitnessWatch' al progetto Xcode.

Il file di progetto è in formato objectVersion 77 (gruppi sincronizzati col
filesystem), quindi non serve elencare i sorgenti: basta agganciare le cartelle.

Modifiche:
  - nuovo PBXNativeTarget FitnessWatch (app watchOS)
  - gruppi sincronizzati FitnessWatch e Shared
  - Shared aggiunto anche al target iOS
  - fase "Embed Watch Content" sull'app iOS + dipendenza fra i target
"""
import re
import sys
import pathlib

P = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                 else "FitnessApp.xcodeproj/project.pbxproj")
s = P.read_text()

if "FitnessWatch" in s:
    sys.exit("Il target FitnessWatch sembra già presente: niente da fare.")

# Il gruppo Shared è già agganciato al target iOS: qui va solo riusato.
EXISTING_SHARED = re.search(r"([0-9A-F]{24}) /\* Shared \*/ = \{\s*isa = PBXFileSystemSynchronizedRootGroup", s)

# ── Identificatori nuovi (prefisso riconoscibile, 24 esadecimali) ─────────────
ID = {k: f"FA7CBEEF0000000000{n:04X}" for n, k in enumerate([
    "target", "product", "watchGroup", "sharedGroup", "sources", "frameworks",
    "resources", "confList", "debug", "release", "embedPhase", "embedFile",
    "proxy", "dep",
], start=1)}

IOS_TARGET = "F03801322F6B633200D77569"
IOS_APP_GROUP = "F03801352F6B633200D77569"
PROJECT_OBJ = "F038012B2F6B633200D77569"
PRODUCTS_GROUP = "F03801342F6B633200D77569"
MAIN_GROUP = "F038012A2F6B633200D77569"


def splice(marker, addition, after=True):
    """Inserisce `addition` subito dopo (o prima di) `marker`."""
    global s
    if marker not in s:
        sys.exit(f"Ancora non trovata nel pbxproj: {marker!r}")
    s = s.replace(marker, marker + addition if after else addition + marker, 1)


# ── 1. PBXBuildFile: la watch app dentro la fase di embed ────────────────────
splice("/* Begin PBXBuildFile section */\n", f"""\t\t{ID['embedFile']} /* FitnessWatch.app in Embed Watch Content */ = {{isa = PBXBuildFile; fileRef = {ID['product']} /* FitnessWatch.app */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n""")

# ── 2. Dipendenza dell'app iOS dal target watch ──────────────────────────────
splice("/* Begin PBXContainerItemProxy section */\n", f"""\t\t{ID['proxy']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {PROJECT_OBJ} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ID['target']};
\t\t\tremoteInfo = FitnessWatch;
\t\t}};\n""")

splice("/* Begin PBXTargetDependency section */\n", f"""\t\t{ID['dep']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ID['target']} /* FitnessWatch */;
\t\t\ttargetProxy = {ID['proxy']} /* PBXContainerItemProxy */;
\t\t}};\n""")

# ── 3. Fase "Embed Watch Content" sull'app iOS ───────────────────────────────
splice("/* Begin PBXCopyFilesBuildPhase section */\n", f"""\t\t{ID['embedPhase']} /* Embed Watch Content */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "$(CONTENTS_FOLDER_PATH)/Watch";
\t\t\tdstSubfolderSpec = 16;
\t\t\tfiles = (
\t\t\t\t{ID['embedFile']} /* FitnessWatch.app in Embed Watch Content */,
\t\t\t);
\t\t\tname = "Embed Watch Content";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};\n""")

# ── 4. Prodotto ──────────────────────────────────────────────────────────────
splice("/* Begin PBXFileReference section */\n", f"""\t\t{ID['product']} /* FitnessWatch.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FitnessWatch.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n""")

# ── 5. Gruppi sincronizzati: FitnessWatch e Shared ───────────────────────────
if EXISTING_SHARED:
    ID["sharedGroup"] = EXISTING_SHARED.group(1)
    shared_decl = ""
else:
    shared_decl = f"""\t\t{ID['sharedGroup']} /* Shared */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = Shared;
\t\t\tsourceTree = "<group>";
\t\t}};\n"""

splice("/* Begin PBXFileSystemSynchronizedRootGroup section */\n", f"""\t\t{ID['watchGroup']} /* FitnessWatch */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = FitnessWatch;
\t\t\tsourceTree = "<group>";
\t\t}};\n""" + shared_decl)

# ── 6. Fasi di build del target watch ────────────────────────────────────────
splice("/* Begin PBXSourcesBuildPhase section */\n", f"""\t\t{ID['sources']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};\n""")

splice("/* Begin PBXFrameworksBuildPhase section */\n", f"""\t\t{ID['frameworks']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};\n""")

splice("/* Begin PBXResourcesBuildPhase section */\n", f"""\t\t{ID['resources']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};\n""")

# ── 7. Il target ─────────────────────────────────────────────────────────────
splice("/* Begin PBXNativeTarget section */\n", f"""\t\t{ID['target']} /* FitnessWatch */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ID['confList']} /* Build configuration list for PBXNativeTarget "FitnessWatch" */;
\t\t\tbuildPhases = (
\t\t\t\t{ID['sources']} /* Sources */,
\t\t\t\t{ID['frameworks']} /* Frameworks */,
\t\t\t\t{ID['resources']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{ID['watchGroup']} /* FitnessWatch */,
\t\t\t\t{ID['sharedGroup']} /* Shared */,
\t\t\t);
\t\t\tname = FitnessWatch;
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = FitnessWatch;
\t\t\tproductReference = {ID['product']} /* FitnessWatch.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};\n""")

# ── 8. Configurazioni del target watch ───────────────────────────────────────
common = f"""\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = Fitness;
\t\t\t\tINFOPLIST_KEY_WKApplication = YES;
\t\t\t\tINFOPLIST_KEY_WKCompanionAppBundleIdentifier = davideCorso.FitnessApp;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = davideCorso.FitnessApp.watchkitapp;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_APPROACHABLE_CONCURRENCY = YES;
\t\t\t\tSWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 4;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 26.0;"""

splice("/* Begin XCBuildConfiguration section */\n", f"""\t\t{ID['debug']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common}
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ID['release']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common}
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t}};
\t\t\tname = Release;
\t\t}};\n""")

splice("/* Begin XCConfigurationList section */\n", f"""\t\t{ID['confList']} /* Build configuration list for PBXNativeTarget "FitnessWatch" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ID['debug']} /* Debug */,
\t\t\t\t{ID['release']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};\n""")

# ── 9. Agganci al target iOS e al progetto ───────────────────────────────────
# Shared anche nell'app iOS, se non c'è già
if not EXISTING_SHARED:
    s = s.replace(f"""\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{IOS_APP_GROUP} /* FitnessApp */,
\t\t\t);""", f"""\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{IOS_APP_GROUP} /* FitnessApp */,
\t\t\t\t{ID['sharedGroup']} /* Shared */,
\t\t\t);""", 1)

# Fase di embed e dipendenza nel target iOS
s = s.replace("""\t\t\t\tF0D0FDF72FCB319C002EEFF8 /* Embed Foundation Extensions */,
\t\t\t);""", f"""\t\t\t\tF0D0FDF72FCB319C002EEFF8 /* Embed Foundation Extensions */,
\t\t\t\t{ID['embedPhase']} /* Embed Watch Content */,
\t\t\t);""", 1)

s = s.replace("""\t\t\t\tF0D0FDF12FCB319C002EEFF8 /* PBXTargetDependency */,
\t\t\t);""", f"""\t\t\t\tF0D0FDF12FCB319C002EEFF8 /* PBXTargetDependency */,
\t\t\t\t{ID['dep']} /* PBXTargetDependency */,
\t\t\t);""", 1)

# Prodotto, gruppi, elenco target, attributi
s = s.replace(f"""\t\t\t\tF0D0FDE22FCB319B002EEFF8 /* FitnessWidgetExtension.appex */,
\t\t\t);
\t\t\tname = Products;""", f"""\t\t\t\tF0D0FDE22FCB319B002EEFF8 /* FitnessWidgetExtension.appex */,
\t\t\t\t{ID['product']} /* FitnessWatch.app */,
\t\t\t);
\t\t\tname = Products;""", 1)

s = s.replace("""\t\t\t\tF0D0FDE82FCB319B002EEFF8 /* FitnessWidget */,""",
              f"""\t\t\t\tF0D0FDE82FCB319B002EEFF8 /* FitnessWidget */,
\t\t\t\t{ID['watchGroup']} /* FitnessWatch */,""", 1)

s = s.replace(f"""\t\t\t\tF0D0FDE12FCB319B002EEFF8 /* FitnessWidgetExtension */,
\t\t\t);
\t\t}};""", f"""\t\t\t\tF0D0FDE12FCB319B002EEFF8 /* FitnessWidgetExtension */,
\t\t\t\t{ID['target']} /* FitnessWatch */,
\t\t\t);
\t\t}};""", 1)

s = s.replace("""\t\t\t\t\tF0D0FDE12FCB319B002EEFF8 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.5;
\t\t\t\t\t};""", f"""\t\t\t\t\tF0D0FDE12FCB319B002EEFF8 = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.5;
\t\t\t\t\t}};
\t\t\t\t\t{ID['target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.6;
\t\t\t\t\t}};""", 1)

P.write_text(s)
print("Target FitnessWatch aggiunto.")
