"""Serialize the project's generated PBX subset as Xcode JSON; read JSON5 edits."""
import json
import subprocess

PHASE_KINDS = {
    "PBXSourcesBuildPhase": "compile-sources",
    "PBXFrameworksBuildPhase": "frameworks",
    "PBXResourcesBuildPhase": "resources",
    "PBXCopyFilesBuildPhase": "copy",
}


def read_project(bundle):
    if (bundle / "project.pbxproj").exists():
        raise ValueError(f"Expected JSON only, found legacy configuration in {bundle}")
    path = bundle / "project.xcproj"
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        # Xcode may write comments and trailing commas; Foundation parses JSON5.
        reader = '''import Foundation
let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let object = try JSONSerialization.jsonObject(with: bytes, options: .json5Allowed)
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: object))
'''
        return json.loads(subprocess.check_output(["xcrun", "swift", "-e", reader, str(path)], timeout=60))


def build_settings(objects, configuration_list):
    configurations = [objects[key] for key in objects[configuration_list]["buildConfigurations"]]
    keys = sorted({key for config in configurations for key in config["buildSettings"]})
    result = {}
    for key in keys:
        values = [config["buildSettings"].get(key) for config in configurations]
        if values[0] is not None and all(value == values[0] for value in values):
            result[key] = values[0]
        else:
            for config, value in zip(configurations, values):
                if value is not None:
                    result[f"{key}[config={config['name']}]"] = value
    return result


def json_project(legacy):
    """Translate only constructs used by our generator and maintained projects.

    This is not a general-purpose pbxproj converter. Xcode build settings and
    source-membership comparisons verify each migration independently.
    """
    objects = legacy["objects"]
    project = objects[legacy["rootObject"]]
    memberships = {}
    targets = []
    for target_id in project["targets"]:
        target = objects[target_id]
        if target["isa"] != "PBXNativeTarget" or target.get("buildRules"):
            raise ValueError("Only native targets without custom build rules are supported")
        phases, package_members = [], []
        for phase_id in target["buildPhases"]:
            phase = objects[phase_id]
            kind = PHASE_KINDS[phase["isa"]]
            relative = kind + ("/" + phase["name"] if phase.get("name") else "")
            description = {"kind": kind}
            if phase.get("name"):
                description["name"] = phase["name"]
            if kind == "copy":
                if str(phase["dstSubfolderSpec"]) != "10":
                    raise ValueError("Only framework copy destinations are supported")
                description.update({"bundle-base-path": "frameworks-directory", "relative-path": phase.get("dstPath", "")})
            if str(phase.get("runOnlyForDeploymentPostprocessing", 0)) == "1":
                description["scope"] = "install"
            phases.append(description if len(description) > 1 else kind)
            for build_id in phase.get("files", []):
                build = objects[build_id]
                member = {"build-phase": target["name"] + "/" + relative}
                settings = build.get("settings", {})
                attributes = settings.get("ATTRIBUTES", [])
                unsupported = set(settings) - {"ATTRIBUTES", "COMPILER_FLAGS"}
                if unsupported or set(attributes) - {"RemoveHeadersOnCopy", "CodeSignOnCopy", "Public", "Private", "Weak"}:
                    raise ValueError(f"Unsupported build file settings: {settings}")
                if "RemoveHeadersOnCopy" in attributes:
                    member["header-preservation"] = "remove-on-copy"
                if "CodeSignOnCopy" in attributes:
                    member["code-sign-on-copy"] = True
                if "Weak" in attributes:
                    member["is-weak"] = True
                for role in ["Public", "Private"]:
                    if role in attributes:
                        member["header-role"] = role.lower()
                if "COMPILER_FLAGS" in settings:
                    member["arguments"] = settings["COMPILER_FLAGS"]
                if "productRef" in build:
                    product = objects[build["productRef"]]
                    package_members.append({"product-name": product["productName"], "build-phase": {"build-phase": relative}})
                else:
                    memberships.setdefault(build["fileRef"], []).append(member if len(member) > 1 else member["build-phase"])
        product = objects[target["productReference"]]
        dependencies = [objects[objects[key]["target"]]["name"] for key in target.get("dependencies", [])]
        dependencies += [{"kind": "package", "product-name": objects[key]["productName"]} for key in target.get("packageProductDependencies", [])]
        targets.append({"name": target["name"], "id": target_id,
                        "product": "Products/" + product["path"],
                        "product-type": target["productType"].removeprefix("com.apple.product-type."), "dependencies": dependencies,
                        "build-phases": phases, "package-product-members": package_members,
                        "build-settings": build_settings(objects, target["buildConfigurationList"])})

    def reference(key):
        item = objects[key]
        path = item.get("path", "")
        base = item.get("sourceTree", "<group>")
        prefixes = {"<group>": "", "<absolute>": "", "BUILT_PRODUCTS_DIR": "<PRODUCTS>/", "SOURCE_ROOT": "<PROJECT>/", "SDKROOT": "<SDK>/"}
        result = {"path": prefixes[base] + path} if path else {}
        if item["isa"] == "PBXGroup":
            result.update({"kind": "group", "children": [reference(child) for child in item.get("children", [])]})
            if item.get("name"):
                result["name"] = item["name"]
        elif item["isa"] == "PBXFileReference":
            if "explicitFileType" in item:
                result["type"] = item["explicitFileType"]
            if memberships.get(key):
                result["target-membership"] = memberships[key]
        else:
            raise ValueError(f"Unsupported file reference: {item['isa']}")
        return result

    packages = []
    for key in project.get("packageReferences", []):
        package = objects[key]
        if package["isa"] == "XCLocalSwiftPackageReference":
            packages.append({"kind": "local", "path": package["relativePath"]})
        else:
            requirement = package["requirement"]
            if requirement["kind"] != "revision":
                raise ValueError("Only pinned remote package revisions are supported")
            packages.append({"kind": "remote", "repository": package["repositoryURL"], "version": {"revision": requirement["revision"]}})
    configuration_list = objects[project["buildConfigurationList"]]
    return {"default-configuration": configuration_list["defaultConfigurationName"],
            "configurations": [objects[key]["name"] for key in configuration_list["buildConfigurations"]],
            "localizations": {"development": project["developmentRegion"], "supported": project["knownRegions"]},
            "packages": packages,
            "files": [reference(key) for key in objects[project["mainGroup"]]["children"]],
            "targets": targets, "build-settings": build_settings(objects, project["buildConfigurationList"])}


