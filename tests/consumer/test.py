import json
import shlex
from datetime import timedelta
from pathlib import Path


def command(*arguments: str) -> str:
    return " ".join(shlex.quote(argument) for argument in arguments)


def shell_commands(value: str | list[str] | None) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return value
    raise AssertionError("consumer shell fixture must be a string or a list of strings")


def run_commands(machine, value: str | list[str] | None) -> None:
    for item in shell_commands(value):
        machine.succeed(f"set -eu\n{item}")


def wait_for(machine, shell: str) -> None:
    checked_shell = command("sh", "-eu", "-c", shell)
    machine.wait_until_succeeds(
        "set -u\n"
        f"if ! {checked_shell}; then\n"
        "  for LOG in /var/lib/kpm-consumer/*.log; do\n"
        "    test -e \"${LOG}\" || continue\n"
        "    printf '%s\\n' \"--- ${LOG} ---\" >&2\n"
        "    cat \"${LOG}\" >&2\n"
        "  done\n"
        "  exit 1\n"
        "fi",
        timeout=timedelta(seconds=30),
    )


def installed_count(package_id: str) -> str:
    query = f"SELECT COUNT(*) FROM installed_packages WHERE id = '{package_id}';"
    return (
        "$(sqlite3 /mnt/us/kmc/kpm/kpm.db " + shlex.quote(query) + ")"
    )


def reset_case(machine, platform: str) -> None:
    machine.succeed("rm -rf /mnt/us /var/local /var/lib/kpm-consumer")
    machine.succeed(
        "mkdir -p /mnt/us/extensions /mnt/us/kmc/kpm /mnt/us/documents /var/local /var/lib/kpm-consumer"
    )
    machine.succeed("rm -f /lib/ld-linux-armhf.so.3")
    if platform == "kindlehf":
        machine.succeed("mkdir -p /lib && : > /lib/ld-linux-armhf.so.3")
    machine.succeed("printf '%s\\n' 'Kindle 5.16.2.1.1' > /etc/prettyversion.txt")
    machine.succeed(
        "sqlite3 /var/local/appreg.db "
        "'CREATE TABLE handlerIds(handlerId TEXT PRIMARY KEY); "
        "CREATE TABLE properties(handlerId TEXT, name TEXT, value TEXT);'"
    )


def initialize_kpm(machine, case: dict, config: dict) -> str:
    kpm = config["kpm"][case["platform"]]
    machine.succeed(f"{command(kpm, 'version')} > /var/lib/kpm-consumer/version.txt 2>&1")
    machine.succeed(
        f"grep -F {command('libkpm v' + config['runtime_version'])} "
        "/var/lib/kpm-consumer/version.txt"
    )
    machine.succeed(
        "test \"$(sqlite3 /mnt/us/kmc/kpm/kpm.db "
        "\"SELECT COUNT(*) FROM repositories WHERE id = 'kindlemodding';\")\" = 1"
    )
    machine.succeed(f"{command(kpm, '-y', 'add-repo', config['repository_url'])}")
    return kpm


def validate_launch(launch: dict) -> dict:
    mode = launch["mode"]
    if mode not in {"exec", "dispatch", "maintenance", "none"}:
        raise AssertionError(f"unknown consumer launch mode: {mode}")
    if not isinstance(launch["args"], list) or not all(
        isinstance(argument, str) for argument in launch["args"]
    ):
        raise AssertionError("consumer launch arguments must be strings")
    if not isinstance(launch["boundaries"], list) or not all(
        isinstance(boundary, str) for boundary in launch["boundaries"]
    ):
        raise AssertionError("consumer launch boundaries must be strings")
    if not isinstance(launch.get("pathPrefix", []), list) or not all(
        isinstance(path, str) for path in launch.get("pathPrefix", [])
    ):
        raise AssertionError("consumer launch path prefixes must be strings")
    if mode == "none":
        if not isinstance(launch.get("reason"), str) or not launch["reason"]:
            raise AssertionError("a consumer launch omission requires a reason")
    elif not shell_commands(launch.get("verify")):
        raise AssertionError("a consumer launch requires a verification fixture")
    if mode != "none" and not launch["boundaries"]:
        raise AssertionError("a consumer launch requires an explicit boundary")
    if not isinstance(launch["actualApplicationExecution"], bool):
        raise AssertionError("consumer launch execution state must be boolean")
    if mode == "exec" and launch["actualApplicationExecution"] is not True:
        raise AssertionError("an exec launch must execute the application")
    if mode in {"dispatch", "none"} and launch["actualApplicationExecution"] is not False:
        raise AssertionError("a dispatch or omitted launch cannot execute the application")
    return launch


