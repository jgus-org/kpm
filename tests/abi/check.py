import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from elftools.common.exceptions import ELFError
from elftools.elf.constants import E_FLAGS
from elftools.elf.elffile import ELFFile


@dataclass(frozen=True)
class Fixture:
    path: Path
    float_abi: str
    glibc: str
    kernel: str


def read_configuration(path: Path) -> tuple[list[dict], dict[str, Fixture], dict]:
    raw = json.loads(path.read_text())
    fixtures = {
        platform: Fixture(
            path=Path(value["path"]),
            float_abi=value["floatAbi"],
            glibc=value["glibc"],
            kernel=value["kernel"],
        )
        for platform, value in raw["fixtures"].items()
    }
    return raw["artifacts"], fixtures, raw["emulationRuntimes"]


def artifact_key(artifact: dict) -> str:
    return f"{artifact['id']}-{'-'.join(artifact['platforms'])}"


def extract_archive(archive: Path, destination: Path) -> None:
    with tarfile.open(archive, "r:gz") as package:
        package.extractall(destination, filter="data")


def elf_metadata(path: Path) -> dict | None:
    try:
        with path.open("rb") as stream:
            if stream.read(4) != b"\x7fELF":
                return None
            stream.seek(0)
            elf = ELFFile(stream)
            if elf["e_machine"] != "EM_ARM":
                return {
                    "path": str(path),
                    "machine": elf["e_machine"],
                    "status": "failed",
                    "reason": "non-ARM ELF in Kindle artifact",
                }
            flags = elf["e_flags"]
            if flags & E_FLAGS.EF_ARM_ABI_FLOAT_HARD:
                float_abi = "hard"
            elif flags & E_FLAGS.EF_ARM_ABI_FLOAT_SOFT:
                float_abi = "soft"
            else:
                float_abi = "unspecified"
            interpreter = None
            for segment in elf.iter_segments():
                if segment["p_type"] == "PT_INTERP":
                    interpreter = segment.get_interp_name()
                    break
            needed = []
            rpath = []
            runpath = []
            required_versions = {}
            provided_versions = []
            soname = None
            dynamic = elf.get_section_by_name(".dynamic")
            if dynamic is not None:
                needed = sorted(
                    tag.needed
                    for tag in dynamic.iter_tags()
                    if tag.entry.d_tag == "DT_NEEDED"
                )
                for tag in dynamic.iter_tags():
                    if tag.entry.d_tag == "DT_RPATH":
                        rpath.extend(tag.rpath.split(":"))
                    elif tag.entry.d_tag == "DT_RUNPATH":
                        runpath.extend(tag.runpath.split(":"))
                    elif tag.entry.d_tag == "DT_SONAME":
                        soname = tag.soname
            version_requirements = elf.get_section_by_name(".gnu.version_r")
            if version_requirements is not None:
                required_versions = {
                    version.name: sorted(auxiliary.name for auxiliary in auxiliaries)
                    for version, auxiliaries in version_requirements.iter_versions()
                }
            version_definitions = elf.get_section_by_name(".gnu.version_d")
            if version_definitions is not None:
                provided_versions = sorted(
                    {
                        auxiliary.name
                        for _, auxiliaries in version_definitions.iter_versions()
                        for auxiliary in auxiliaries
                    }
                )
            return {
                "path": str(path),
                "machine": "ARM",
                "type": elf["e_type"],
                "floatAbi": float_abi,
                "interpreter": interpreter,
                "needed": needed,
                "providedVersions": provided_versions,
                "requiredVersions": required_versions,
                "rpath": rpath,
                "runpath": runpath,
                "soname": soname,
            }
    except (OSError, EOFError, ValueError, ELFError):
        return {
            "path": str(path),
            "machine": "unreadable",
            "status": "failed",
            "reason": "invalid ELF data",
        }


def expected_float_abis(platforms: list[str], fixtures: dict[str, Fixture]) -> set[str]:
    return {
        fixtures[platform].float_abi for platform in platforms if platform in fixtures
    }


def find_fixture_path(fixture: Fixture, absolute_path: str) -> Path | None:
    candidate = fixture.path / absolute_path.lstrip("/")
    if candidate.exists():
        return candidate
    basename = Path(absolute_path).name
    matches = sorted(fixture.path.glob(f"**/{basename}"))
    return matches[0] if matches else None