def write_project(output, legacy, project_format):
    import plistlib
    output.mkdir(parents=True, exist_ok=True)
    if project_format == "json":
        content = json.dumps(json_project(legacy), indent=2, ensure_ascii=False) + "\n"
        (output / "project.xcproj").write_text(content)
        (output / "project.pbxproj").unlink(missing_ok=True)
    elif project_format == "plist":
        (output / "project.pbxproj").write_bytes(plistlib.dumps(legacy, sort_keys=False))
        (output / "project.xcproj").unlink(missing_ok=True)
    else:
        raise ValueError(f"Unknown project format: {project_format}")


def compiled_swift_sources(project, project_root, target_name):
    """Resolve explicit source membership, rejecting ambiguous/unsupported layouts."""
    if sum(target["name"] == target_name for target in project["targets"]) != 1:
        raise ValueError(f"Expected exactly one target: {target_name}")
    sources = set()

    def visit(entries, parent):
        for entry in entries:
            raw = entry.get("path", "")
            if raw.startswith("<PRODUCTS>/") or raw.startswith("<SDK>/"):
                continue
            path = project_root / raw.removeprefix("<PROJECT>/") if raw.startswith("<PROJECT>/") else parent / raw
            kind = entry.get("kind", "file-reference")
            if kind == "group":
                visit(entry.get("children", []), path)
            elif kind == "file-reference":
                for membership in entry.get("target-membership", []):
                    phase = membership if isinstance(membership, str) else membership["build-phase"]
                    if phase == target_name + "/compile-sources" and path.suffix == ".swift":
                        resolved = path.resolve()
                        if resolved in sources:
                            raise ValueError(f"Duplicate compiled source: {resolved}")
                        if not resolved.is_file():
                            raise ValueError(f"Missing compiled source: {resolved}")
                        sources.add(resolved)
            else:
                raise ValueError(f"Unsupported source membership kind: {kind}")
    visit(project["files"], project_root)
    return sources
