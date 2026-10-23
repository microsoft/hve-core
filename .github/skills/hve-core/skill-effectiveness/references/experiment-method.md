---
description: "Native Vally execution, safe validation, spending boundaries, and evidence interpretation for skill-effectiveness"
---
<!-- cspell:ignore uninspected -->

# Native Execution And Evidence

The current authoring/test package targets Vally 0.19.0, Copilot CLI 1.0.89 and SDK 1.0.15,
on Node.js 24+. Windows model-free package and optional native command-policy
checks passed; full task and grader qualification remains separate.
Keep completed evaluation packages and their pins unchanged for reproducibility.

## Restricted Execution Profile

The authoring package and generic adapter are cross-platform. The optional
`windows-native` profile is Windows-specific; importing its helper does not
activate it. Linux/macOS execution requires a separately qualified native or
container profile, not selection of that Windows name or an unrestricted fallback.

The current development package and generated template use the versions above. The
[session-policy plugin](../scripts/restricted-copilot-executor.mjs) and templates
prepare the following contract. Package checks and runtime security verification
are distinct. Model-free Ubuntu restore, repository/copied-package
tests and actual image decoding passed. The plugin refuses registration on a
different stack. Actual SDK RPC and hardened native Docker checks passed
the tested policy and role boundaries; these are distinct from mocked wiring.
Untrusted execution remains blocked unless the operator establishes the required
controls for the selected image, task and grading route.
The local command later in this guide documents mechanics, not a contained
alternative when a required control is missing. There is no automatic fallback
to the local backend.

Published package inspection alone is not installed-stack verification.
The default image `vally.azurecr.io/vally-task:0.19.0` at digest
`sha256:cc940117d3aeec8c6949944104f6a1d431ea8d368aa3dfac17a5bfafe958c536`
reports core 0.18.0 in its grade role, incompatible with host 0.19.0.
Do not bypass the native compatibility guard, downgrade or substitute an image
without approval. Model-free profile checks qualify separately built pinned
public-stack Linux images, not that default digest or arbitrary substitutes.

### Completed Model-Free Evidence And Limits

| Check                                              | Established scope                                                                                                             | Not established                                                                            |
|----------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| Frozen restore and ordinary package tests          | Ubuntu and Windows package mechanics, native mock/lint/dry-run paths and local image decoding                                 | Actual model calls, Windows runtime isolation or judgment quality                          |
| Actual SDK policy and synthetic native-role checks | Tool/permission RPC behavior and host-file, environment, privilege and network canaries on the tested hardened Linux profiles | Arbitrary task policies or authenticated model-task boundaries                             |
| No-prompt production startups                      | Actual session inventories, independent backup bytes, completion comparison and native workspace retention                    | Successful candidate tasks or independent host attestation                                 |
| Optional Windows-native candidate profile          | Normal-login startup; useful Node execution; protected authentication/audit reads, outside writes and loopback access denied  | Full interpreter/browser tasks, grader isolation or a managed-policy floor                 |
| Optional Linux offline rendering profile           | Chromium user-namespace renderer and actual Mermaid PNGs with no capabilities, no-new-privileges and denied external network  | Full native CLI export, immutable submission binding or arbitrary host/image compatibility |
| Synthetic protected grading                        | Immediate checker authentication, readonly executed inputs, writable scratch and integrity-negative rejection                 | Real-candidate provenance or automatic arm/snapshot binding                                |

These scopes are not universal protection. Preserve validation evidence with the
exact package/runtime revision and selected profile; qualify materially changed
code, images or native preservation layouts separately. Full Windows task/grader
containment, authenticated model-task execution and model judgment quality remain
unverified. The optional Windows regression intercepts the candidate send without
forwarding a model request; it does not spend credits.

### Public Release Basis