def expand_library_path(value: str, executable: Path, package_root: Path) -> Path:
    expanded = value.replace("${ORIGIN}", str(executable.parent)).replace(
        "$ORIGIN", str(executable.parent)
    )
    path = Path(expanded)
    return path if path.is_absolute() else package_root / path


def expand_embedded_path(
    value: str,
    consumer: Path,
    package_root: Path,
    fixture: Fixture,
) -> Path:
    if "$ORIGIN" in value or "${ORIGIN}" in value:
        return Path(
            value.replace("${ORIGIN}", str(consumer.parent)).replace(
                "$ORIGIN", str(consumer.parent)
            )
        )
    path = Path(value)
    if path.is_absolute():
        return fixture.path / str(path).lstrip("/")
    return package_root / path


def normalize_detail(
    detail: str,
    package_root: Path,
    work_directory: Path | None,
    fixture: Fixture,
) -> str:
    replacements = {
        str(package_root): "$PACKAGE_ROOT",
        str(fixture.path): "$SYSROOT",
    }
    if work_directory is not None:
        replacements[str(work_directory)] = "$WORK_DIRECTORY"
    for source, replacement in replacements.items():
        detail = detail.replace(source, replacement)
    return re.sub(r"0x[0-9a-fA-F]+", "<address>", detail)


def normalize_dependencies(
    output: str,
    package_root: Path,
    fixture: Fixture,
) -> list[dict[str, str]]:
    dependencies = []
    for line in output.splitlines():
        value = re.sub(r"\s+\(0x[0-9a-fA-F]+\)$", "", line.strip())
        if " => " in value:
            name, provider = value.split(" => ", 1)
        else:
            name, provider = value, "virtual"
        provider = normalize_detail(provider, package_root, None, fixture)
        dependencies.append({"name": name, "provider": provider})
    return sorted(
        dependencies,
        key=lambda dependency: (dependency["name"], dependency["provider"]),
    )


def fixture_library_paths(fixture: Fixture) -> list[Path]:
    candidates = [
        fixture.path / "lib",
        fixture.path / "usr/lib",
        fixture.path / "lib/arm-linux-gnueabi",
        fixture.path / "usr/lib/arm-linux-gnueabi",
        fixture.path / "lib/arm-linux-gnueabihf",
        fixture.path / "usr/lib/arm-linux-gnueabihf",
    ]
    return [path for path in candidates if path.exists()]


def resolve_runtime_path(path: Path, package_root: Path, fixture: Fixture) -> Path:
    for _ in range(16):
        if not path.is_symlink():
            return path
        target = Path(os.readlink(path))
        if target.is_absolute():
            root = fixture.path if path.is_relative_to(fixture.path) else package_root
            path = root / str(target).lstrip("/")
        else:
            path = path.parent / target
    return path


def dependency_coverage(
    path: Path,
    metadata: dict,
    fixture: Fixture,
    package_root: Path,
    context: dict | None,
) -> dict | None:
    loader_kind = (context or {}).get("loader", {"kind": "fixture"})["kind"]
    package_paths = [
        expand_library_path(value, path, package_root)
        for value in (context or {}).get("libraryPaths", [])
    ]
    absent_paths = [
        str(directory.relative_to(package_root))
        for directory in package_paths
        if directory.is_relative_to(package_root) and not directory.is_dir()
    ]
    if absent_paths:
        return {
            "path": metadata["path"],
            "status": "failed",
            "reason": f"declared library path is absent: {', '.join(absent_paths)}",
        }
    queue = [(path, metadata)]
    examined = set()
    missing_providers = set()
    version_gaps = set()
    providers = set()
    while queue:
        consumer_path, consumer = queue.pop()
        rpath = [
            expand_embedded_path(value, consumer_path, package_root, fixture)
            for value in consumer["rpath"]
        ]
        runpath = [
            expand_embedded_path(value, consumer_path, package_root, fixture)
            for value in consumer["runpath"]
        ]
        search_paths = [*rpath, *package_paths, *runpath]
        if loader_kind == "fixture" or (context or {}).get(
            "includeFixtureLibraries", False
        ):
            search_paths.extend(fixture_library_paths(fixture))
        for needed in consumer["needed"]:
            provider = next(
                (
                    directory / needed
                    for directory in search_paths
                    if (directory / needed).exists()
                ),
                None,
            )
            if provider is None:
                missing_providers.add(needed)
                continue
            provider = resolve_runtime_path(provider, package_root, fixture)
            provider_key = str(provider)
            required = set(consumer["requiredVersions"].get(needed, []))
            provider_metadata = elf_metadata(provider)
            if provider_metadata is None or provider_metadata.get("machine") != "ARM":
                return {
                    "path": metadata["path"],
                    "status": "failed",
                    "reason": f"runtime provider is not ARM ELF: {needed}",
                }
            provider_abi = provider_metadata["floatAbi"]
            if provider_abi not in (fixture.float_abi, "unspecified"):
                return {
                    "path": metadata["path"],
                    "status": "failed",
                    "reason": (
                        f"{provider_abi}-float provider {needed} selected for "
                        f"{fixture.float_abi}-float runtime"
                    ),
                }
            provided = set(provider_metadata["providedVersions"])
            missing_versions = sorted(required - provided)
            normalized_provider = normalize_detail(
                str(provider), package_root, None, fixture
            )
            providers.add((needed, normalized_provider))
            if missing_versions:
                version_gaps.add(
                    (
                        needed,
                        normalized_provider,
                        tuple(missing_versions),
                        tuple(sorted(provided)),
                    )
                )
            if provider_key not in examined:
                examined.add(provider_key)
                queue.append((provider, provider_metadata))
    if missing_providers or version_gaps:
        status = "failed" if loader_kind == "package" else "missing"
        return {
            "path": metadata["path"],
            "status": status,
            "reason": "representative runtime provider coverage is incomplete",
            "missingProviders": sorted(missing_providers),
            "versionGaps": [
                {
                    "library": library,
                    "provider": provider,
                    "required": list(required),
                    "provided": list(provided),
                }
                for library, provider, required, provided in sorted(version_gaps)
            ],
        }
    return {
        "providers": [
            {"library": library, "provider": provider}
            for library, provider in sorted(providers)
        ]
    }


