# Package compatibility policy

Packages must follow the documented KPM contract. When behavior conflicts with that contract, prefer fixing KPM upstream. A temporary compatibility measure is justified only by a concrete critical operational need; document its explicit scope and removal condition.

Runtime fixtures used by automated ABI tests must come from reproducibly pinned online sources and must not depend on files exported from a Kindle.

Automated lifecycle tests must cover installation, launch, and uninstallation for every packaged item.
