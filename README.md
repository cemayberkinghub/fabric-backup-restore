# fabric-backup-restore

Two Windows BAT scripts that use the [Microsoft Fabric CLI (`fab`)](https://github.com/microsoft/fabric-cli) to **back up** a Fabric workspace — preserving every item definition in a hierarchical folder structure — and to **restore** those items into a target workspace.

---

## Contents

| File | Purpose |
|---|---|
| `backup_workspace.bat` | Exports all items from a Fabric workspace to a timestamped local folder |
| `restore_workspace.bat` | Imports all backed-up items into a target (new or existing) workspace |

---

## Prerequisites

1. **Python 3.10 – 3.13** installed and on `PATH`.
2. **Microsoft Fabric CLI** installed:
   ```cmd
   pip install ms-fabric-cli
   ```
3. **Authenticated** with your Fabric tenant:
   ```cmd
   fab auth login
   ```
   For unattended / CI scenarios you can authenticate via service principal:
   ```cmd
   fab auth login -u <client_id> -p <client_secret> --tenant <tenant_id>
   ```

---

## backup_workspace.bat

Exports all item definitions from a workspace and saves them in a timestamped folder:

```
<BackupBaseDir>\<WorkspaceName>_<YYYY-MM-DD_HH-MM-SS>\
  <WorkspaceName>.Workspace\
    <ItemName1>.<ItemType>\
      ...definition files...
    <ItemName2>.<ItemType>\
      ...definition files...
```

### Usage

```cmd
backup_workspace.bat [WorkspaceName] [BackupBaseDir]
```

Both parameters are **optional**. If omitted the script prompts for them interactively.

#### Examples

```cmd
REM Interactive
backup_workspace.bat

REM Non-interactive
backup_workspace.bat "Sales Analytics" "C:\FabricBackups"
```

---

## restore_workspace.bat

Iterates over every item folder inside a backup and imports each one into the target workspace.

### Usage

```cmd
restore_workspace.bat [BackupDir] [TargetWorkspaceName]
```

`BackupDir` is the **timestamped folder** created by `backup_workspace.bat`
(e.g. `C:\FabricBackups\Sales Analytics_2024-06-01_09-00-00`).

Both parameters are **optional**. If omitted the script prompts for them interactively.

#### Examples

```cmd
REM Interactive
restore_workspace.bat

REM Non-interactive
restore_workspace.bat "C:\FabricBackups\Sales Analytics_2024-06-01_09-00-00" "Sales Analytics DR"
```

The script prints a summary of successful and failed imports at the end.  
**Tip:** Restore into a new, empty workspace to avoid conflicts with existing items.

---

## Supported Item Types

The scripts work with any item type that the Fabric CLI supports for `export`/`import`, including (but not limited to):

- Notebook (`.Notebook`)
- Report (`.Report`)
- Lakehouse (`.Lakehouse`)
- Data Pipeline (`.DataPipeline`)
- Semantic Model / Dataset (`.SemanticModel`)

Items whose type is not yet supported by the CLI for export/import will be skipped or reported as failed during restore.

---

## Notes

- Re-run `fab auth login` if your session expires before the backup or restore finishes.
- For large workspaces, consider running the scripts from an elevated (Administrator) Command Prompt to avoid permission issues when creating folders.
- Connections and linked resources referenced by items (e.g., data source credentials) must be recreated manually in the target workspace after restore.