def runtime_probe(
    path: Path,
    metadata: dict,
    fixture: Fixture,
    package_root: Path,
    context: dict | None,
    fixture_available: bool,
) -> dict:
    interpreter = metadata["interpreter"]
    if interpreter is None:
        return {
            "path": metadata["path"],
            "status": "passed",
            "reason": "static executable",
        }
    loader_kind = "fixture"
    if context is None:
        loader = find_fixture_path(fixture, interpreter)
        declared_library_paths = []
    else:
        loader_configuration = context.get("loader", {"kind": "fixture"})
        loader_kind = loader_configuration["kind"]
        if loader_kind == "fixture":
            loader = find_fixture_path(
                fixture, loader_configuration.get("path", interpreter)
            )
        elif loader_kind == "package":
            loader = package_root / loader_configuration["path"]
            if not loader.is_file():
                return {
                    "path": metadata["path"],
                    "status": "failed",
                    "reason": f"declared loader is absent: {loader_configuration['path']}",
                }
        else:
            return {
                "path": metadata["path"],
                "status": "failed",
                "reason": f"unknown loader kind: {loader_kind}",
            }
        declared_library_paths = context.get("libraryPaths", [])
    if loader_kind == "fixture" and not fixture_available:
        return {
            "path": metadata["path"],
            "status": "missing",
            "reason": "QEMU cannot execute the selected runtime fixture loader",
        }
    if loader is None:
        return {
            "path": metadata["path"],
            "status": "missing",
            "reason": f"fixture does not provide interpreter {interpreter}",
        }
    library_paths = [
        expand_library_path(value, path, package_root)
        for value in declared_library_paths
    ]
    absent_paths = [
        str(directory.relative_to(package_root))
        for directory in library_paths
        if directory.is_relative_to(package_root) and not directory.is_dir()
    ]
    if absent_paths:
        return {
            "path": metadata["path"],
            "status": "failed",
            "reason": f"declared library path is absent: {', '.join(absent_paths)}",
        }
    library_directories = [str(directory) for directory in library_paths]
    if loader_kind == "fixture" or (context or {}).get(
        "includeFixtureLibraries", False
    ):
        library_directories.extend(
            str(directory) for directory in fixture_library_paths(fixture)
        )
    command = ["qemu-arm", str(loader)]
    if library_directories:
        command.extend(["--library-path", ":".join(library_directories)])
    command.extend(["--list", str(path)])
    try:
        result = subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=30,
        )
    except subprocess.TimeoutExpired:
        return {
            "path": metadata["path"],
            "status": "failed",
            "reason": "runtime dependency probe timed out",
        }
    if result.returncode == 0:
        if loader.is_relative_to(fixture.path):
            loader_name = str(loader.relative_to(fixture.path))
        else:
            loader_name = str(loader.relative_to(package_root))
        return {
            "path": metadata["path"],
            "status": "passed",
            "loader": loader_name,
            "dependencies": normalize_dependencies(
                result.stdout, package_root, fixture
            ),
        }
    detail = normalize_detail(
        (result.stderr or result.stdout).strip(), package_root, None, fixture
    )
    missing_provider = bool(
        re.search(
            r"cannot open shared object file|version [`'][^`']+[`'] not found",
            detail,
        )
    )
    result_status = (
        "missing" if loader_kind == "fixture" and missing_provider else "failed"
    )
    return {
        "path": metadata["path"],
        "status": result_status,
        "reason": detail or "runtime dependency closure is unavailable",
    }


