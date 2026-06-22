# Fabric Backup & Restore

A lightweight notebook-based toolkit to back up and restore selected Microsoft Fabric / Power BI workspace artifacts.

This repo is intended for migration testing, workspace recovery experiments, tenant/region move preparation, and repeatable backup/restore validation.

> **Note**  
> This is a technical accelerator, not a production-grade backup product. Always test in non-production workspaces first.

---

## What it does

The notebooks help you:

- Export Fabric workspace metadata and access assignments
- Back up supported item definitions
- Export Power BI semantic model permissions and RLS details where supported
- Export paginated report `.rdl` files
- Back up Dataflow Gen1 / Gen2 definitions
- Store backup output in ADLS Gen2
- Restore supported artifacts into a new target workspace
- Generate backup and restore summary files

---

## Repository contents

| File | Description |
|---|---|
| `migration_nb_backup_v6_s.ipynb` | Main backup notebook. Exports workspace metadata, access, item definitions, reports, semantic model security details, paginated reports, and dataflows. |
| `migration_nb_restore_v6_s.ipynb` | Main restore notebook. Reads the backup from ADLS Gen2 and recreates supported artifacts in a target workspace. |
| `PowerBI_SemanticModel_Migration.ipynb` | Dedicated notebook for large Power BI semantic model backup and restore using `.abf` files. |

---

## High-level flow

```text
Source Fabric Workspace
        │
        ▼
Backup Notebook
        │
        ▼
ADLS Gen2 Backup Storage
        │
        ▼
Restore Notebook
        │
        ▼
Target Fabric Workspace
```

---

## Supported scope

| Artifact | Backup | Restore | Notes |
|---|---:|---:|---|
| Workspace metadata | Yes | Yes | Basic workspace information and metadata |
| Workspace access | Yes | Optional | Role assignments can be reapplied |
| Semantic models | Yes | Yes | Definition-based restore where supported |
| Dataset permissions | Yes | Optional | Reapplied after semantic model restore |
| RLS roles / members | Yes | Optional | Requires sufficient permissions / XMLA access |
| Reports | Yes | Yes | Definition-based backup and restore |
| Paginated reports | Yes | Yes | Uses `.rdl` export/import |
| Dataflow Gen1 | Yes | Yes | Credentials and refresh settings may need manual rework |
| Dataflow Gen2 | Yes | Yes | Uses Fabric item definitions where supported |
| Dashboards | Inventory only | No | Captured for reference only |

---

## Prerequisites

You need:

- Microsoft Fabric workspace access
- Sufficient permissions on the source and target workspaces
- ADLS Gen2 storage for backup files
- Fabric notebook runtime
- Tenant/API permissions for Power BI and Fabric REST operations
- Optional XMLA access for semantic model RLS operations

The notebooks may install or use libraries such as:

```python
semantic-link-sempy
semantic-link-labs
semantic-link
notebookutils
pandas
requests
```

---

## How to use

### 1. Run the backup notebook

Open:

```text
migration_nb_backup_v6_s.ipynb
```

Update the configuration cells, especially:

```python
STORAGE_ACCOUNT = "<storage-account-name>"
FILE_SYSTEM = "<container-name>"
WORKSPACE_INCLUDE = ["<source-workspace-name>"]
```

Then run the notebook end-to-end.

The backup output is written to ADLS Gen2 and includes manifests, item definitions, security metadata, and summary files.

---

### 2. Run the restore notebook

Open:

```text
migration_nb_restore_v6_s.ipynb
```

Update the restore configuration:

```python
SOURCE_WORKSPACE_NAME = "<source-workspace-name>"
TARGET_WORKSPACE_NAME = "<target-workspace-name>"

RESTORE_WORKSPACE_ACCESS = True
RESTORE_DATASET_PERMISSIONS = True
RESTORE_RLS_ROLE_MEMBERS = True
```

Then run the notebook to create the target workspace and restore supported artifacts.

---

### 3. Large semantic model migration

For large Power BI semantic models, use:

```text
PowerBI_SemanticModel_Migration.ipynb
```

This notebook focuses on `.abf` backup and restore patterns for large semantic models.

---

## Typical backup output

```text
backup-root/
├── _manifest.json
├── _workspace_level_backup_manifest.json
└── <workspace_name>__<workspace_id>/
    ├── _workspace.json
    ├── _workspace_access_role_assignments.json
    ├── _workspace_backup_summary.json
    ├── SemanticModel/
    ├── Report/
    ├── PaginatedReport/
    ├── Dataflow/
    └── DataflowGen1/
```

---

## Known limitations

- This is not a full enterprise backup product.
- Some Fabric item types may not support export/import through APIs.
- Dashboards are inventoried only, not restored.
- Credentials, gateways, connections, refresh schedules, and sensitivity labels may require manual reconfiguration.
- RLS and dataset permission restore depend on API support, XMLA access, and tenant permissions.
- Always validate restored artifacts functionally after restore.

---

## Security notes

Backup files may include sensitive metadata such as workspace access, dataset permissions, and RLS membership.

Recommended practices:

- Store backups in a secured ADLS Gen2 location
- Use least-privilege access
- Do not commit secrets, tenant-specific IDs, or customer data
- Test restore in isolated workspaces first

---

## Disclaimer

This repository is a reference implementation and technical accelerator. Microsoft Fabric and Power BI APIs evolve frequently, so behavior may change over time.

Use carefully, validate thoroughly, and adapt to your environment.
