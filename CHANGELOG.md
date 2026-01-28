---
title: Changelog
description: Automatically generated changelog tracking all notable changes to the HVE Core project using semantic versioning
---

<!-- markdownlint-disable MD012 MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note:** This file is automatically maintained by [release-please](https://github.com/googleapis/release-please). Do not edit manually.

## [2.0.0](https://github.com/microsoft/hve-core/compare/hve-core-v1.1.0...hve-core-v2.0.0) (2026-01-28)


### ⚠ BREAKING CHANGES

* **agents:** add Task Reviewer and expand RPI to 4-phase workflow ([#277](https://github.com/microsoft/hve-core/issues/277))

### ✨ Features

* **agents:** add hve-core-installer agent to extension package ([#297](https://github.com/microsoft/hve-core/issues/297)) ([c0e48c6](https://github.com/microsoft/hve-core/commit/c0e48c60dabb2f43a34c1f14660aded66440b982))
* **agents:** add Task Reviewer and expand RPI to 4-phase workflow ([#277](https://github.com/microsoft/hve-core/issues/277)) ([ae76cab](https://github.com/microsoft/hve-core/commit/ae76cabe11935094b33c4c87a51e8e8bd5c72488))
* **build:** add code coverage reporting to Pester workflow ([#230](https://github.com/microsoft/hve-core/issues/230)) ([a34822a](https://github.com/microsoft/hve-core/commit/a34822a04208f40d9dc15baf92702e4636bf81de))
* **docs:** add GOVERNANCE.md for OSSF Silver Badge compliance ([#235](https://github.com/microsoft/hve-core/issues/235)) ([b0e752c](https://github.com/microsoft/hve-core/commit/b0e752c1811bd3dc5ac9ddf5fea9c48c92a6d550))
* **docs:** add ROADMAP.md for OSSF Silver badge compliance ([#238](https://github.com/microsoft/hve-core/issues/238)) ([4a41c16](https://github.com/microsoft/hve-core/commit/4a41c16480d70f3687c116c380f03e7eac2fb347))
* **mcp:** add MCP server configuration guidance and installer enhancements ([#225](https://github.com/microsoft/hve-core/issues/225)) ([0bce418](https://github.com/microsoft/hve-core/commit/0bce418ef9a17e5e311d7cc01dc4e8ac699aa51f))
* **scripts:** add YAML linting with actionlint ([#234](https://github.com/microsoft/hve-core/issues/234)) ([d9301f9](https://github.com/microsoft/hve-core/commit/d9301f932669f9e0ffb13fef412ab9563701a3ae))
* **security:** add OpenSSF Scorecard workflow and badge ([#271](https://github.com/microsoft/hve-core/issues/271)) ([7c6d788](https://github.com/microsoft/hve-core/commit/7c6d7888986c9c77398648add958221a3ef63216))
* **skills:** add video-to-gif conversion skill with FFmpeg two-pass optimization ([#247](https://github.com/microsoft/hve-core/issues/247)) ([8d65c42](https://github.com/microsoft/hve-core/commit/8d65c427efb6a90a4b4a483ad7756f6157667bca))
* **tests:** add Pester tests for LintingHelpers and Validate-MarkdownFrontmatter ([#197](https://github.com/microsoft/hve-core/issues/197), [#198](https://github.com/microsoft/hve-core/issues/198)) ([#205](https://github.com/microsoft/hve-core/issues/205)) ([51ae563](https://github.com/microsoft/hve-core/commit/51ae563a213909937f96eacd722a38a9644367aa))


### 🐛 Bug Fixes

* **build:** detect table formatting changes via git diff ([#261](https://github.com/microsoft/hve-core/issues/261)) ([985eee0](https://github.com/microsoft/hve-core/commit/985eee0cc4215b6b69803fdb83c63182c03287bb))
* **build:** disable MD024 lint rule in CHANGELOG for release-please ([#220](https://github.com/microsoft/hve-core/issues/220)) ([971df94](https://github.com/microsoft/hve-core/commit/971df94b11b0333843189fc457720c0913a4a5c1))
* **build:** quote shell variables and group redirects in workflow files ([#299](https://github.com/microsoft/hve-core/issues/299)) ([3372509](https://github.com/microsoft/hve-core/commit/337250909ffa2c4788fd9312bb858b51b446917b))
* **build:** resolve scorecard badge and workflow security issues ([#301](https://github.com/microsoft/hve-core/issues/301)) ([aeaed13](https://github.com/microsoft/hve-core/commit/aeaed13699523fba9ac03bc4b9d223969e2b34e6))
* **extension:** remove frontmatter from README and exclude from markdown linting ([#223](https://github.com/microsoft/hve-core/issues/223)) ([4272529](https://github.com/microsoft/hve-core/commit/427252962228e190054815d472bcc6aa5adc3b96))
* **instructions:** quote applyTo glob pattern for YAML compatibility ([#216](https://github.com/microsoft/hve-core/issues/216)) ([085199c](https://github.com/microsoft/hve-core/commit/085199c8820ac0910742ddf6c8a2dda0cce61f46))
* **scripts:** add FooterExcludePaths parameter to frontmatter validation ([#334](https://github.com/microsoft/hve-core/issues/334)) ([64db98d](https://github.com/microsoft/hve-core/commit/64db98d26189017208391388daf3c2b24e50d549))
* **scripts:** add GHSA word and logs/ exclusion to cspell config ([#214](https://github.com/microsoft/hve-core/issues/214)) ([5c99b3f](https://github.com/microsoft/hve-core/commit/5c99b3f81b316a76d0313a1c85ac08bfa651ef8c))
* **scripts:** correct type assertions in Invoke-YamlLint.Tests.ps1 ([#332](https://github.com/microsoft/hve-core/issues/332)) ([af7050d](https://github.com/microsoft/hve-core/commit/af7050df973aaeb44be5a298d39a7544c27ed4bc))
* **scripts:** eliminate false positives in dependency pinning npm pattern ([#273](https://github.com/microsoft/hve-core/issues/273)) ([ccbdfa3](https://github.com/microsoft/hve-core/commit/ccbdfa3d84d057bc633e17edbd7a7dd1b7e16d84))
* **security:** add artifact attestation for signed releases ([#257](https://github.com/microsoft/hve-core/issues/257)) ([c52d6e2](https://github.com/microsoft/hve-core/commit/c52d6e268f8e9130579003f14d53c0a47638bb79))
* standardize markdown footers and complete frontmatter ([#217](https://github.com/microsoft/hve-core/issues/217)) ([b4e7556](https://github.com/microsoft/hve-core/commit/b4e75565b1476bdb4e2d2846f432373a616e8bfa))


### 📚 Documentation

* add OpenSSF Best Practices Passing badge to README ([#239](https://github.com/microsoft/hve-core/issues/239)) ([91bc529](https://github.com/microsoft/hve-core/commit/91bc5296db759087346f08879f15aeda1d1d4c4f))
* **architecture:** add architecture documentation and value proposition ([#252](https://github.com/microsoft/hve-core/issues/252)) ([0e4b02f](https://github.com/microsoft/hve-core/commit/0e4b02f92bfe8ff18332714fb19a08aa217b01ac))
* **contributing:** add testing requirements for OSSF compliance ([#254](https://github.com/microsoft/hve-core/issues/254)) ([4db1a18](https://github.com/microsoft/hve-core/commit/4db1a1861e935170ded1f7c0c3f6ef278eedd186))
* **docs:** add enterprise status badges to README header ([#270](https://github.com/microsoft/hve-core/issues/270)) ([ccb68a4](https://github.com/microsoft/hve-core/commit/ccb68a481e755d669057f9f70a5d82f89fc47191))
* **security:** add security assurance case and threat model for OSSF Silver ([#259](https://github.com/microsoft/hve-core/issues/259)) ([a390e26](https://github.com/microsoft/hve-core/commit/a390e26bc00f746794c51d2e1a3281afdebe4250))


### ♻️ Refactoring

* **application:** wrap execution with try blocks, ensure proper … ([#296](https://github.com/microsoft/hve-core/issues/296)) ([35c4417](https://github.com/microsoft/hve-core/commit/35c44178ff7bca70f390a987ebb51767cda375a4))
* **scripts:** extract frontmatter validation to testable module ([#293](https://github.com/microsoft/hve-core/issues/293)) ([4e8707e](https://github.com/microsoft/hve-core/commit/4e8707eb77ae3bf201e93c403106865ed534514b))
* **scripts:** extract pure functions for Pester testability ([#221](https://github.com/microsoft/hve-core/issues/221)) ([d40e742](https://github.com/microsoft/hve-core/commit/d40e742b4e4673bb9323da3aecd0c255f1897aa6))


### 🔧 Maintenance

* **deps-dev:** bump cspell from 9.4.0 to 9.6.0 in the npm-dependencies group ([#208](https://github.com/microsoft/hve-core/issues/208)) ([855914b](https://github.com/microsoft/hve-core/commit/855914b95a43d90e7331bfc93b8ffbb4ffd7263b))
* **deps-dev:** bump cspell from 9.6.0 to 9.6.1 in the npm-dependencies group ([#294](https://github.com/microsoft/hve-core/issues/294)) ([1e45ad6](https://github.com/microsoft/hve-core/commit/1e45ad6f1cd3e713db35e394c2a2dd2b270f14dc))
* **deps:** bump actions/setup-node from 6.1.0 to 6.2.0 in the github-actions group ([#209](https://github.com/microsoft/hve-core/issues/209)) ([c4c69e2](https://github.com/microsoft/hve-core/commit/c4c69e283888fa8e4dd58fab89659a89555428c9))
* **deps:** bump the github-actions group with 4 updates ([#295](https://github.com/microsoft/hve-core/issues/295)) ([d8337b8](https://github.com/microsoft/hve-core/commit/d8337b8b280f516f0425abedd1b574d9e84f33f3))
* remove step-security/harden-runner from workflows ([#246](https://github.com/microsoft/hve-core/issues/246)) ([c5708d8](https://github.com/microsoft/hve-core/commit/c5708d8169d62425c8749b4d88aa50f05e07df5f))

## [1.1.0](https://github.com/microsoft/hve-core/compare/hve-core-v1.0.0...hve-core-v1.1.0) (2026-01-19)


### ✨ Features

* **.devcontainer:** add development container configuration ([#24](https://github.com/microsoft/hve-core/issues/24)) ([45debf5](https://github.com/microsoft/hve-core/commit/45debf564f3dfd1f9f8f1d09e1ec649512540d95))
* **.github:** add github metadata and mcp configuration ([#23](https://github.com/microsoft/hve-core/issues/23)) ([1cb898d](https://github.com/microsoft/hve-core/commit/1cb898d143b805f8136038091866e17484296680))
* **agent:** Add automated installation via hve-core-installer agent ([#82](https://github.com/microsoft/hve-core/issues/82)) ([a2716d5](https://github.com/microsoft/hve-core/commit/a2716d5c9ca20cad206c2873d884669dab41d630))
* **agents:** add brd-builder.agent.md for building BRDs ([#122](https://github.com/microsoft/hve-core/issues/122)) ([bfdc9f3](https://github.com/microsoft/hve-core/commit/bfdc9f362c7f24c120fb2785d9fccca507da3521))
* **agents:** redesign installer with Codespaces support and method documentation ([#123](https://github.com/microsoft/hve-core/issues/123)) ([6329fc0](https://github.com/microsoft/hve-core/commit/6329fc0d14af6f09dd31e4d2dc90586a620ee42e))
* **ai:** Establish AI-Assisted Development Framework ([#48](https://github.com/microsoft/hve-core/issues/48)) ([f5199a4](https://github.com/microsoft/hve-core/commit/f5199a483a7591fb09ec219684cb2c2edb847c3c))
* **build:** implement automated release management with release-please ([#86](https://github.com/microsoft/hve-core/issues/86)) ([90150e2](https://github.com/microsoft/hve-core/commit/90150e2c2902723bfd26321f9456cd930c597e12))
* **chatmodes:** add architecture diagram builder agent ([#145](https://github.com/microsoft/hve-core/issues/145)) ([db24637](https://github.com/microsoft/hve-core/commit/db246371cf681aa47e2bc4df3d2e4bade724f265))
* **config:** add development tools configuration files ([#19](https://github.com/microsoft/hve-core/issues/19)) ([9f97522](https://github.com/microsoft/hve-core/commit/9f97522557d7ebc0f42f2472fac33f0d87af6ebd))
* **config:** add npm package configuration and dependencies ([#20](https://github.com/microsoft/hve-core/issues/20)) ([fcba198](https://github.com/microsoft/hve-core/commit/fcba198044b55eadab3507a6c13a3d28d1622bbe))
* **copilot:** add GitHub Copilot instruction files ([#22](https://github.com/microsoft/hve-core/issues/22)) ([4927284](https://github.com/microsoft/hve-core/commit/4927284d6acab6d463cfe07c9cc1ff7475903ef4))
* **copilot:** add specialized chat modes for development workflows ([#21](https://github.com/microsoft/hve-core/issues/21)) ([ae8495f](https://github.com/microsoft/hve-core/commit/ae8495fa3cca7814df58395f3b99d75bcafcd2c6))
* **docs:** add comprehensive AI artifact contribution documentation ([#76](https://github.com/microsoft/hve-core/issues/76)) ([d81cf96](https://github.com/microsoft/hve-core/commit/d81cf96697ace7b4850014c917f4393939f0d2df))
* **docs:** add getting started guide for project configuration ([#57](https://github.com/microsoft/hve-core/issues/57)) ([3b864fa](https://github.com/microsoft/hve-core/commit/3b864fae1402f8602faa5332b6b7dcb99be52174))
* **docs:** add repository foundation and documentation files ([#18](https://github.com/microsoft/hve-core/issues/18)) ([ad7efb6](https://github.com/microsoft/hve-core/commit/ad7efb624737d9b472b4293b6485096d8b345954)), closes [#2](https://github.com/microsoft/hve-core/issues/2)
* **docs:** add RPI workflow documentation and restructure docs folder ([#102](https://github.com/microsoft/hve-core/issues/102)) ([c3af708](https://github.com/microsoft/hve-core/commit/c3af708c39a4db1cd35d2ffd0d15db2bbe6dd0da))
* **extension:** hve core vs code extension ([#149](https://github.com/microsoft/hve-core/issues/149)) ([041a1fd](https://github.com/microsoft/hve-core/commit/041a1fd7e0ca46b2511a322c5fabe67ad2584d30))
* **extension:** implement pre-release versioning with agent maturity filtering ([#179](https://github.com/microsoft/hve-core/issues/179)) ([fb38233](https://github.com/microsoft/hve-core/commit/fb38233f97ce1004e36e381c43fb9a9034aff85e))
* **instructions:** add authoring standards for prompt engineering artifacts ([#177](https://github.com/microsoft/hve-core/issues/177)) ([5de3af9](https://github.com/microsoft/hve-core/commit/5de3af9de3957d9a1b2d7b75a2472cadf628fca9))
* **instructions:** add extension quick install and enhance installer agent ([#176](https://github.com/microsoft/hve-core/issues/176)) ([48e3d58](https://github.com/microsoft/hve-core/commit/48e3d58c49a889c8a3ab71e76d85b47d7aa1cdca))
* **instructions:** add VS Code variant prompt and gitignore recommendation to installer ([#185](https://github.com/microsoft/hve-core/issues/185)) ([b400493](https://github.com/microsoft/hve-core/commit/b4004939f770bf1b28114505049f6896c76dd2c8))
* **instructions:** add writing style guide for markdown content ([#151](https://github.com/microsoft/hve-core/issues/151)) ([02df6a8](https://github.com/microsoft/hve-core/commit/02df6a852027fd2fff59fe36d485bdf4ced25156))
* **instructions:** consolidate C# guidelines and update prompt agent fields ([#158](https://github.com/microsoft/hve-core/issues/158)) ([65342d4](https://github.com/microsoft/hve-core/commit/65342d4261936e4efebd50e588985d37127b0a94))
* **instructions:** provide guidance on using safe commands to reduce interactive prompting ([#117](https://github.com/microsoft/hve-core/issues/117)) ([1268580](https://github.com/microsoft/hve-core/commit/12685800c475a9b5ce24736a8308ec6bcdc237c8))
* **linting:** add linting and validation scripts ([#26](https://github.com/microsoft/hve-core/issues/26)) ([66be136](https://github.com/microsoft/hve-core/commit/66be13677872fa97e2bb353a6649bc32f061f5b0))
* **prompt-builder:** enhance prompt engineering instructions and validation protocols ([#155](https://github.com/microsoft/hve-core/issues/155)) ([bc5004f](https://github.com/microsoft/hve-core/commit/bc5004f5976022a70e22f36e99f311fd02be7087))
* **prompts:** add ADR placement planning and update template paths ([#69](https://github.com/microsoft/hve-core/issues/69)) ([380885f](https://github.com/microsoft/hve-core/commit/380885f0663eddd7ace7d075039a46014f58ce8e))
* **prompts:** add git workflow prompts from edge-ai ([#84](https://github.com/microsoft/hve-core/issues/84)) ([56d66b6](https://github.com/microsoft/hve-core/commit/56d66b6fae5b2b913b46ee12fb7b094ffc0a32f8))
* **prompts:** add github-add-issue prompt and github-issue-manager chatmode with delegation pattern ([#55](https://github.com/microsoft/hve-core/issues/55)) ([d0e1789](https://github.com/microsoft/hve-core/commit/d0e1789229a8cf15505410fb4b8e9cd36cd7b95a))
* **prompts:** add PR template discovery and integration to pull-request prompt ([#141](https://github.com/microsoft/hve-core/issues/141)) ([b8a4c7a](https://github.com/microsoft/hve-core/commit/b8a4c7a6e3741f7cc5890873005487763bc0e116))
* **prompts:** add task research initiation prompt and rpi agent([#124](https://github.com/microsoft/hve-core/issues/124)) ([5113e3b](https://github.com/microsoft/hve-core/commit/5113e3ba24d61b036d34aca70a21f30bcafe528f))
* **release:** implement release management strategy ([#161](https://github.com/microsoft/hve-core/issues/161)) ([6164c3b](https://github.com/microsoft/hve-core/commit/6164c3b8f8ccfed506a77fe0fa7402e7d3fa7e12))
* Risk Register Prompt ([#146](https://github.com/microsoft/hve-core/issues/146)) ([843982c](https://github.com/microsoft/hve-core/commit/843982c05b8b580d86907a1703933af59b966f81))
* **scripts:** enhanced JSON Schema validation for markdown frontmatter ([#59](https://github.com/microsoft/hve-core/issues/59)) ([aba152c](https://github.com/microsoft/hve-core/commit/aba152cef7ec125532845f39822fedc5747a20d5))
* **security:** add checksum validation infrastructure ([#106](https://github.com/microsoft/hve-core/issues/106)) ([07528fb](https://github.com/microsoft/hve-core/commit/07528fb9e18406e8f90d4bd3f146acbf36c91a6a))
* **security:** add security scanning scripts ([#25](https://github.com/microsoft/hve-core/issues/25)) ([82de5a1](https://github.com/microsoft/hve-core/commit/82de5a16eba3c05b3e988b49e988565cf98e482a))
* **workflows:** add CodeQL security analysis to PR validation ([#132](https://github.com/microsoft/hve-core/issues/132)) ([e5b6e8f](https://github.com/microsoft/hve-core/commit/e5b6e8f52aadcc78f6af244457f38983f2668daf))
* **workflows:** add orchestration workflows and documentation ([#29](https://github.com/microsoft/hve-core/issues/29)) ([de442e0](https://github.com/microsoft/hve-core/commit/de442e0b57a39663d2a8e1e4bf1e8bd6e0af128c))
* **workflows:** add security reusable workflows ([#28](https://github.com/microsoft/hve-core/issues/28)) ([2c74399](https://github.com/microsoft/hve-core/commit/2c7439975c8fc2cb7713eab4b0681cfafc20167a))
* **workflows:** add validation reusable workflows ([#27](https://github.com/microsoft/hve-core/issues/27)) ([f52352d](https://github.com/microsoft/hve-core/commit/f52352df935ec65dbe0742f36575c2740aa06d71))


### 🐛 Bug Fixes

* **build:** add token parameter to release-please action ([#166](https://github.com/microsoft/hve-core/issues/166)) ([c9189ec](https://github.com/microsoft/hve-core/commit/c9189ec83e0664535d8c63177e3ab822ef982bc6))
* **build:** disable MD012 lint rule in CHANGELOG for release-please compatibility ([#173](https://github.com/microsoft/hve-core/issues/173)) ([54502d8](https://github.com/microsoft/hve-core/commit/54502d8a40d9fd2a25adea044f28e0157c932d97)), closes [#172](https://github.com/microsoft/hve-core/issues/172)
* **build:** pin npm commands for OpenSSF Scorecard compliance ([#181](https://github.com/microsoft/hve-core/issues/181)) ([c29db54](https://github.com/microsoft/hve-core/commit/c29db54feeaf25f57c898c4d686ad755cef9aad3))
* **build:** remediate GHSA-g9mf-h72j-4rw9 undici vulnerability ([#188](https://github.com/microsoft/hve-core/issues/188)) ([634bf36](https://github.com/microsoft/hve-core/commit/634bf368e370a86ad1def917ff07a41cf62b0479))
* **build:** seed CHANGELOG.md with version entry for release-please frontmatter preservation ([#170](https://github.com/microsoft/hve-core/issues/170)) ([2b299ac](https://github.com/microsoft/hve-core/commit/2b299ac8a8355722ffc36247b3f1a19650d9b878))
* **build:** use GitHub App token for release-please ([#167](https://github.com/microsoft/hve-core/issues/167)) ([070e042](https://github.com/microsoft/hve-core/commit/070e04286aa01c08755d8b0c0ab9b4653f9c8559))
* **build:** use hashtable splatting for named parameters ([#164](https://github.com/microsoft/hve-core/issues/164)) ([02a965f](https://github.com/microsoft/hve-core/commit/02a965ff0aee298061eeaf604f8cd1396bfa5694))
* **devcontainer:** remove unused Python requirements check ([#78](https://github.com/microsoft/hve-core/issues/78)) ([f17a872](https://github.com/microsoft/hve-core/commit/f17a872acc0cc72762d0d08534069ff191b5bb02)), closes [#77](https://github.com/microsoft/hve-core/issues/77)
* **docs:** fix broken links and update validation for .vscode/README.md ([#118](https://github.com/microsoft/hve-core/issues/118)) ([160ae7a](https://github.com/microsoft/hve-core/commit/160ae7ac5a5757f83b581cb4bdbb0ee667e15ba5))
* **docs:** improve language consistency in Automated Installation section ([#139](https://github.com/microsoft/hve-core/issues/139)) ([a932918](https://github.com/microsoft/hve-core/commit/a9329184105d969a17f5f648b4953067d36f8621))
* **docs:** replace install button anchor with VS Code protocol handler ([#111](https://github.com/microsoft/hve-core/issues/111)) ([41a265e](https://github.com/microsoft/hve-core/commit/41a265e758b9de030094b51857da7b3583fc2ae3))
* **docs:** update install badges to use aka.ms redirect URLs ([#114](https://github.com/microsoft/hve-core/issues/114)) ([868f655](https://github.com/microsoft/hve-core/commit/868f655bf3699f11d0fbe5646409d4e7e808072d))
* **linting:** use cross-platform path separators in gitignore pattern matching ([#121](https://github.com/microsoft/hve-core/issues/121)) ([3f0aa1b](https://github.com/microsoft/hve-core/commit/3f0aa1b1a2f99c05aae73b05540c0401ff0199fc))
* **scripts:** accepts the token (YYYY-MM-dd) in frontmatter validation ([#133](https://github.com/microsoft/hve-core/issues/133)) ([2648215](https://github.com/microsoft/hve-core/commit/26482154d9f2d82e8a8b12f7d04a2367337c3491))
* **tools:** correct Method 5 path resolution in hve-core-installer ([#129](https://github.com/microsoft/hve-core/issues/129)) ([57ef20d](https://github.com/microsoft/hve-core/commit/57ef20d38e6b8c2d17755c6e87d64ce8b1fc9837))


### 📚 Documentation

* add comprehensive RPI workflow documentation ([#153](https://github.com/microsoft/hve-core/issues/153)) ([cbaa4a9](https://github.com/microsoft/hve-core/commit/cbaa4a97f566ee024b8ba6aabd798ddb329a8e0f))
* enhance README with contributing, responsible AI, and legal sections ([#52](https://github.com/microsoft/hve-core/issues/52)) ([a424adc](https://github.com/microsoft/hve-core/commit/a424adc11b51839bf6553843b2f03f9cb7f88333))


### ♻️ Refactoring

* **instructions:** consolidate and enhance AI artifact guidelines ([#206](https://github.com/microsoft/hve-core/issues/206)) ([54dd959](https://github.com/microsoft/hve-core/commit/54dd95908c5e66d03c1ce21a583a2aa75ef15ab4))
* migrate chatmodes to agents architecture ([#210](https://github.com/microsoft/hve-core/issues/210)) ([712b0b7](https://github.com/microsoft/hve-core/commit/712b0b7b4d069880bb68e1c3cc062db96a370386))


### 🔧 Maintenance

* **build:** clean up workflow permissions for Scorecard compliance ([#183](https://github.com/microsoft/hve-core/issues/183)) ([64686e7](https://github.com/microsoft/hve-core/commit/64686e767009e4559fc82a122edda2410d9dbaf0))
* **deps-dev:** bump cspell in the npm-dependencies group ([#61](https://github.com/microsoft/hve-core/issues/61)) ([38650eb](https://github.com/microsoft/hve-core/commit/38650eb40986d81ff84b0fa555bed0966577198e))
* **deps-dev:** bump glob from 10.4.5 to 10.5.0 ([#74](https://github.com/microsoft/hve-core/issues/74)) ([b3ca9fd](https://github.com/microsoft/hve-core/commit/b3ca9fd773c82fa88edc9cfb51440d84857fffbf))
* **deps-dev:** bump markdownlint-cli2 from 0.19.1 to 0.20.0 in the npm-dependencies group ([#134](https://github.com/microsoft/hve-core/issues/134)) ([ebfbe84](https://github.com/microsoft/hve-core/commit/ebfbe847ff182393b5d0fbb28054b746ca246722))
* **deps-dev:** bump the npm-dependencies group across 1 directory with 2 updates ([#109](https://github.com/microsoft/hve-core/issues/109)) ([936ab84](https://github.com/microsoft/hve-core/commit/936ab84964ce23a478b83de248e92c95fcfae676))
* **deps-dev:** bump the npm-dependencies group with 2 updates ([#30](https://github.com/microsoft/hve-core/issues/30)) ([cf99cbf](https://github.com/microsoft/hve-core/commit/cf99cbfa9704285146c0393d1bd177ad2e209643))
* **deps:** bump actions/upload-artifact from 5.0.0 to 6.0.0 in the github-actions group ([#142](https://github.com/microsoft/hve-core/issues/142)) ([91eac8a](https://github.com/microsoft/hve-core/commit/91eac8a876e235aa30e0b01e04c8f3c642abd50b))
* **deps:** bump js-yaml, markdown-link-check and markdownlint-cli2 ([#75](https://github.com/microsoft/hve-core/issues/75)) ([af03d0e](https://github.com/microsoft/hve-core/commit/af03d0e745f09549cf20463d4ee22977727209b1))
* **deps:** bump the github-actions group with 2 updates ([#108](https://github.com/microsoft/hve-core/issues/108)) ([3e56313](https://github.com/microsoft/hve-core/commit/3e56313a0490eab1c39fa00f5849b638198cbf10))
* **deps:** bump the github-actions group with 2 updates ([#135](https://github.com/microsoft/hve-core/issues/135)) ([4538a03](https://github.com/microsoft/hve-core/commit/4538a03af26ad78e37ccca0d2c09bf663cf68b6b))
* **deps:** bump the github-actions group with 2 updates ([#62](https://github.com/microsoft/hve-core/issues/62)) ([d1e0c09](https://github.com/microsoft/hve-core/commit/d1e0c09fa29e9f2bbac0b72834c33a5c6c701071))
* **deps:** bump the github-actions group with 3 updates ([#87](https://github.com/microsoft/hve-core/issues/87)) ([ed550f4](https://github.com/microsoft/hve-core/commit/ed550f482e84edf7ad7b0fb87857e2aede76a31f))
* **deps:** bump the github-actions group with 6 updates ([#162](https://github.com/microsoft/hve-core/issues/162)) ([ec5bb12](https://github.com/microsoft/hve-core/commit/ec5bb12a3c14ad5353dc26730926795ffd7ce181))
* **devcontainer:** enhance gitleaks installation with checksum verification ([#100](https://github.com/microsoft/hve-core/issues/100)) ([5a8507d](https://github.com/microsoft/hve-core/commit/5a8507d65176df469a3c5b1bba3c326120f9cf78))
* **devcontainer:** refactor setup scripts for improved dependency management ([#94](https://github.com/microsoft/hve-core/issues/94)) ([f5f50d1](https://github.com/microsoft/hve-core/commit/f5f50d119babb757130309b4118ff5c59d530039)), closes [#98](https://github.com/microsoft/hve-core/issues/98)
* **security:** configure GitHub branch protection for OpenSSF compliance ([#191](https://github.com/microsoft/hve-core/issues/191)) ([90aab1a](https://github.com/microsoft/hve-core/commit/90aab1aadf6ee088edf21ea566a63e1d8e3962c9))

## 0.0.0 (Initial)

* Initial placeholder for release-please compatibility
