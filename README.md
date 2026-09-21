# Git Bulk Amend Automation

A high-performance, robust PowerShell utility designed to dynamically sweep across local folder structures, overwrite commit historical indexes, and update GitHub profile portfolio placements simultaneously.

## Overview

**Git Bulk Amend Automation** addresses localized profile indexing loops by programmatically updating development arrays across extensive numbers of repositories. Instead of manually shifting staging trees, this engine automates checkout pipelines, captures active working trees, modifies historical stamps to match current timestamps (`GIT_COMMITTER_DATE`), and triggers conditional upstream pushes (`--force-with-lease`). It natively evaluates structural branched pipelines (`dev` vs `main`/`master`) and seamlessly merges developmental loops to make repositories look like they underwent a structured maintenance phase.

## Features

- **Automated Directory Discovery:** Scans parent workspaces recursively to dynamically isolate active Git environments from empty folders or asset assets.
- **Advanced Flow Tracking Matrix:** Intelligently maps branching environments—automatically amending and updating dedicated `dev`/`development` routes first before checking out and merging into default lines (`main`/`master`).
- **Cryptographic Push Security:** Utilizes protective `--force-with-lease` criteria rules to instantly skip the push sequence if remote histories contain new changes that are missing locally, avoiding accidental work deletion.
- **Dry-Run Inspection Guard:** Includes an absolute preview flag (`-DryRun`) that simulates terminal commands, branch shifts, and log messages without changing a single line of local or remote code.
- **Dynamic Timing Buffers:** Employs configurable pause limits between consecutive operations to emulate human pacing and protect remote host accounts from API speed limit blocks.
- **Transparent Execution Transcripts:** Generates structured, color-coded logging summaries straight to your shell alongside runtime output logs (`.log`) preserving details on successes, skips, and failures.

## Project Structure

```bash
git-bulk-automation/
├── bulk-amend.ps1       # Master core PowerShell scripting utility engine
├── bulk-amend_*.log     # (Git Ignored) Auto-generated analytical transaction history tracks
└── README.md            # Comprehensive operational technical documentation
```

## Parameter & Execution Options

| Configuration Flag  | Data Parameter Type | Fallback Value Default | Target Operational Behavior                                            |
| :------------------ | :------------------ | :--------------------- | :--------------------------------------------------------------------- |
| **`-Message`**      | String              | `"Changed Visibility"` | Explicit textual description stamped across target commit alterations. |
| **`-DelaySeconds`** | Integer             | `10`                   | Waiting period buffer assigned between repository runs.                |
| **`-DryRun`**       | Switch              | _Inactive_             | Prevents real execution; prints simulated steps for confirmation.      |

---

## Setup & Script Execution Guide

### Prerequisites

- Windows 10/11 or macOS/Linux instances containing **PowerShell Core**.
- Native **Git CLI** wrapper tools installed locally and configured inside system path maps.

### Running the Automation Pipeline

- Clone or download this specialized utility script directly into the parent root path folder where your target portfolio repositories sit:

  ```powershell
  git clone https://github.com
  ```

- Launch a new terminal window inside that main root folder location.

- _(Optional)_ If your local system execution profile restricts unsigned scripting components, unblock the execution wrapper temporarily:

  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
  ```

- Execute a dry run pass first to preview branches, targets, and expected structural modifications safely:

  ```powershell
  .\bulk-amend.ps1 -DryRun
  ```

- Initiate the real production execution loop across all active targets using tailored parameters:
  ```powershell
  .\bulk-amend.ps1 -Message "Refactored System Architecture" -DelaySeconds 5
  ```

## Author

H2SO4-1191 – Software Engineer