def relative_metadata(metadata: dict, root: Path) -> dict:
    result = dict(metadata)
    result["path"] = str(Path(metadata["path"]).relative_to(root))
    return result


def run_functional_test(
    test: dict,
    package_root: Path,
    work_directory: Path,
    platform: str,
    fixture: Fixture,
    emulation_runtimes: dict,
) -> dict:
    environment = os.environ.copy()
    environment.update(
        {
            "KPM_ABI_PACKAGE_ROOT": str(package_root),
            "KPM_ABI_PLATFORM": platform,
            "KPM_ABI_QEMU": shutil.which("qemu-arm") or "qemu-arm",
            "KPM_ABI_SYSROOT": str(fixture.path),
            "KPM_ABI_WORK_DIRECTORY": str(work_directory),
        }
    )
    runtime_name = test.get("runtime")
    if runtime_name is not None:
        runtime = emulation_runtimes[runtime_name]
        environment.update(
            {
                "KPM_ABI_EMULATION_LIBRARY_PATH": ":".join(runtime["libraryPaths"]),
                "KPM_ABI_EMULATION_LOADER": runtime["loader"],
            }
        )
    try:
        result = subprocess.run(
            [test["script"]],
            cwd=work_directory,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "failed",
            "reason": "functional operation timed out",
        }
    detail = normalize_detail(
        (result.stdout + result.stderr).strip(), package_root, work_directory, fixture
    )
    if result.returncode == 0:
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "passed",
            "detail": detail,
        }
    if result.returncode == 77 and detail:
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "missing",
            "reason": detail,
        }
    if result.returncode == 77:
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "failed",
            "reason": "missing coverage result did not provide a reason",
        }
    return {
        "name": test["name"],
        "runtime": runtime_name,
        "status": "failed",
        "reason": detail or f"test exited with status {result.returncode}",
    }


def functional_test_result(
    test: dict,
    package_root: Path,
    work_directory: Path,
    platform: str,
    fixture: Fixture,
    fixture_result: dict,
    emulation_runtimes: dict,
    emulation_results: dict[str, dict],
) -> dict:
    runtime_name = test.get("runtime")
    script = Path(test["script"])
    if not script.is_file():
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "failed",
            "reason": "declared functional test script is absent",
        }
    if not os.access(script, os.X_OK):
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "failed",
            "reason": "declared functional test script is not executable",
        }
    if runtime_name is None and fixture_result["status"] != "passed":
        return {
            "name": test["name"],
            "runtime": None,
            "status": "missing",
            "reason": "QEMU cannot execute the selected reference fixture loader",
        }
    if runtime_name is not None and runtime_name not in emulation_runtimes:
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "failed",
            "reason": f"unknown emulation runtime: {runtime_name}",
        }
    if (
        runtime_name is not None
        and emulation_results[runtime_name]["status"] == "missing"
    ):
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "missing",
            "reason": emulation_results[runtime_name]["reason"],
        }
    if (
        runtime_name is not None
        and emulation_results[runtime_name]["status"] != "passed"
    ):
        return {
            "name": test["name"],
            "runtime": runtime_name,
            "status": "failed",
            "reason": "selected emulation runtime failed its health check",
        }
    return run_functional_test(
        test,
        package_root,
        work_directory,
        platform,
        fixture,
        emulation_runtimes,
    )


def summarize_layers(
    artifacts: list[dict],
    fixture_results: list[dict],
    emulation_results: list[dict],
) -> dict:
    layers = {
        "fixtures": Counter(result["status"] for result in fixture_results),
        "emulationRuntimes": Counter(result["status"] for result in emulation_results),
        "inventory": Counter(),
        "runtime": Counter(),
        "functional": Counter(),
    }
    for artifact in artifacts:
        for layer in ("inventory", "runtime", "functional"):
            layers[layer].update(item["status"] for item in artifact[layer])
    return {
        layer: {
            status: counts.get(status, 0) for status in ("passed", "missing", "failed")
        }
        for layer, counts in layers.items()
    }