def launch_command(kpm: str, package_id: str, launch: dict, config: dict) -> str:
    path_prefix = [*launch.get("pathPrefix", []), config["boundary_path"]]
    prefix = ":".join(shlex.quote(path) for path in path_prefix)
    return f"PATH={prefix}:${{PATH}} {command(kpm, 'launch', package_id, *launch['args'])}"


def lifecycle_command(kpm: str, config: dict, *arguments: str) -> str:
    return f"PATH={command(config['boundary_path'])}:${{PATH}} {command(kpm, *arguments)}"


def validate_case(case: dict) -> list[dict]:
    launches = case.get("launches")
    if not isinstance(launches, list) or not launches:
        raise AssertionError("a consumer case requires at least one launch")
    return [validate_launch(launch) for launch in launches]


def report_launch(launch: dict) -> dict:
    return {
        "mode": launch["mode"],
        "args": launch["args"],
        "boundaries": launch["boundaries"],
        "actual_application_execution": launch["actualApplicationExecution"],
    }


def install_case(machine, kpm: str, case: dict, config: dict) -> None:
    package_id = case["artifact"]
    install = f"printf 'y\\n' | {lifecycle_command(kpm, config, 'install', package_id)}"
    log = "/var/lib/kpm-consumer/install-" + package_id + ".log"
    status, _ = machine.execute(f"{install} > {command(log)} 2>&1")
    if status == 0:
        return
    output = machine.succeed(f"cat {command(log)}")
    raise AssertionError(
        f"install for {package_id} on {case['platform']} failed with status {status}: {output}"
    )


def assert_install(machine, case: dict) -> None:
    package_id = case["artifact"]
    package_directory = "/mnt/us/kmc/kpm/packages/" + package_id
    machine.succeed(f"test -d {command(package_directory)}")
    machine.succeed(f"test \"{installed_count(package_id)}\" = 1")
    machine.succeed(f"test -f {command(package_directory + '/manifest.json')}")
    source_directory = "/var/lib/kpm-consumer/archive-" + case["artifact"] + "-" + case["platform"]
    machine.succeed(f"rm -rf {command(source_directory)} && mkdir {command(source_directory)}")
    machine.succeed(f"tar -xzf {command(case['archive'])} -C {command(source_directory)}")
    machine.succeed(f"test -n \"$(find {command(source_directory)} -mindepth 1 -print -quit)\"")
    machine.succeed(
        f"diff -r -x .kpm-install-success {command(source_directory)} {command(package_directory)}"
    )
    scriptlet = case.get("scriptlet")
    if scriptlet is not None:
        machine.succeed(f"test -f {command('/mnt/us/documents/' + scriptlet['name'])}")
    native = case.get("native")
    if native is not None:
        machine.succeed(f"test -f {command(native['marker'])}")
        for scriptlet in native["scriptlets"]:
            machine.succeed(f"test -f {command(scriptlet['destination'])}")
    waf = case.get("waf")
    if waf is not None:
        machine.succeed(f"test -f {command(waf['marker'])}")
        machine.succeed(f"test -f {command('/mnt/us/documents/' + waf['scriptletName'])}")
        query = f"SELECT COUNT(*) FROM handlerIds WHERE handlerId = '{waf['appId']}';"
        machine.succeed(
            "test \"$(sqlite3 /var/local/appreg.db "
            f"{shlex.quote(query)})\" = 1"
        )
    run_commands(machine, case.get("installAssertions"))


def create_retained_paths(machine, directory: str, paths: list[str]) -> None:
    for path in paths:
        target = directory + "/" + path
        machine.succeed(
            f"if [ ! -e {command(target)} ]; then mkdir -p {command(str(Path(target).parent))}; : > {command(target)}; fi"
        )