Use the pinned public [Vally core](https://www.npmjs.com/package/@microsoft/vally/v/0.19.0),
[Vally CLI](https://www.npmjs.com/package/@microsoft/vally-cli/v/0.19.0) and
[Copilot SDK](https://www.npmjs.com/package/@github/copilot-sdk/v/1.0.15)
distributions for runtime capability claims. Verify archive integrity against
the canonical lockfile before inspecting the shipped contracts. The adapter
uses the exported executor client factories; the recorder and image reviewer
use SDK session/RPC and attachment interfaces. CLI plugin loading, native
grading and Docker role settings belong to the released runtime.

Keep published API support, inspected package behavior and observed execution
separate; none alone establishes all required runtime boundaries.

### Ownership And Role Boundaries

Vally retains execution, workspace lifecycle, staging, grading, retries, native
results and time/concurrency controls. One thin executor plugin applies session
policy through public client factories; it does not clone the executor or add a
launcher, scheduler, credential proxy or spending service. The provider/native
host owns process/filesystem separation, credentials, egress and enforceable
financial limits. This skill owns task/evidence authoring and honest supervision.

| Role                         | Native surface                                                              | Required boundary before use                                                                                                                                                                     | Evidence limit or operator verification                                                                                        |
|------------------------------|-----------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Tool-using repository intake | Authoring session, not the candidate executor                               | Treat repository/tool content as data; no imported instruction may grant tool or credential access                                                                                               | Candidate session policy does not restrict the authoring session                                                               |
| Candidate                    | Native `experiment run`, Docker backend and `task-*` role settings          | Public task/sources and declared skills only; identical explicit session policy in both arms; no private checker, review machinery or host evidence; no general access to runtime authentication | Actual SDK policy and synthetic containment tested; qualify the selected useful task policy, image and authentication boundary |
| Offline executable grading   | Separate native `grade` with executable-only graders and `grade-*` settings | No credentials or egress; readonly trusted checker and submission; protected temporary outputs; check checker hash immediately before use                                                        | Synthetic checker/input and containment checks passed; verify each actual runtime layout and original/snapshot binding         |
| Online saved-evidence review | Separate native assessment or the no-tools SDK image reviewer               | Selected saved artifacts only; no submission execution or execution tools; model-service access must not reopen offline execution                                                                | Exact native text-review restrictions and separation from executable grading                                                   |
| Supervised startup evidence  | Existing session factory and durable operator audit root                    | Capture and independently back up actual inventory before the first prompt; compare both files with the in-memory digest after execution; keep audit files out of candidate and grading inputs   | Verify retention through actual native CLI cleanup; no independent host attestation                                            |

Use native `--backend docker` and documented `--backend-args` role settings,
including `task-image`, `grade-image`, `task-env`, `grade-env`, `task-network`
and `grade-network`. Network defaults are not denial. Offline grading requires
`grade-network=none`, no LLM graders, and no global `judge_provider`: an
explicit provider can project credentials even without an LLM grader. The later
online review needs its own spec/provider scope; do not invent a `--grader`
selection flag. Extra review inputs must not duplicate or change the public task.

Fresh homes, separate conversations, deleted environment variables, readonly
source mounts and before/after hashes are not proof of these boundaries. Graders
can execute candidate-controlled code, so candidate containment does not solve
grader containment. Model authentication must not become a general
candidate-readable secret. If the native boundary cannot enforce this, stop;
do not add a custom credential proxy or accept financial risk in its place.

### Replacing Additions With Native Vally Features

Keep the three additions independent of native experiment results, graders and
reports. Retire an addition when a released native feature satisfies its contract,
not merely when Vally's version increases. Do not add a compatibility framework
or automatic fallback to less restrictive behavior.

| Addition                     | Replacement contract                                                                                                                      | Integration points to remove or update                                                              |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| Session-policy plugin        | Equivalent explicit tool visibility, permission decisions and fresh environment-scoped session behavior, verified on the selected runtime | `study:*`'s `--executor-plugin`, eval executor/config, plugin module and its focused contract tests |
| Startup inventory and backup | Actual full skill inventory before the first prompt, independent backup and completion comparison with retained startup digest            | Session factory, recorder, backup/verification tests and durable audit retention after CLI cleanup  |
| Optional image-review helper | Actual PNG/JPEG delivery, bounded approved inputs, no execution tools and retained usage/failure evidence, not text-only snapshots        | Image helper, decoder dependency and image-review tests; human visual review remains available      |

Normal execution uses the existing environment-aware client factory, not a
process-wide SDK prototype wrapper. The recorder's separately invoked diagnostic
preload remains available for explicit no-prompt investigation; it is not the
generated run command or a production evidence boundary.
For any replacement, update development/generated pins and canonical locks
together, translate configuration explicitly, and run the existing contract
checks against the native replacement. Preserve completed experiment packages;
record the replacement as a methodology change for future runs.

### Adapter-Owned Session Policy Contract

Copy the [plugin](../scripts/restricted-copilot-executor.mjs) to the same
`scripts/restricted-copilot-executor.mjs` path in generated packages.
The generated `study:dry-run` command loads it through native
`--executor-plugin`; the eval selects `restricted-copilot-sdk`. Separately
authorized manual execution must load the same plugin. Relative plugin
paths resolve from the experiment file's directory, so keep the documented
`experiments/` and `scripts/` layout. `executor_plugins` is not a supported
experiment YAML field. Both arms inherit the same eval policy.
It imports the released `@microsoft/vally/executor` and public SDK interfaces.
Only **fresh environment-scoped sessions** are supported. The template's shared
`agent_environment.env` selects Vally's environment-aware `createEnvClient`
factory, preserving its configured provider environment, config home, telemetry and trace
provider. The plugin removes inherited host-agent/subagent control variables and
Node injection/test controls from a child-only copy, but does not remove provider
or authentication variables indiscriminately. This is not credential isolation.
It pins the installed platform executable through the supported
`RuntimeConnection.forStdio({path, env})` interface; the legacy `cliPath` client
property is not a supported selection mechanism in SDK 1.0.15.
Default-mode and resume requests reject before SDK startup.
The default factory also rejects; no private home/environment reconstruction
or global SDK prototype mutation is used.

The following is the binding **configuration shape** inside that plugin's native
`executor.config`. It is not accepted by the built-in executor, whose published
validator accepts only `provider`. Empty lists illustrate the no-grants starting
policy, not a runnable task profile:

```yaml
sessionPolicy:
  availableTools: []
  permissions:
    allow: []
    deny: []
```

Set sibling `executor.config.auditDirectory` to a durable absolute operator-owned
directory outside every candidate workspace. The candidate template accepts
the native `AUDIT_DIR` parameter. Missing, relative or overlapping paths reject
before native execution. Do not use `sessionLog.rootDir` for this storage:
the CLI creates that directory temporarily and exports only its supported native
logs before deleting it.

### Explicit Empty Client Mode For Repository Workspaces

For a full checkout containing nested `AGENTS.md` or `CLAUDE.md`, select the
pinned SDK's empty client mode explicitly:

```yaml
clientMode: empty
```

This is an optional sibling of `sessionPolicy` and `auditDirectory`, not an
execution profile or a replacement for tool/filesystem controls. The adapter
creates private runtime state under the disjoint durable audit root and passes
`mode: "empty"` and `baseDirectory` to the public SDK client constructor.
Omitting `clientMode` leaves the existing default/provider client unchanged.
The startup inventory records the selected mode.
Empty mode also omits automatic environment context. The adapter replaces only
that section with the actual absolute workspace and operating-system identifier,
so candidates resolve relative paths correctly rather than assuming `/workspace`.
This does not restore ambient repository instructions. Caller-supplied full
system-message replacement or environment-section overrides reject in this mode;
other system-message content/sections remain intact.
Runtime-state directories are private operational storage, not submission or
review evidence. Share only explicitly selected inventory/backup/verification
files after privacy review, never the entire runtime-state tree.

The pinned runtime can advertise a child-instruction index from a staged
subproject despite `skipCustomInstructions: true`. Source-ID exclusions and
cache reload alone did not empty that observed inventory. Empty mode suppresses
the discovery while retaining explicitly supplied tools and focus skills.
The guard still rejects every nonempty or malformed instruction inventory;
never filter its response, remove repository instruction files or treat an
advertised index as proof that no custom instructions are active.

Qualify the actual complete staged checkout in both arms, not only a small
synthetic directory. Retain raw instruction-source responses outside candidate
workspaces, verify authentication status without extracting credentials, and
test legitimate source reads, private-path denials and full skill activation.
The opt-in native runtime tests also create nested instruction files and
verify their content is absent from intercepted model-facing requests.
Mode changes require a separately recorded setup revision; completed runs
and failed startup attempts remain unchanged.

### Optional Windows-Native Candidate Profile

For a Windows candidate using normal local Copilot sign-in, copy
[native-windows-sandbox.mjs](../scripts/native-windows-sandbox.mjs) alongside the
plugin and add the following sibling configuration:

```yaml
executionProfile:
  name: windows-native
  readonlyPaths: []
  deniedPaths: []
```

Both path lists require distinct absolute paths. Add only reviewed task runtimes
and inputs to `readonlyPaths`, identically in both arms; never grant a directory
containing credentials or private evaluation material. Node's installed directory
and explicitly registered skill directories are included automatically. Keep
all writable candidate work inside the native workspace. The adapter denies the
audit root, Copilot authentication/configuration paths and configured private
paths. It requires actual shell, denied-path and network capabilities, applies
the session sandbox before returning the session, and rejects failed updates,
blocked enforcement or absent normal-login authentication.

This profile removes inherited Copilot/GitHub token and Copilot provider variables
from the runtime child, rejects explicit provider/client-token configuration,
and disables Git/GitHub shell credential injection. It also drops the parent's
`PSModulePath` so the command runtime discovers its own PowerShell modules.
It does not extract or forward the local login credential. Native sandboxing
disables bypass, automatic development-tool grants, outbound access and loopback.
Do not place other secrets in the runtime environment or task runtime directories.
The generic profile intentionally preserves provider/BYOK behavior when this
option is absent; that path still needs separate credential containment.

This uses the pinned SDK's public experimental sandbox RPC. It is Windows-only,
has no unrestricted fallback, and is an explicit session policy rather than an
enterprise managed-policy floor. It restricts candidate commands, not the
authoring session or offline grader. Qualify Python kernels, browsers, native
artifact retention and grading separately for the actual task before paid use.

### Split Candidate And Offline Toolchains

When the approved candidate sandbox cannot run a notebook kernel or browser,
you may keep Node/Python execution with the candidate and execute notebooks or
render diagrams only in a separate credential-free offline grading environment.
Jupyter's ZeroMQ channels and a renderer's browser are grading prerequisites in
that arrangement, not required candidate capabilities.

Obtain approval if this changes the agreed candidate tool profile. Update both
arms' task/tool declarations equally before collecting fresh outputs: disclose
which self-tests are unavailable and where final execution/rendering happens.
Keep original input and skill bytes pinned and record changed task disclosures
separately. Do not advertise installed candidate tools that cannot run.
Retain executed notebooks, all required charts and actual rendered diagrams;
offline execution is not a file-only substitute.

Verify ordinary Node/Python work, child processes and long-command lifecycle
inside the candidate sandbox. Preserve required command environment entries;
an arbitrarily shortened `PATH` can break native runtime discovery. Stage each
public checker's locked dependencies without exposing private grading resources.
Include the runtime's read/stop shell tools when legitimate commands can outlive
the first response. Test missing prerequisites and failed commands as errors,
not successful task evidence.

Separately qualify the offline image, readonly checker/submission inputs,
writable scratch, output retention and denied host credentials/egress. Browser
sandbox or container-privilege changes need their own explicit approval; the split
does not authorize disabling a browser sandbox or granting extra capabilities.

### Linux Browser Namespace Sandbox

For credential-free offline rendering, use a nonroot Linux image with a pinned
Chromium/Mermaid installation and an explicitly reviewed seccomp profile.
[Microsoft's Docker guidance](https://playwright.dev/docs/docker#crawling-and-scraping)
permits `clone`, `setns` and `unshare` for user namespaces. Pin the
[profile's source revision](https://github.com/microsoft/playwright/blob/66070a1eaa0b869379607a9e0e1a652ddf2a77da/utils/docker/seccomp_profile.json)
and hash rather than following `main` silently.

The tested no-capabilities configuration additionally needed an allowed
`chroot` syscall: that source profile otherwise enables it only when the
container has `CAP_SYS_CHROOT`. A reviewed syscall allowance lets Chromium
establish its namespace sandbox without granting that host capability; kernel
permission checks still apply. This is a policy change requiring approval,
not a global default. Preserve upstream licensing if redistributing a profile.
Do not add `SYS_ADMIN`, use privileged/unconfined mode or disable the browser
sandbox as an automatic workaround.

The tested controls retain user `1000:1000`, `--cap-drop ALL`,
`no-new-privileges:true`, a readonly root/checker mount, private writable scratch
and `--network none`. Observe renderer UID maps, zero effective capabilities and
active seccomp, then run the actual Mermaid checker and decode its images.
Successful browser startup alone is insufficient. A setuid sandbox package
alone does not overcome `no-new-privileges`; user-namespace support and host
policy must be verified. Do not change host namespace/AppArmor settings implicitly.

The image supplies `MERMAID_CLI`. Pass its compatible, readonly Puppeteer JSON
with an explicit browser executable path; await asynchronous Puppeteer path
discovery when generating that JSON. This profile is separate from the
Windows-native candidate adapter.

After separately approving Docker startup and the existing image/profile,
run the opt-in regression from the skill root:

```powershell
$env:SKILL_EFFECTIVENESS_LINUX_RENDER_TESTS = '1'
$env:SKILL_EFFECTIVENESS_RENDER_IMAGE = 'sha256:<verified-image-id>'
$env:SKILL_EFFECTIVENESS_RENDER_SECCOMP = '<absolute-approved-profile.json>'
$env:SKILL_EFFECTIVENESS_RENDER_BROWSER_CONFIG = '<absolute-browser-config.json>'
$env:SKILL_EFFECTIVENESS_RENDER_EVIDENCE_DIR = '<absolute-durable-evidence-root>'
node --test tests/native-linux-rendering.test.mjs
```

The test never pulls an image, forwards credentials, invokes a model or changes
host policy. It uses one owned container, retains records and decoded browser/
Mermaid images, and removes only that container. Ordinary tests skip it.
The supplied image/profile remain operator-owned inputs; the skill does not
install Docker, vendor browser binaries or create an execution framework.

### Task Policy Requirements

* Require all three lists and their enclosing objects. Reject unknown keys,
  missing values, wrong types, duplicate entries and empty/non-string entries
  before a candidate prompt. Empty lists are valid and must not be converted
  into omitted/unrestricted settings. Preserve native `provider` validation.
* `availableTools` contains exact, runtime-supported tool names, not wildcard
  grants. Populate only the tools needed for the approved task, identically in
  both arms. Unknown or unsupported tools fail closed. Do not enable shell,
  interpreters, delegated agents or external tool servers merely to make a
  failing task finish.
  Supply the native `skill` tool whenever skills are requested. Registration in
  `skills.list` alone does not make a skill model-visible. Both arms request the
  same tool list; the runtime may naturally omit `skill` when no skills are
  available. Only that omission is accepted for an arm with no requested skills.
  Record actual tool names and verify treatment activation in native traces.
* Forward `permissions.allow` and `permissions.deny` to the SDK's host-injected
  `managedSettings.permissions`; fix `disableBypassPermissionsMode` to
  `"disable"`. Rule strings use the runtime's own managed-permission parser,
  not a handwritten command-prefix or filesystem parser. Validate malformed
  rules through native session initialization before any candidate prompt.
* Replace the executor's approving handler with an explicit SDK denial result,
  `kind: "reject"`, for every
  permission request reaching the host. Only native rules may admit operations
  before this fallback. Unknown kinds deny; no request is left pending, no
  original approving callback is invoked and no interactive approval is assumed.
  Use the pinned native permission protocol's canonical decision; a malformed
  callback response is an operational failure, not evidence of policy denial.
* Apply policy last on each fresh environment-scoped session and replacement
  client. Per-execution context prevents concurrent runs from sharing policy.
  Preserve native provider validation and delegate only provider configuration
  to Vally. Reject conflicting injected session restrictions.
  Disable configuration discovery, custom instructions and on-demand instruction
  discovery separately. Also disable extensions, file hooks, host Git context and
  cross-session storage; explicitly enable supplied skills and exclude builtin
  skills. Reject nonempty or unavailable actual custom-instruction inventories.
  Compare enabled skill paths with every explicitly requested skill directory,
  rejecting missing, ambient, duplicate or disabled treatment entries.
* Initialize tools and inspect the public SDK's current tool metadata before
  returning the session to Vally. Effective tool names must match the explicit
  list, including an empty list, except the no-skill omission described above.
  Missing, unexpected, duplicate or
  unavailable metadata fails closed. Native session creation/tool initialization
  owns managed-rule validation; the adapter does not parse rule syntax.
  Session creation has a deadline of at most 30 seconds to accommodate first-use
  runtime extraction. Inventory RPCs and failed-session disconnect each have a
  deadline of at most ten seconds, bounded further by the configured native timeout. Failure
  preserves initiating and cleanup errors. A deadline does not prove that the
  underlying operation or process stopped; Vally retains client cleanup ownership.
* SDK 1.0.15 exposes injected policy, but older runtimes may ignore that additive
  RPC field. The exact released runtime must demonstrate enforcement, including
  fresh and replacement sessions, before this profile is usable. Resume is
  unsupported. Registration checks installed core/SDK/CLI package versions and
  the connection selects the installed platform executable; this does not
  independently attest binary integrity or effective restrictions. An unsupported field,
  ignored restriction or failed security check blocks execution; it does not
  justify a newer private build or unrestricted fallback.

Keep plugin code and policy outside candidate write authority. Tool visibility
is not an operation permission, and neither is an OS sandbox. Native allow rules
need task-specific review; broad shell/interpreter access permits arbitrary code
effects. Keep those requests denied until verified native containment supports
the original task safely. Do not silently turn an arbitrary-code task into a
source-only task; a methodology change requires a user decision and disclosure.

### Operational Acceptance Still Required

Before the final run gate, independently authorize model-free runtime checks
using synthetic, non-secret canaries in a disposable environment. Check
outside-workspace reads, inherited environment access, undeclared commands,
controlled egress and private checker replacement. Separately check startup
backup/verification and native workspace retention, including changed/deleted
inventory copies; supervised detection does not require write denial.
Never use personal files, real credentials or public exfiltration
targets. Verify immediate pre-use checker hashes and readonly executed paths,
not just the original source mount.

Test legitimate task operations too: workspace/fixture directory listings,
input reads and deliverable create/update. Use canonical absolute paths so
Windows short-name aliases do not accidentally deny an allowed path. An exact
directory `Read(...)` rule can permit listing without a recursive file grant;
verify protected root files and private descendants remain denied. The generic
plugin never invents a task's path permissions. A listing can expose filenames,
so keep private author notes, other arms and evaluator originals outside its
listing scope. Do not add broad workspace reads to fix a denied listing.

The optional `tests/native-runtime.test.mjs` checks the real pinned SDK/Vally
lifecycle using fixed SDK request-handler responses that never forward to a
model. Set `SKILL_EFFECTIVENESS_RUNTIME_TESTS=1` and explicitly select a locally
available metadata model with `SKILL_EFFECTIVENESS_TEST_MODEL` to run it.
Authentication/runtime startup can still be required; this is not a judge
qualification or permission to start paid inference. Ordinary tests leave it
skipped. It covers baseline context, treatment skill-body activation, directory
listing, input read, deliverable write and native completion with cleanup.

Distinguish a Windows host running Linux containers from native Windows candidate
tooling. Host-specific PowerShell, Edge, Mermaid, Python and notebook-kernel paths
are not portable image dependencies. Select and verify a supported host/image
or stop for a platform decision. Until these gates pass, there is no claim that
the adapter makes evaluation evidence isolated.

## Copy And Test The Reusable Skill

Installing a skill for chat use and running its contributor regression suite are
different operations. Install/load the complete folder through your chat host
for use; `npm ci` alone does not register it. To author your first experiment,
start with the [authoring walkthrough](first-evaluation.md).

Copy `SKILL.md`, `SECURITY.md`, `LICENSE`, `NOTICE`, `assets/`, `references/`, `scripts/`, `tests/`, `package.json`,
`package-lock.json`, `.npmrc` and `.gitignore` as one folder.
No parent-repository runtime helpers are needed. For contributor regression
tests, use the isolated repository-shaped copy and additional root `LICENSE`
shown below: the packaging test compares the skill's license with that
canonical file.
Exclude node_modules, temporary test directories, logs, generated coverage
reports and previous outputs.

For example, from an HVE Core checkout root, make a fresh regression-test copy
with no parent runtime helpers. If using an installed complete skill folder,
set `$Source` to that folder instead:

```powershell
$Source = (Resolve-Path '.github\skills\hve-core\skill-effectiveness').Path
$CopyRoot = Join-Path ([IO.Path]::GetTempPath()) ('skill-effectiveness-check-' + [Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $CopyRoot) { throw 'Choose a fresh copy directory.' }
$Copy = Join-Path $CopyRoot '.github\skills\hve-core\skill-effectiveness'
New-Item -ItemType Directory -Path $Copy | Out-Null
$Items = @(
  'SKILL.md', 'SECURITY.md', 'LICENSE', 'NOTICE', 'assets', 'references',
  'scripts', 'tests', 'package.json', 'package-lock.json', '.npmrc', '.gitignore'
)
foreach ($Item in $Items) {
  Copy-Item -LiteralPath (Join-Path $Source $Item) -Destination $Copy -Recurse
}
Copy-Item -LiteralPath (Join-Path $Source 'LICENSE') -Destination (Join-Path $CopyRoot 'LICENSE')
Set-Location $Copy
```

The additional root `LICENSE` supplies the canonical-notice comparison in the
tests; it is not another runtime dependency. An arbitrary flat-folder test copy
does not satisfy that repository-layout assertion.

From this copy, after applying the approved-registry instructions below if your
organization requires a proxy:

```powershell
npm ci
npm test
```

The test files validate packaging, native lint/dry-run/mock results,
code-plus-prompt evidence wiring, inventory capture and SDK image attachments.
Ordinary tests mock model responses, but still require the optional platform
packages: Vally/SDK setup can resolve the bundled Copilot executable, and image
tests use the native Sharp decoder. Do not restore this suite with
`--omit=optional`. Native session-startup coverage is skipped unless explicitly
selected; installed runtime packages do not authorize model calls.
These tests do not judge output quality or prove model vision. Coordinated
dependency pins and the canonical lock have passed frozen Ubuntu and Windows
restore and package tests on the pinned stack. Windows file-symlink coverage
requires host privileges and can be skipped. The plugin rejects mismatched installed
versions. A missing local installation or older parent-repository packages
cannot substitute for the frozen suite; record unavailable checks explicitly.
Restore only when permitted by the host's dependency/network policy.

### Restore Through An Approved Registry

If your organization requires a registry proxy, supply its approved address
through your environment, not a tracked file. A CLI flag or
`npm_config_registry` overrides the package's public `.npmrc`; user-level npm
configuration alone does not. From the skill or generated experiment folder,
with `npm_config_registry` already set to your approved registry:

```powershell
npm ci --replace-registry-host=always --ignore-scripts --include=dev --no-audit --no-fund
```

For intermittent connection resets, retry the same frozen restore sequentially
with `--maxsockets=3 --fetch-retries=1 --fetch-timeout=120000`. Stop on an
unavailable pinned version and ask your registry administrator; do not switch
registries, disable TLS checks or substitute versions automatically.
Keep the canonical public lockfile and its SHA512 hashes unchanged. Do not
generate locks through a proxy or run `npm install` as a restore workaround.

For Python, frozen locks can contain direct public artifact URLs that an index
override alone does not redirect. Export the unchanged lock's exact requirements
and hashes, then restore through the approved source into a fresh virtual
environment:

```powershell
uv export --frozen --no-dev --no-emit-project --no-header -o requirements.txt
uv venv --python <approved-python> .venv
uv pip sync --python <venv-python> --require-hashes --only-binary :all: `
  --index-url "$env:APPROVED_PYTHON_INDEX" requirements.txt
```

Keep the exported requirements tied to the original lock digest. Supply local
feed values privately from approved host configuration, with BuildKit secrets
for image restores; never bake them into image configuration or committed files.
Do not regenerate the public lock, change versions, bypass hashes/TLS or fall
back to a public download when local policy requires the approved source.

The development package and generated template explicitly override `qs` to
6.16.0. This compatible pin passed public and approved-registry frozen restores
and model-free checks; it does not include the functional and robustness fixes
in [6.16.1](https://github.com/ljharb/qs/blob/v6.16.1/CHANGELOG.md).
Reassess the pin when updating dependencies. This recipe does not approve
packages, guarantee registry availability or authorize runtime startup.

The host's coverage-enabled Node runner writes `coverage-node.info` in the skill
folder. This generated report is ignored by Git and the package-content check;
other undeclared package files remain errors.

### Optional Runtime Startup

After separately authorizing local runtime startup and installing optional
dependencies, select the model-free native smoke test:

```powershell
$env:SKILL_EFFECTIVENESS_NATIVE_PREFLIGHT = '1'
node --test --test-name-pattern="actual native executor" tests/native-inventory.test.mjs
Remove-Item Env:\SKILL_EFFECTIVENESS_NATIVE_PREFLIGHT
```

This smoke test creates real local SDK sessions but stops before any model prompt.
It is not part of ordinary upstream validation.

The development package and generated package pin the same direct dependencies
and security overrides. MCP SDK 1.31.0 fixes GHSA-6qxp-vccf-f47h. Azure Monitor
exporter beta.46 replaces the old logging stack containing OpenTelemetry Core
2.0.0 (GHSA-8988-4f7v-96qf); its compatible Core versions include the 2.8.0 fix.
Keep these overrides when generating a package, since the exporter's `latest`
tag still selects the older release. No custom OAuth provider is supplied here;
applications adding HTTP OAuth must also follow the MCP advisory's credential
issuer-binding and migration requirements.
The CLI brings its server dependency transitively; no separate server pin is
needed here. YAML is used by template tests. The committed lockfile was
regenerated from public npm and uses canonical registry URLs and SHA-512
integrity hashes. Preserve direct pins and security overrides when regenerating.
Do not hand-repair hashes or resolve through a private mirror. Use a clean
resolution directory with copies of this package's manifest and registry
configuration, no existing lockfile, and no installed dependencies:

```powershell
npm install --package-lock-only --ignore-scripts --registry=https://registry.npmjs.org/
```

Inspect and replace only this package's lockfile. Then run `npm ci`, the package
tests, and the host's public dependency-feed check.

## Author A Native Package

For a small complete authoring example, use
[Author Your First A/B Evaluation](first-evaluation.md).

Use the [copy map](../SKILL.md#assemble-and-validate). Generate its own lockfile.
Put the public task and required interfaces in the eval prompt and fixtures.
Keep role maps, private checks, reviews and previous outputs outside candidate
inputs. Stage only needed sources, not an entire authoring workspace.

Both variants explicitly list complete skill arrays, with shared skills in both
and the focus skill only in treatment. Keep every other condition identical.
The candidate template demonstrates public completion and delivery checks only.
Copy the [grade-only template](../assets/native-grade-eval.template.yaml) for
separate protected executable quality grading of each completed native trial.
The optional [review template](../assets/native-review-eval.template.yaml)
demonstrates native saved-evidence `prompt` grading in a separate invocation.
Replace task/checker/rubric placeholders, remove methods that do not fit and
agree judge usage before execution. `capability`
and `regression` are Vally classifications, not choices of grading method.
Keep the existing-skill and repository-origin routes on this same execution path.

Use native public delivery graders during collection. The grade-only `program`
prelude supplies the protected checker seam; reuse task tests/validators behind
that entry point rather than staging a private `run-command` in the candidate
workspace. Disclose the checked contract, not a command to a withheld evaluator.
Author the exact same stimulus name in both specs and replace every placeholder.
Pin the reviewed checker's SHA-256 in the trusted grade config, outside candidate
authority. Its authored entry point is relative to the protected assets root.
The checker receives the disclosed submission-relative output as `process.argv[2]`
with the submission root as its working directory; writable scratch remains at
`EVALUATE_WORKSPACE`. Keep stdout silent; return normally/exit 0 for pass, exit 1
for task failure and throw for broken checker execution. The prelude reports
prerequisite/body errors through native `status: error`, not a task-quality zero.
Adapt the checker to classify invalid task content intentionally.
When an entry point delegates to another process, retain its stdout/stderr
diagnostics before reporting a task-failure exit code. An unexplained exit1
does not establish which notebook cell or checker condition failed; reproduce
diagnostically in a separate approved offline scratch environment, never by
editing the submission or overwriting the original grade.

Test passing alternatives, wrong/missing output and broken checker setup.
Inspect actual native grader-error details, not just process exit.
Do not return success plus a private "uninspected" flag: native reports do not
interpret that as unavailable.

### Separate Public, Grading And Review Inputs

Use these three scopes, not a copied authoring workspace:

* `fixtures/<task>/public` contains only the public request, sources and required
  interfaces. The candidate template stages it at `task-fixture`.
* `grading/<task>` is the reviewed original evaluator/dependency tree, outside
  candidate mounts. Pass it explicitly as native `--assets-dir` only for
  separate offline grading; neither spec uses a private workspace overlay.
  Never execute a workspace or `task-fixture` substitute as the trusted checker.
  Do not remove legitimate public tools from the full focus skill.
* A completed host-owned arm-specific submission snapshot supplies native
  `--artifact-dir`. Preserve the original record and record the binding in
  EVALS.md; a directory's existence is not complete immutable export evidence.
* An evaluator-owned saved-review directory contains only one submission's
  approved artifacts and needed original public sources. Exclude private
  evaluators, focus-skill trees, role maps, EVALS.md, prior assessments and
  review helpers. Review inputs are not candidate inputs or the executable
  grading workspace.

Declare the checker's interpreter, entry point and locked dependency closure in
EVALS.md. For example, an ESM catalog checker importing `yaml` needs a trusted
grader-local installation resolved from its own location, not candidate
`node_modules`, an ambient authoring install or `NODE_PATH`. Prepare dependencies
outside candidate authority before offline grading; do not fetch them during it.
Verify that the selected native backend actually stages the required closure.

The prelude consumes only reserved native `EVALUATE_ASSETS`,
`EVALUATE_ARTIFACT_DIR` and `EVALUATE_WORKSPACE` roots. It rejects missing or
overlapping roots, invalid/escaping or linked input paths and missing/mismatched
trusted checker digests before checker-body entry. It hashes the actual entry
point immediately before import. This authenticates that file, not its complete
dependency closure or the arm identity. Readonly inputs and independently trusted
dependency provisioning remain necessary against changes after authentication.
Missing output under intact correctly bound inputs is a task failure without a
checker-body claim; unavailable roots/checker or integrity/startup errors are
operationally invalid. Original errors/skips/null trajectories stay unavailable
as fresh quality evidence. Do not invent missing native subprocess metadata.
Unverified read-only mounts, integrity timing, artifact export, image identity,
credential removal or egress denial block runtime acceptance; do not substitute
a writable local grade or claim these YAML files enforce them.

### Run Native Experiments, Grade Each Trial, Then Review Saved Evidence

Keep `experiment run` for collection and public delivery checks. Use the same
candidate eval and complete skill arrays for both variants. Vally owns
repetitions, staging, identities, results and cleanup; no skip-grade flag or
custom collector is needed. Preserve its per-variant `results.jsonl` files.
Native `grade` consumes their original `trial-result` records directly;
`vally export` exports eval specifications, not saved outcomes.

Verify fresh candidate homes and unique sessions/workspaces through native
behavior. If separate arm invocations are necessary, use native `--variant`
selection from the same experiment file. Retain the planned order and native
pair identities in EVALS.md; do not add a scheduler or pairing engine.

For each completed trial, select exactly one original record and one explicitly
bound completed snapshot. Preserve original file/record hashes, native identities,
eval/config hashes, snapshot origin/digest, trusted checker/dependency provenance
and the exact new grade command/output link in EVALS.md. Native grade output
drops outer item/variant/trial/experiment metadata; do not pair it by order alone.
With native `--workspace` preservation, verify the original `workspacePath`
and its readable completed output; do not assume `trajectory.artifactDir`
exists or add it to the original record to make grading work.
Successful nonnull trajectories are freshly graded even with earlier passing
public grades. Non-success/null trajectories can pass through without dispatch.

The following PowerShell recipe is illustrative and gated, not a verified runtime
profile or permission to execute. Supply compatible selected native images and
pre-created, distinct host-owned inputs/scratch and a fresh output location.
Only the original single record enters stdin; do not fabricate a trajectory.

```powershell
Get-Content -Raw .\selected-original-trial.jsonl | npm run vally -- grade `
  --eval-spec .\evals\<task>.grade.eval.yaml --output jsonl --require-pass `
  --backend docker --backend-args "task-image=<compatible-image>" `
  --backend-args "grade-image=<compatible-image>" `
  --backend-args task-network=none --backend-args grade-network=none `
  --workspace "<fresh-scratch>" --assets-dir "<trusted-checker-tree>" `
  --artifact-dir "<bound-submission-snapshot>" > .\fresh-grade-output.jsonl
```

These overrides apply to every input record: never submit a multi-arm batch with
one artifact directory. A valid opposite-arm snapshot can still pass vanilla
native grading; operator-owned binding is a prerequisite, not an automatic check.
Require readonly authoritative checker/submission paths, writable scratch, no
model credentials, denied grade egress and verified native lifecycle. No LLM
grader/provider is configured in this grade-only spec. Preserve all attempts
and errors and never overwrite original reports or rerun candidates to repair
grading. Source/local mechanics do not establish actual-route containment.

Only after offline capture succeeds, assemble and approve the one-submission
review directory and snapshot coverage. For optional online text review, feed
that trial to native `grade --eval-spec evals/<task>.review.eval.yaml --workspace`
with that approved directory. The command reads JSONL from stdin, not a positional
results-file argument. `--workspace` overrides every input record, so never feed
multiple submissions into one such invocation. Use the same public task and
preselected rubric for both independent reviews, without role labels.

The separate review spec is needed because saved grading selects its graders
from the spec, not a per-grader CLI flag. Configure review authentication only
in that online role. The published 0.19.0 package configures `view`, `grep` and
its verdict tool for workspace evidence, with permission handling separate from
the candidate adapter. This is inspected package configuration, not
runtime verification. Do not add execution tools, executable graders, candidate
setup hooks or rendering to online review. If required restrictions cannot be
verified, stop automatic text review and retain explicit human review.
Render untrusted artifacts only in the verified credential-free offline role,
retain its actual exported pixels, then use image review or human visual review.

These are source contracts, not an approved runtime recipe. Coordinated
release-matched pins/locks, backend lifecycle tests and observed role controls
remain final-integration gates. Do not silently switch code-execution tasks to
source-only assessment.

## Validate Without Spending

Run from the generated package root, replacing task/model placeholders:

```powershell
npm ci
npm run vally -- lint --strict --eval-spec evals/<task>.eval.yaml
npm run vally -- lint --strict --eval-spec evals/<task>.grade.eval.yaml
npm run vally -- lint --strict --eval-spec evals/<task>.review.eval.yaml
npm run study:dry-run -- experiments/<task>.experiment.yaml --param AGENT_MODEL=<id>
```

The dry-run uses native Vally without loading the inventory recorder or starting
candidate sessions. It loads and validates the shared executor plugin, unlike
the static lint command, which does not validate an unregistered plugin's
policy. It does not establish agent startup, effective permissions, containment
or budget enforcement. Do not add `--executor-plugin` to `lint`: the inspected
released lint command does not expose that option.

Keep optional native `prompt` review separate from executable grading. Put task-quality
criteria in the stimulus rubric and select evidence explicitly. For artifact
tasks, use `repo` rather than assuming the final response contains the files.
Follow [source-grounded review](holistic-review.md) to inspect approved saved
snapshot coverage, protect original sources and avoid condition leakage.
Include completed offline results only when relevant and explicitly approved;
native graders do not automatically receive another grader's output.

Count model judges as paid execution. The native prompt client can issue reminder
turns and retry failures; one configured grader is not a hard one-call cap.
Use [SDK image review](visual-review.md) for actual pixels after capture. Its
separate command has no scripted retries, but neither path enforces a credit cap.

## Execute An Approved Run Plan

Before paid calls, record the models, tasks, variants, repetitions, candidate
sessions, model graders, image reviews and native retry/reminder behavior in
EVALS.md. Use dry-run to confirm the candidate plan, then obtain explicit operator
approval of that scope and budget, including the disclosed risk of overspend.
State whether that budget is a supervised target or a required enforced maximum.
Approve manual reruns and scope changes separately; a failed attempt still
consumes usage.

Use available native time/concurrency limits and provider spending controls.
The selected Vally execution profile and helpers do not enforce a hard credit ceiling.
Timeouts, manual monitoring and post-run reports cannot guarantee a monetary cap.
If the operator requires one, stop until the provider or runtime can enforce it.
Do not add a custom spending controller. Spending approval does not waive
candidate, grader, credential or evidence-security prerequisites.

The generated package omits `study:run` and `review:images` paid convenience
scripts while this profile has no enforceable spending ceiling. It retains
`study:dry-run` for plan inspection, the raw `vally` CLI passthrough and the
image helper. The latter two still permit manual paid execution: omission is
not a spending cap, sandbox or guarantee that no model can be invoked.
Keep paid execution deferred until the separate exact-stack, role-security,
spending and operational prerequisites are satisfied.
There is no approved restricted-runtime command recipe yet; do not substitute
unrestricted local execution. No custom launcher or separate collection path is
needed.

Each invocation needs fresh native output and preserved-workspace locations.
Before staging a repeated full-checkout batch, measure its per-session workspace
and output footprint and verify enough free space for all retained copies plus
operational headroom. A successful single-session smoke test does not establish
batch storage capacity. Recheck capacity before subsequent invocations and stop
before starting another when space is insufficient. Keep disk-full staging,
empty/truncated native records and failed status writes as operational failures;
do not manufacture replacement results. Publish operator status atomically from
a flushed temporary file rather than truncating the last valid status in place.
On Windows choose a short workspace root before execution; nested audit filenames
can exceed Git's path limit. Verify actual native `workspace.patch` retention,
not merely directory existence. Preserve capture warnings as missing evidence;
do not rewrite a failed run into a complete one or change global Git settings.
Use native `--workspace` preservation and retain each trial's audit directory
alongside its original native record. Record the exact command,
role mapping and output location in EVALS.md. Inspect results and reported usage
before authorizing the next invocation. Do not start the next invocation when the
approved scope is complete or reported usage reaches the agreed target. This
does not promise cancellation of an in-flight call, reminder or native retry.
Missing or incomparable usage stays unknown, not zero or proof of budget
compliance. Pause for explicit continuation unless existing approval already
covers that specific bounded unknown-usage scope. Do not automate silent reruns.
Any separately authorized manual native experiment invocation must use the
pinned Vally CLI and load the session-policy plugin explicitly.
The retained `vally` passthrough forwards native arguments and exit status; it
does not select the plugin automatically, preload a process-wide SDK wrapper or
require `SKILL_EVAL_INVENTORY_DIR`. Selecting a different executor
bypasses this plugin's policy and inventory capture and is not an equivalent run.

Wait for the native experiment to complete and its results JSONL to be flushed
before offline grading. A terminal delivery announcement is not a saved record.
Verify that the original record exists before creating fresh grade scratch or
piping input. A zero experiment CLI exit code or a generic `completed` pass does
not erase failed delivery, tool denials or missing audit artifacts. Keep these
outcomes separate from protected task checks and substantive quality review.

## Publisher Iteration, Repetition And Pairing

Start with a useful comparison, not a required number of runs. An initial pair
can expose an unsuitable task or a measure that misses the claimed benefit.
The publisher may improve the skill or evaluation, record the changes in EVALS.md
and preserve earlier results. Examples tuned this way are development evidence.
Publisher inspection can guide iteration without pretending to be independent
review or an automatic quality verdict.

For a repeat batch, agree the count and spending scope, then keep the skill,
task, inputs and assessment fixed. Native `overrides.runs: N` repeats each
task/model/variant combination; one task and two variants means 2*N candidate
sessions. Count all experiment files and combinations before spending, and use
dry-run to confirm the plan. Report every trial. Rejudging saved outputs does
not create fresh candidate trials, and repetition does not improve a bad measure.

Vally orders variant IDs lexically. The template uses `a-baseline` and
`b-treatment`, with `baseline: a-baseline`. For a treatment-first pair, copy the
native experiment under a distinct name, use `a-treatment` and `b-baseline`,
set `baseline: b-baseline`, and retain each role's correct skill array.
Increasing `overrides.runs` does not alternate variant order. To alternate pairs,
keep `overrides.runs: 1` in separate native experiment files and reverse roles
between files within the agreed budget. A repeated fixed-order batch is also
possible; disclose its order imbalance rather than claiming counterbalancing.

Record which experiment files form the planned pairs. Use native task, variant,
trialIndex and session identities (including itemId/shardKey where present).
Native single-trial records can omit trialIndex; use their native task/variant
identity and unique itemId/shardKey rather than inventing a repetition number.
Never infer pairing from file order or replace missing attempts with another
repetition. No duplicate schedule format or cross-block analyzer is supplied.

## Inspect The Evidence

The [recorder](../scripts/native-inventory.mjs) saves actual skill metadata after
SDK initialization. The session-policy factory captures it and independently
publishes a byte-identical backup before returning that session for its first
prompt. Each execution creates a unique `skill-evidence-*`
directory beneath the explicit durable `executor.config.auditDirectory`,
outside the candidate workspace and native temporary session-log directory.
Retain this audit root alongside native `--output-dir` and separate `--workspace`
roots. Missing, relative or overlapping audit paths reject before native execution;
canonical-path overlap also rejects. Direct executor callers supply that same
configuration. The actual CLI export/cleanup regression verifies both arms'
audit files survive after native temporary log deletion.
The audit directory contains `<session-id>.json`,
`startup-backups/<session-id>.json` and the completion
`<session-id>.verification.json`. Filenames encode the actual SDK session ID.
The two copies are separate files, not hard-linked aliases of one mutable inode.

Snapshots retain enabled states, runtime source paths when available, requested
skill directories, timestamp and actual session ID. The restricted adapter
rejects enabled skills outside the explicitly requested directories; the separate
diagnostic recorder alone does not enforce that check. Baseline still must not
receive treatment-only skill contents.

After native execution and its cleanup return, the plugin compares both copies
against the digest retained in per-execution memory. Changed or missing copies,
shared-inode backups, redirected paths and failed verification-report publication
are operational errors. Verification also runs when native execution throws;
neither failure masks the other. The report records the expected digest, session
identity and verification outcome without replacing altered originals. A verified
inventory does not turn a failed native trial into a successful trial.
Missing reports or partial backups are not verified evidence.

Retain the durable audit root and native output directory as well as the preserved candidate workspace.
The workspace copy alone no longer contains audit records. Match external audit
files to the original trial's session/workspace identity and expected digest.
Keep operator policy receipts and audit metadata outside candidate workspaces,
including outside their directory listings; denying a read after exposing an
irrelevant audit name can still derail an otherwise legitimate task. Do not
include audit or policy files in the deliverable-only
snapshot bound to offline grading or in blinded saved-evidence review inputs.
These are ordinary supervised consistency checks, not an adversarial host-owned
audit store. They do not stop a process with equivalent authority from changing
code, memory or every persisted copy, and do not provide grader protection.
The actual no-prompt retention check above passed on its tested frozen profile;
materially different native preservation layouts need their own verification.

Initialization, skill listing and failure-path disconnect each have a bounded
wait of at most ten seconds. A timeout does not cancel the RPC or prove shutdown.
Capture/backup failure stops that session before return and attempts disconnect;
native Vally still owns execution, results and cleanup. Stop further execution
until the operator checks an unverified shutdown.
Complete bytes publish without replacing existing destinations; the filesystem
must support same-directory hard links. Independent backup reads are limited
to 16 MiB and check regular-file identity, size and modification time.

### Optional Completed Session Log Backup

Native session history can help explain a result but may omit transient inventory.
Keep native logs and records as originals. After the session has stopped, an
operator may explicitly back up one selected regular log file:

```powershell
node .\scripts\native-inventory.mjs backup-log `
  --source "C:\approved-evidence\trial\events.jsonl" `
  --output "C:\approved-evidence\log-backups\trial-events.jsonl"
```

Use actual absolute paths and a new output filename. The helper copies complete
nonempty files up to 16 MiB, rejects links and observable changes during reading,
and exclusively writes the copy plus `<output>.metadata.json` with source,
timestamp, byte count and SHA-256. Publication failure is an error even when a
partial pair remains; retain it for inspection, not as a completed backup.
It does not scan homes, collect arbitrary session trees, upload logs or redact
content. Metadata goes to stdout, never log contents. Private-file modes apply
where supported, not a custom Windows ACL guarantee.

Logs may contain prompts, source, paths or credentials. Select and protect them,
and review before sharing. Link the chosen file/digest to its native trial in
EVALS.md. A snapshot does not prove complete history or independent provenance.
Later growth of the original log is expected, not startup-inventory tampering.

The separately invoked diagnostic preload still supports
`SKILL_EVAL_INVENTORY_DIR` for explicit no-prompt investigation. Its prototype
hook and failure records are not used by the generated native run command.
Retain original bytes or their digest independently when checking later changes.
An altered or deleted record invalidates that evidence; a hash stored beside a
same-user-writable file does not make either authoritative. This diagnostic
limitation does not itself establish an environment escape or compromised grade.

Inspect baseline for focus-skill leakage, including copies at other paths/names;
check treatment availability and understand other context differences. Shared
unrelated skills do not automatically invalidate a comparison. Check native skill
activations and access traces for other outputs, private checks or external inputs.
No recorded invocation does not prove no availability or influence.

Missing snapshots, necessary source paths or logs remain unverified. A startup
snapshot does not cover later context changes, and native permissions can permit
access outside the workspace. This is supervised detection, not enforced isolation
or an OS sandbox. Preserve contaminated attempts, apply symmetric exclusions and
authorize replacements separately. A complete native report is not a clean bill
of integrity.

## Report Without A Second Reporting System

Link Vally's actual run directory, native report, raw trial records, workspaces
and inventories. Keep separate human/Copilot assessments beside that evidence,
with their inputs, limits and failures. Neither narrative findings nor later
visual reviews retroactively change native grades.

Distinguish a completed check scoring zero, missing candidate output, evaluator
unavailability and operational errors. Preserve native error status even when its
message is empty. Inspect individual grader results; do not interpret the aggregate
as task quality or a skill-effect verdict. Unknown usage stays unknown.

Write paired observations, variation, exclusions and limitations in EVALS.md.
Address the claimed benefit separately from delivery/check pass rates. For
example, successful C4 rendering establishes valid diagrams; examining abstraction
levels, relationship clarity and actual-image legibility addresses a communication
claim. Explain a preference with evidence, allow ties, and identify the reviewer.
There is no generated analysis.json, combined effect report or RESULTS.md updater.
Small pilots do not establish general effectiveness or equivalence.