def check_artifact(
    artifact: dict,
    fixtures: dict[str, Fixture],
    fixture_results: dict[str, dict],
    emulation_runtimes: dict,
    emulation_results: dict[str, dict],
    scratch: Path,
) -> dict:
    key = artifact_key(artifact)
    package_root = scratch / key / "package"
    work_directory = scratch / key / "work"
    package_root.mkdir(parents=True)
    work_directory.mkdir(parents=True)
    extract_archive(Path(artifact["archive"]), package_root)
    expected = expected_float_abis(artifact["platforms"], fixtures)
    raw_metadata = [
        metadata
        for path in sorted(package_root.rglob("*"))
        if path.is_file() and (metadata := elf_metadata(path)) is not None
    ]
    inventory = []
    arm_metadata = []
    for metadata in raw_metadata:
        metadata = relative_metadata(metadata, package_root)
        if metadata.get("machine") != "ARM":
            if metadata.get("status") == "failed":
                inventory.append(metadata)
            continue
        arm_metadata.append(metadata)
        result = dict(metadata)
        if not expected:
            result.update(
                status="missing",
                reason="artifact platforms do not select one available runtime ABI fixture",
            )
        elif metadata["type"] == "ET_REL":
            result.update(status="passed", reason="ARM relocatable object inventoried")
        elif metadata["floatAbi"] == "unspecified":
            result.update(
                status="missing",
                reason="ELF header does not declare a float ABI",
            )
        elif metadata["floatAbi"] not in expected:
            result.update(
                status="failed",
                reason=(
                    f"{metadata['floatAbi']}-float ELF in artifact supporting "
                    f"{', '.join(sorted(expected))}-float ABIs"
                ),
            )
        else:
            result["status"] = "passed"
        inventory.append(result)
    runtime = []
    known_paths = {metadata["path"] for metadata in arm_metadata}
    runtime_contexts = {}
    for context in artifact["runtimeContexts"]:
        if "path" in context:
            matching_paths = {context["path"]} & known_paths
            selector = context["path"]
        else:
            selector = context["pathPrefix"]
            matching_paths = {path for path in known_paths if path.startswith(selector)}
        if not matching_paths:
            runtime.append(
                {
                    "path": selector,
                    "status": "failed",
                    "reason": "declared runtime payload selector matches no ARM ELF",
                }
            )
        for matching_path in matching_paths:
            runtime_contexts[matching_path] = context
    fixtures_by_abi = {
        fixture.float_abi: (platform, fixture)
        for platform, fixture in fixtures.items()
        if platform in artifact["platforms"]
    }
    for metadata in arm_metadata:
        if metadata["type"] not in ("ET_EXEC", "ET_DYN"):
            continue
        if metadata["type"] == "ET_DYN" and metadata["interpreter"] is None:
            continue
        fixture_selection = fixtures_by_abi.get(metadata["floatAbi"])
        if fixture_selection is None:
            runtime.append(
                {
                    "path": metadata["path"],
                    "status": "missing",
                    "reason": "no single runtime fixture applies to this artifact",
                }
            )
            continue
        platform, fixture = fixture_selection
        executable = package_root / metadata["path"]
        context = runtime_contexts.get(metadata["path"])
        coverage = dependency_coverage(
            executable,
            metadata,
            fixture,
            package_root,
            context,
        )
        if coverage is not None and "status" in coverage:
            runtime.append(coverage)
            continue
        probe = runtime_probe(
            executable,
            metadata,
            fixture,
            package_root,
            context,
            fixture_results[platform]["status"] == "passed",
        )
        if coverage is not None and "providers" in coverage:
            probe["providers"] = coverage["providers"]
        runtime.append(probe)
    functional = []
    if artifact["functionalTests"]:
        if len(artifact["platforms"]) != 1 or artifact["platforms"][0] not in fixtures:
            functional = [
                {
                    "name": test["name"],
                    "status": "missing",
                    "reason": "no single runtime fixture applies to this artifact",
                }
                for test in artifact["functionalTests"]
            ]
        else:
            fixture = fixtures[artifact["platforms"][0]]
            functional = [
                functional_test_result(
                    test,
                    package_root,
                    work_directory,
                    artifact["platforms"][0],
                    fixture,
                    fixture_results[artifact["platforms"][0]],
                    emulation_runtimes,
                    emulation_results,
                )
                for test in artifact["functionalTests"]
            ]
    elif arm_metadata:
        functional = [
            {
                "name": "package-operation",
                "status": "missing",
                "reason": "package has ARM payloads but declares no emulated functional operation",
            }
        ]
    return {
        "id": artifact["id"],
        "key": key,
        "platforms": artifact["platforms"],
        "inventory": inventory,
        "runtime": runtime,
        "functional": functional,
    }