def assert_uninstall(machine, case: dict) -> None:
    package_id = case["artifact"]
    machine.succeed(f"test ! -e {command('/mnt/us/kmc/kpm/packages/' + package_id)}")
    machine.succeed(f"test \"{installed_count(package_id)}\" = 0")
    native = case.get("native")
    if native is not None:
        if native["preservedPaths"]:
            machine.succeed(f"test \"$(cat {command(native['marker'])})\" = retained")
            for path in native["preservedPaths"]:
                machine.succeed(f"test -e {command(native['destination'] + '/' + path)}")
        else:
            machine.succeed(f"test ! -e {command(native['marker'])}")
        for scriptlet in native["scriptlets"]:
            machine.succeed(f"test ! -e {command(scriptlet['destination'])}")
    waf = case.get("waf")
    if waf is not None:
        query = f"SELECT COUNT(*) FROM handlerIds WHERE handlerId = '{waf['appId']}';"
        machine.succeed(
            "test \"$(sqlite3 /var/local/appreg.db "
            f"{shlex.quote(query)})\" = 0"
        )
        machine.succeed(f"test ! -e {command('/mnt/us/documents/' + waf['scriptletName'])}")
        if waf["retainedPayloadPaths"]:
            machine.succeed(f"test \"$(cat {command(waf['marker'])})\" = retained")
            for path in waf["retainedPayloadPaths"]:
                machine.succeed(f"test -e {command(waf['mesquiteDirectory'] + '/' + path)}")
        else:
            machine.succeed(f"test ! -e {command(waf['marker'])}")
        documents = waf["documents"]
        if documents is not None:
            marker = documents["directory"] + "/.kpm-" + case["artifact"]
            if documents["retainedPaths"]:
                machine.succeed(f"test \"$(cat {command(marker)})\" = retained")
                for path in documents["retainedPaths"]:
                    machine.succeed(f"test -e {command(documents['directory'] + '/' + path)}")
            else:
                machine.succeed(f"test ! -e {command(marker)}")
    run_commands(machine, case.get("uninstallAssertions"))


def run_case(machine, case: dict, config: dict) -> dict:
    launches = validate_case(case)
    reset_case(machine, case["platform"])
    kpm = initialize_kpm(machine, case, config)
    install_case(machine, kpm, case, config)
    assert_install(machine, case)
    native = case.get("native")
    if native is not None:
        create_retained_paths(machine, native["destination"], native["preservedPaths"])
    waf = case.get("waf")
    if waf is not None:
        create_retained_paths(machine, waf["mesquiteDirectory"], waf["retainedPayloadPaths"])
        if waf["documents"] is not None:
            create_retained_paths(
                machine,
                waf["documents"]["directory"],
                waf["documents"]["retainedPaths"],
            )
    for launch in launches:
        launcher = "/mnt/us/kmc/kpm/packages/" + case["artifact"] + "/launch.sh"
        if launch["mode"] == "none":
            machine.succeed(f"test ! -e {command(launcher)}")
        else:
            machine.succeed(f"test -f {command(launcher)}")
        machine.succeed("rm -f /var/lib/kpm-consumer/*.log")
        try:
            run_commands(machine, launch.get("setup"))
            if launch["mode"] != "none":
                machine.succeed(launch_command(kpm, case["artifact"], launch, config))
                for item in shell_commands(launch["verify"]):
                    wait_for(machine, item)
        finally:
            run_commands(machine, launch.get("cleanup"))
    machine.succeed(lifecycle_command(kpm, config, "-y", "uninstall", case["artifact"]))
    assert_uninstall(machine, case)
    return {
        "artifact": case["artifact"],
        "platform": case["platform"],
        "launches": [
            report_launch(launch)
            for launch in launches
        ],
    }


