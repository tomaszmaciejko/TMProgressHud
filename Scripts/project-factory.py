#!/usr/bin/env python3
"""Generate the production framework or isolated distribution-consumer project."""
import argparse
import json
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parent))
from project_format import read_project, write_project

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / "VERSION").read_text().strip()
DEPLOYMENT_TARGETS = json.loads((ROOT / "Scripts/deployment-targets.json").read_text())


class Project:
    def __init__(self):
        self.objects = {}

    def add(self, isa, **values):
        key = f"{len(self.objects) + 1:024X}"
        self.objects[key] = {"isa": isa, **values}
        return key

    def configurations(self, values):
        refs = []
        for name in ["Debug", "Release"]:
            settings = dict(values)
            settings["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if name == "Debug" else "-O"
            refs.append(self.add("XCBuildConfiguration", name=name, buildSettings=settings))
        return self.add("XCConfigurationList", buildConfigurations=refs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")


def synchronize_test_sources(bundle):
    """Replace only managed Swift memberships; preserve targets, resources and reference fixtures."""
    project = read_project(bundle)
    phases = {"TMProgressHudUIKit/compile-sources", "TMProgressHudUIKitTests/compile-sources"}

    def preserved(entries):
        result = []
        for entry in entries:
            if entry.get("kind") == "group":
                children = preserved(entry.get("children", []))
                if children or not entry.get("children"):
                    result.append({**entry, "children": children})
            else:
                memberships = entry.get("target-membership", [])
                owned = [member for member in memberships if (member if isinstance(member, str) else member["build-phase"]) in phases]
                if owned and Path(entry.get("path", "")).suffix == ".swift":
                    if memberships != owned or len(owned) != 1 or not isinstance(owned[0], str):
                        raise ValueError("Cannot replace mixed Swift source membership")
                else:
                    result.append(entry)
        return result

    project["files"] = preserved(project["files"])
    for name, directory, target in (
        ("Swift library sources", "Sources/TMProgressHudUIKit", "TMProgressHudUIKit"),
        ("Swift tests", "Tests/TMProgressHudUIKitTests", "TMProgressHudUIKitTests"),
    ):
        if not (ROOT / directory).is_dir():
            raise ValueError(f"Missing source directory: {directory}")
        children = [
            {"path": os.path.relpath(path, bundle.parent), "target-membership": [target + "/compile-sources"]}
            for path in sorted((ROOT / directory).glob("*.swift"))
        ]
        project["files"].append({"kind": "group", "name": name, "children": children})
    (bundle / "project.xcproj").write_text(json.dumps(project, indent=2, ensure_ascii=False) + "\n")


def generate(output, kind, platform="ios", artifact=None, remote_source=None, project_format=None):
    output = output.resolve()
    if kind == "test-sources":
        synchronize_test_sources(output)
        return
    framework = kind == "framework"
    product_name = "TMProgressHudUIKit" if framework else "TMProgressHudConsumer"
    extension = "framework" if framework else "app"
    project = Project()
    p = project
    file_refs, source_builds, resource_builds = [], [], []
    sources = sorted((ROOT / "Sources/TMProgressHudUIKit").glob("*.swift")) if framework else [ROOT / "Examples/UIKitDemo/DemoApp.swift"]
    resources = [ROOT / "Sources/TMProgressHudUIKit/PrivacyInfo.xcprivacy", *sorted((ROOT / "Sources/TMProgressHudUIKit/Resources").glob("*.txt")), ROOT / "Sources/TMProgressHudUIKit/TMProgressHudUIKit.docc"] if framework else []
    for path in [*sources, *resources]:
        ref = p.add("PBXFileReference", path=os.path.relpath(path, output.parent), sourceTree="<group>", lastKnownFileType="sourcecode.swift" if path.suffix == ".swift" else ("folder.documentationcatalog" if path.suffix == ".docc" else "text"))
        file_refs.append(ref)
        build = p.add("PBXBuildFile", fileRef=ref)
        (source_builds if path in sources else resource_builds).append(build)
    links, embeds, packages, dependencies = [], [], [], []
    if kind == "spm":
        if remote_source:
            package = p.add("XCRemoteSwiftPackageReference", repositoryURL=remote_source["url"], requirement={"kind": "revision", "revision": remote_source["revision"]})
        else:
            package = p.add("XCLocalSwiftPackageReference", relativePath=os.path.relpath(ROOT, output.parent))
        packages.append(package)
        dependency = p.add("XCSwiftPackageProductDependency", package=package, productName="TMProgressHudUIKit")
        dependencies.append(dependency)
        links.append(p.add("PBXBuildFile", productRef=dependency))
    if kind in ["binary", "carthage"]:
        ref = p.add("PBXFileReference", path=str(artifact.resolve()), sourceTree="<absolute>", lastKnownFileType="wrapper.xcframework")
        file_refs.append(ref)
        links.append(p.add("PBXBuildFile", fileRef=ref))
        embeds.append(p.add("PBXBuildFile", fileRef=ref, settings={"ATTRIBUTES": ["CodeSignOnCopy", "RemoveHeadersOnCopy"]}))
    phases = [p.add("PBXSourcesBuildPhase", buildActionMask="2147483647", files=source_builds, runOnlyForDeploymentPostprocessing="0"), p.add("PBXFrameworksBuildPhase", buildActionMask="2147483647", files=links, runOnlyForDeploymentPostprocessing="0"), p.add("PBXResourcesBuildPhase", buildActionMask="2147483647", files=resource_builds, runOnlyForDeploymentPostprocessing="0")]
    if embeds:
        phases.append(p.add("PBXCopyFilesBuildPhase", name="Embed Frameworks", dstPath="", dstSubfolderSpec="10", buildActionMask="2147483647", files=embeds, runOnlyForDeploymentPostprocessing="0"))
    product = p.add("PBXFileReference", path=f"{product_name}.{extension}", sourceTree="BUILT_PRODUCTS_DIR", explicitFileType="wrapper.framework" if framework else "wrapper.application")
    products = p.add("PBXGroup", name="Products", sourceTree="<group>", children=[product])
    group = p.add("PBXGroup", sourceTree="<group>", children=[*file_refs, products])
    settings = {"PRODUCT_NAME": product_name, "PRODUCT_BUNDLE_IDENTIFIER": f"com.github.tomaszmaciejko.{product_name}", "CODE_SIGNING_ALLOWED": "NO", "SWIFT_VERSION": "6.0", "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES", "CLANG_ENABLE_MODULES": "YES", "GENERATE_INFOPLIST_FILE": "YES", "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGETS["ios"], "TVOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGETS["tvos"], "MARKETING_VERSION": VERSION, "CURRENT_PROJECT_VERSION": "1", "SUPPORTS_MACCATALYST": "NO"}
    if framework:
        settings.update({"SUPPORTED_PLATFORMS": "iphoneos iphonesimulator appletvos appletvsimulator", "TARGETED_DEVICE_FAMILY": "1,2", "TARGETED_DEVICE_FAMILY[sdk=appletv*]": "3", "DEFINES_MODULE": "YES", "DYLIB_INSTALL_NAME_BASE": "@rpath", "SKIP_INSTALL": "NO", "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES", "APPLICATION_EXTENSION_API_ONLY": "YES", "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"})
    else:
        settings.update({"SUPPORTED_PLATFORMS": "appletvos appletvsimulator" if platform == "tvos" else "iphoneos iphonesimulator", "TARGETED_DEVICE_FAMILY": "3" if platform == "tvos" else "1,2", "INFOPLIST_FILE": str(ROOT / "Examples/UIKitDemo" / ("Info-tvOS.plist" if platform == "tvos" else "Info.plist")), "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]})
    target = p.add("PBXNativeTarget", name=product_name, productName=product_name, productReference=product, productType="com.apple.product-type.framework" if framework else "com.apple.product-type.application", buildConfigurationList=p.configurations(settings), buildPhases=phases, dependencies=[], buildRules=[], packageProductDependencies=dependencies)
    root = p.add("PBXProject", attributes={"LastUpgradeCheck": "1600"}, buildConfigurationList=p.configurations({"SDKROOT": "appletvos" if platform == "tvos" else "iphoneos"}), compatibilityVersion="Xcode 14.0", developmentRegion="en", knownRegions=["en", "Base"], mainGroup=group, productRefGroup=products, projectDirPath="", projectRoot="", targets=[target], packageReferences=packages)
    output.mkdir(parents=True, exist_ok=True)
    # Disposable consumers retain compatibility with CocoaPods and older Xcode.
    project_format = project_format or ("json" if framework else "plist")
    write_project(output, {"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": p.objects, "rootObject": root}, project_format)
    scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
    ET.SubElement(entry, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=target, BuildableName=f"{product_name}.{extension}", BlueprintName=product_name, ReferencedContainer=f"container:{output.name}")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    schemes = output / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(scheme).write(schemes / f"{product_name}.xcscheme", encoding="UTF-8", xml_declaration=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["framework", "spm", "cocoapods", "binary", "carthage", "test-sources"])
    parser.add_argument("output", type=Path)
    parser.add_argument("--platform", choices=["ios", "tvos"], default="ios")
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--format", choices=["json", "plist"], help="Defaults to JSON for the framework; plist for disposable compatibility consumers")
    args = parser.parse_args()
    if args.kind in ["binary", "carthage"] and args.artifact is None:
        parser.error("Binary consumers require --artifact")
    generate(args.output.resolve(), args.kind, args.platform, args.artifact, project_format=args.format)