def check_fixture(platform: str, fixture: Fixture) -> dict:
    interpreter = (
        "/lib/ld-linux-armhf.so.3"
        if fixture.float_abi == "hard"
        else "/lib/ld-linux.so.3"
    )
    loader = find_fixture_path(fixture, interpreter)
    if loader is None:
        return {
            "platform": platform,
            "status": "failed",
            "reason": f"fixture interpreter is absent: {interpreter}",
        }
    try:
        result = subprocess.run(
            ["qemu-arm", str(loader), "--list", str(loader)],
            text=True,
            capture_output=True,
            check=False,
            timeout=30,
        )
    except subprocess.TimeoutExpired:
        return {
            "platform": platform,
            "status": "failed",
            "reason": "fixture loader health probe timed out",
            "loader": str(loader.relative_to(fixture.path)),
            "glibc": fixture.glibc,
            "kernel": fixture.kernel,
        }
    if result.returncode == 0:
        return {
            "platform": platform,
            "status": "passed",
            "loader": str(loader.relative_to(fixture.path)),
            "glibc": fixture.glibc,
            "kernel": fixture.kernel,
        }
    detail = (result.stderr or result.stdout).strip()
    return {
        "platform": platform,
        "status": "missing",
        "reason": detail or f"QEMU exited with status {result.returncode}",
        "loader": str(loader.relative_to(fixture.path)),
        "glibc": fixture.glibc,
        "kernel": fixture.kernel,
    }


def check_emulation_runtime(name: str, runtime: dict) -> dict:
    if "unavailableReason" in runtime:
        return {
            "name": name,
            "status": "missing",
            "reason": runtime["unavailableReason"],
        }
    command = ["qemu-arm", runtime["loader"]]
    if runtime["libraryPaths"]:
        command.extend(["--library-path", ":".join(runtime["libraryPaths"])])
    command.extend(["--list", runtime["loader"]])
    try:
        result = subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=30,
        )
    except subprocess.TimeoutExpired:
        return {
            "name": name,
            "status": "failed",
            "reason": "emulation runtime health probe timed out",
        }
    if result.returncode == 0:
        return {"name": name, "status": "passed"}
    return {
        "name": name,
        "status": "failed",
        "reason": (result.stderr or result.stdout).strip()
        or f"QEMU exited with status {result.returncode}",
    }


def main() -> int:
    configuration = Path(sys.argv[1])
    output = Path(sys.argv[2])
    artifacts, fixtures, emulation_runtimes = read_configuration(configuration)
    fixture_results = {
        platform: check_fixture(platform, fixture)
        for platform, fixture in fixtures.items()
    }
    emulation_results = {
        name: check_emulation_runtime(name, runtime)
        for name, runtime in emulation_runtimes.items()
    }
    output.mkdir(parents=True)
    artifact_output = output / "artifacts"
    artifact_output.mkdir()
    with tempfile.TemporaryDirectory() as temporary_directory:
        scratch = Path(temporary_directory)
        results = [
            check_artifact(
                artifact,
                fixtures,
                fixture_results,
                emulation_runtimes,
                emulation_results,
                scratch,
            )
            for artifact in artifacts
        ]
    report = {
        "schemaVersion": 1,
        "summary": summarize_layers(
            results,
            list(fixture_results.values()),
            list(emulation_results.values()),
        ),
        "fixtures": list(fixture_results.values()),
        "emulationRuntimes": list(emulation_results.values()),
        "artifacts": results,
    }
    failed = any(
        result["status"] == "failed"
        for results_by_name in (fixture_results, emulation_results)
        for result in results_by_name.values()
    ) or any(
        item["status"] == "failed"
        for result in results
        for layer in ("inventory", "runtime", "functional")
        for item in result[layer]
    )
    for result in results:
        (artifact_output / f"{result['key']}.json").write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n"
        )
    (output / "report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    if failed:
        print(json.dumps(report, indent=2, sort_keys=True))
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