def run_contract_checks(machine, config: dict) -> list[str]:
    contract = config["contract"]
    reset_case(machine, contract["platform"])
    case = {"platform": contract["platform"]}
    kpm = initialize_kpm(machine, case, config)
    package_id = contract["artifact"]
    machine.succeed(f"printf 'y\\n' | {lifecycle_command(kpm, config, 'install', package_id)}")
    machine.succeed(f"test -f {command(contract['install_marker'])}")
    machine.succeed(f"printf '%s' user-data > {command(contract['retained_path'])}")
    unsupported_status, _ = machine.execute(
        f"{lifecycle_command(kpm, config, '-y', 'install', 'unsupported-platform')} > /var/lib/kpm-consumer/unsupported-platform.log 2>&1"
    )
    assert 0 < unsupported_status < 128
    unsupported_output = machine.succeed("cat /var/lib/kpm-consumer/unsupported-platform.log")
    assert "Could not find artifact for given target." in unsupported_output
    missing_status, _ = machine.execute(
        f"{lifecycle_command(kpm, config, '-y', 'install', 'missing-dependency')} > /var/lib/kpm-consumer/missing-dependency.log 2>&1"
    )
    missing_output = machine.succeed("cat /var/lib/kpm-consumer/missing-dependency.log")
    assert 0 < missing_status < 128, (
        f"missing dependency exited with status {missing_status}: {missing_output}"
    )
    assert "dependency" in missing_output.lower()
    passing = [
        "archive-install",
        "repository-selection",
        "unsupported-platform",
        "missing-dependency",
    ]
    machine.succeed("test ! -e /mnt/us/kmc/kpm/packages/missing-dependency")
    machine.succeed("rm -rf /srv/kpm-consumer/repository")
    machine.succeed(f"cp -a {command(contract['upgrade_repository'])} /srv/kpm-consumer/repository")
    machine.succeed(lifecycle_command(kpm, config, "-y", "upgrade"))
    machine.succeed(f"test \"$(cat {command(contract['retained_path'])})\" = user-data")
    version_query = (
        "SELECT version_major || '.' || version_minor || '.' || version_patch "
        f"FROM installed_packages WHERE id = '{package_id}';"
    )
    machine.succeed(
        "test \"$(sqlite3 /mnt/us/kmc/kpm/kpm.db "
        f"{shlex.quote(version_query)})\" = {shlex.quote(contract['upgrade_version'])}"
    )
    machine.succeed(lifecycle_command(kpm, config, "-y", "uninstall", package_id))
    machine.succeed(f"test ! -e /mnt/us/kmc/kpm/packages/{shlex.quote(package_id)}")
    machine.succeed(f"test \"$(cat {command(contract['retained_path'])})\" = user-data")
    installed_query = f"SELECT COUNT(*) FROM installed_packages WHERE id = '{package_id}';"
    machine.succeed(
        "test \"$(sqlite3 /mnt/us/kmc/kpm/kpm.db "
        f"{shlex.quote(installed_query)})\" = 0"
    )
    machine.succeed(f"cp {command(contract['invalid_archive'])} /var/lib/kpm-consumer/invalid-manifest.kpkg")
    invalid_status, _ = machine.execute(
        f"{lifecycle_command(kpm, config, '-y', 'install', 'file:///var/lib/kpm-consumer/invalid-manifest.kpkg')} > /var/lib/kpm-consumer/invalid-manifest.log 2>&1"
    )
    assert 0 < invalid_status < 128
    invalid_output = machine.succeed("cat /var/lib/kpm-consumer/invalid-manifest.log")
    assert "Invalid manifest version, got 3, expected 2" in invalid_output
    passing.extend(["upgrade", "uninstall", "invalid-manifest"])
    return passing


def run(machine, config_path: str) -> None:
    config = json.loads(Path(config_path).read_text())
    machine.succeed("mkdir -p /srv/kpm-consumer /var/lib/kpm-consumer")
    machine.succeed(f"cp -a {command(config['repository'])} /srv/kpm-consumer/repository")
    machine.succeed(
        "python3 -m http.server 18080 --directory /srv/kpm-consumer/repository "
        "> /var/lib/kpm-consumer/http.log 2>&1 &"
    )
    wait_for(
        machine,
        f"{command(config['http_client'], '--fail', '--silent', config['repository_url'])} > /dev/null",
    )
    cases = [run_case(machine, case, config) for case in config["cases"]]
    contract_checks = run_contract_checks(machine, config)
    launches = [launch for case in cases for launch in case["launches"]]
    declared_launches = [
        report_launch(launch)
        for case in config["cases"]
        for launch in validate_case(case)
    ]
    report = {
        "source": config["source_revision"],
        "source_identity": config["source_identity"],
        "runtime": machine.succeed("tr '\\n' ' ' < /var/lib/kpm-consumer/version.txt"),
        "cli_io": "upstream cli/io.c with an inert FBInk boundary stub",
        "bootstrap_repository": "test-local loopback redirect",
        "cases": cases,
        "case_count": len(cases),
        "declared_launch_count": len(declared_launches),
        "launch_count": len(launches),
        "boundary_handoff_count": sum(
            not launch["actual_application_execution"] for launch in launches
        ),
        "actual_application_execution_count": sum(
            launch["actual_application_execution"] for launch in launches
        ),
        "passing_checks": contract_checks,
    }
    report_json = json.dumps(report, indent=2, sort_keys=True)
    machine.succeed(
        f"printf '%s\\n' {shlex.quote(report_json)} > /var/lib/kpm-consumer/report.json"
    )
    machine.succeed("cat /var/lib/kpm-consumer/report.json")
    machine.copy_from_machine("/var/lib/kpm-consumer/report.json")
