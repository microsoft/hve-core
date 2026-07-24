---
title: Changelog
description: Automatically generated changelog tracking all notable changes to the HVE Core project using semantic versioning
---

<!-- markdownlint-disable MD012 MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note:** This file is automatically maintained by [release-please](https://github.com/googleapis/release-please). Do not edit manually.

## [4.0.0](https://github.com/microsoft/hve-core/compare/hve-core-v3.3.101...hve-core-v4.0.0) (2026-07-24)


### ⚠ BREAKING CHANGES

* **instructions:** disclaimer SSOT migration (stacked on #1497) ([#1639](https://github.com/microsoft/hve-core/issues/1639))
* **agents:** per-agent model selection for cost optimization and /compact loop fix ([#1541](https://github.com/microsoft/hve-core/issues/1541))

### ✨ Features

* add experimental Caveman response style skill ([#1861](https://github.com/microsoft/hve-core/issues/1861)) ([3620737](https://github.com/microsoft/hve-core/commit/3620737e6f17ab2c565383cce73c282d60cf5858))
* add Vally evaluation infrastructure ([#1590](https://github.com/microsoft/hve-core/issues/1590)) ([8f3914c](https://github.com/microsoft/hve-core/commit/8f3914c2d6cd1939e9928dc67166c36d6df8d02a))
* **agents:** add acceptance criteria template and issue type hierarchy strategy to backlog manager ([#1597](https://github.com/microsoft/hve-core/issues/1597)) ([a780b7f](https://github.com/microsoft/hve-core/commit/a780b7f4a85c403d7ecf6b667ce6399b6e33f93d))
* **agents:** add accessibility planner, reviewer, and code-review accessibility agents ([#1735](https://github.com/microsoft/hve-core/issues/1735)) ([1ca6269](https://github.com/microsoft/hve-core/commit/1ca6269c0fbe331354eef3329846e434d22d90bf))
* **agents:** add enablement dimension to Experiment Designer for code-with MVEs ([#1416](https://github.com/microsoft/hve-core/issues/1416)) ([84077a8](https://github.com/microsoft/hve-core/commit/84077a82e269e4e38cb4a87890708c17f9cacdf8))
* **agents:** add PR Walkthrough narrative orientation agent ([#1947](https://github.com/microsoft/hve-core/issues/1947)) ([b98f527](https://github.com/microsoft/hve-core/commit/b98f527e7b3565c1a9f1d50eba899b1588c41bcc))
* **agents:** add Privacy Planner, SSSC reviewer, and privacy-standards skill ([#2168](https://github.com/microsoft/hve-core/issues/2168)) ([0bc13ee](https://github.com/microsoft/hve-core/commit/0bc13ee71d74fa3b5b254e36b6b53a196dd179ac))
* **agents:** add Task Challenger adversarial questioning agent ([#1315](https://github.com/microsoft/hve-core/issues/1315)) ([a9014c9](https://github.com/microsoft/hve-core/commit/a9014c95050aabfcf19a6c1ac8c79bd2ba0a6176))
* **agents:** add Vally evaluation agents and prompts ([#1834](https://github.com/microsoft/hve-core/issues/1834)) ([18ce4c6](https://github.com/microsoft/hve-core/commit/18ce4c6fd0a26674a84ed60089590adc94b6befe))
* **agents:** align sssc planner with rai parity, add signing and validation ([#1497](https://github.com/microsoft/hve-core/issues/1497)) ([f5e8513](https://github.com/microsoft/hve-core/commit/f5e8513a495d530651d4ae504829aea6d7168a9b))
* **agents:** consolidate code-review agents and add orientation-first review loop ([#2100](https://github.com/microsoft/hve-core/issues/2100)) ([7ca4cb2](https://github.com/microsoft/hve-core/commit/7ca4cb26df450a7ffea8ff0a2bc550a13398f5f4))
* **agents:** document plain-text path convention for .copilot-tracking artifacts ([#2147](https://github.com/microsoft/hve-core/issues/2147)) ([3362577](https://github.com/microsoft/hve-core/commit/3362577deba5ec9a6c2d46d2213e3cac0a028d9c))
* **agents:** keep internal workflow references out of comments ([#2023](https://github.com/microsoft/hve-core/issues/2023)) ([0d6a3f0](https://github.com/microsoft/hve-core/commit/0d6a3f08da281f826fb584dfa348a9299b64c1d5))
* **agents:** optimize RPI agent context management with discipline rules ([#1492](https://github.com/microsoft/hve-core/issues/1492)) ([35e5924](https://github.com/microsoft/hve-core/commit/35e5924a7313aa1fe2a63ddf832bfd96c8c53618))
* **agents:** per-agent model selection for cost optimization and /compact loop fix ([#1541](https://github.com/microsoft/hve-core/issues/1541)) ([e158d88](https://github.com/microsoft/hve-core/commit/e158d88237e6b5e0fb57cb707dfc82410aa86702))
* **agents:** remove issue-triage decomposition and improve labeling ([#2223](https://github.com/microsoft/hve-core/issues/2223)) ([3420081](https://github.com/microsoft/hve-core/commit/3420081fc8ca7b9904dafb206445b01b6e4b38d6))
* **agents:** security-planner SSSC parity ([#1642](https://github.com/microsoft/hve-core/issues/1642)) ([f4f6b3c](https://github.com/microsoft/hve-core/commit/f4f6b3c52bc760bfc7b76f428f6980d549836224))
* **agents:** upgrade ADR Planner with phased identity and adr-author skill ([#1554](https://github.com/microsoft/hve-core/issues/1554)) ([d2868d5](https://github.com/microsoft/hve-core/commit/d2868d5a528025edc91b39f912e210ed391fd6c1))
* **collections:** register Vally artifacts and regenerate plugins ([#1836](https://github.com/microsoft/hve-core/issues/1836)) ([74f0e86](https://github.com/microsoft/hve-core/commit/74f0e86245de7944667c1824ee35343e1c3d160c))
* **docs:** remediate Docusaurus site accessibility (WCAG 2.2 AA) ([#2391](https://github.com/microsoft/hve-core/issues/2391)) ([937be41](https://github.com/microsoft/hve-core/commit/937be41d196016bd3e1eaf6311d94c77ff88c7ad))
* **docs:** scaffold asset docs pages and wire Docusaurus Asset Catalog ([#2389](https://github.com/microsoft/hve-core/issues/2389)) ([766a4dc](https://github.com/microsoft/hve-core/commit/766a4dcc7a5f1905f15ed021189ad88b567f6da2))
* **evals:** add behavior eval corpora and Pester test suite ([#1832](https://github.com/microsoft/hve-core/issues/1832)) ([d44ad1e](https://github.com/microsoft/hve-core/commit/d44ad1e0d818b93456b687758ea6e1f870854f28))
* **evals:** add npm eval scripts and shared environments ([#1626](https://github.com/microsoft/hve-core/issues/1626)) ([1102901](https://github.com/microsoft/hve-core/commit/11029013677008d5b35d501ed3856b3a202da22e))
* **evals:** execute changed stimuli when eval specs are modified ([#2300](https://github.com/microsoft/hve-core/issues/2300)) ([7e743c5](https://github.com/microsoft/hve-core/commit/7e743c5cb9003051c35dfa4ed98a8dec29466671))
* **graphify:** Add graphify skill with thin prompt + applyTo instructions ([#1600](https://github.com/microsoft/hve-core/issues/1600)) ([878843c](https://github.com/microsoft/hve-core/commit/878843cb1639e57d2a3db1e189c3b2b2a16083ed))
* **hooks:** add local session telemetry hooks ([#2008](https://github.com/microsoft/hve-core/issues/2008)) ([34fe036](https://github.com/microsoft/hve-core/commit/34fe036242a71336fb268c9c08d637d2eac891e8))
* **hve-builder:** align HVE Builder artifact workflows ([#2438](https://github.com/microsoft/hve-core/issues/2438)) ([d293ea3](https://github.com/microsoft/hve-core/commit/d293ea35de7732357d0ef3b16edf56ac6358372b))
* Improve quality of rpi-agent.agent.md ([#1949](https://github.com/microsoft/hve-core/issues/1949)) ([0d9c746](https://github.com/microsoft/hve-core/commit/0d9c746e1884c4da034562a951d686e87d973b21))
* **instructions:** add accessibility instruction set and shared planner identity base ([#1733](https://github.com/microsoft/hve-core/issues/1733)) ([2158ced](https://github.com/microsoft/hve-core/commit/2158ced6d06a7288d2770a5d1239498a74997278))
* **instructions:** disclaimer SSOT migration (stacked on [#1497](https://github.com/microsoft/hve-core/issues/1497)) ([#1639](https://github.com/microsoft/hve-core/issues/1639)) ([a09b333](https://github.com/microsoft/hve-core/commit/a09b333d0b472199fd84bbf1ed8f5b0ff18367bb))
* **instructions:** harden ADR Creator against untrusted content and sensitive data ([#1811](https://github.com/microsoft/hve-core/issues/1811)) ([02e353d](https://github.com/microsoft/hve-core/commit/02e353d84495b1a393a827c2c33288dd37621ec3))
* **planning:** add Security Planner state schema with contract suite and fixtures ([#1638](https://github.com/microsoft/hve-core/issues/1638)) ([8947038](https://github.com/microsoft/hve-core/commit/8947038823847a2039c0ad78edff4eab4c0b058e))
* **prompts:** add agent frontmatter to standalone prompts ([#1840](https://github.com/microsoft/hve-core/issues/1840)) ([244b631](https://github.com/microsoft/hve-core/commit/244b63181a23f04710b41adcf232d68b00821d02))
* **prompts:** add cspell-config prompt for automated spell check maintenance ([#1516](https://github.com/microsoft/hve-core/issues/1516)) ([79db525](https://github.com/microsoft/hve-core/commit/79db525325e5e5bc087af12d0fc658c8db2d9458))
* **prompts:** add jira-setup credential configuration prompt ([#1698](https://github.com/microsoft/hve-core/issues/1698)) ([b30a75d](https://github.com/microsoft/hve-core/commit/b30a75da26fd86dab5ff074a2d421f0640449b8d))
* **rpi:** introduce skill-forward RPI workflows ([#1953](https://github.com/microsoft/hve-core/issues/1953)) ([44b42d4](https://github.com/microsoft/hve-core/commit/44b42d40e7bcf10ac1604c33bc9a5de4f2cc30ed))
* **rpi:** update skill workflows and eval coverage ([#2202](https://github.com/microsoft/hve-core/issues/2202)) ([01052e3](https://github.com/microsoft/hve-core/commit/01052e3cbdded798187b9f4a4fa7169bd7580eea))
* **scripts:** add accessibility state schema and noticeLog audit trail to planner schemas ([#1734](https://github.com/microsoft/hve-core/issues/1734)) ([4044819](https://github.com/microsoft/hve-core/commit/4044819ff20a4b52bf6c19bf16c5fcc69ef547c1))
* **scripts:** add evals orchestration modules and runners ([#1831](https://github.com/microsoft/hve-core/issues/1831)) ([3175b5c](https://github.com/microsoft/hve-core/commit/3175b5c5b2db981c95db1cc0d18b5123c36d56a7))
* **scripts:** add instruction applyTo scope Pester suite ([#1640](https://github.com/microsoft/hve-core/issues/1640)) ([d7a7a1c](https://github.com/microsoft/hve-core/commit/d7a7a1cab2a5defe521fecec6757c328cbac8aea))
* **scripts:** add lint:py:fix to apply ruff autofixes across Python skills ([#1450](https://github.com/microsoft/hve-core/issues/1450)) ([2b6dca7](https://github.com/microsoft/hve-core/commit/2b6dca76134908614d7efa362d7fc4b593a99186))
* **scripts:** add structured JSON log output to Validate-Collections.ps1 ([57ea279](https://github.com/microsoft/hve-core/commit/57ea279d17424d8fabc4bafe13d793432242e31c))
* **scripts:** add structured JSON log output to Validate-Marketplace.ps1 ([#1430](https://github.com/microsoft/hve-core/issues/1430)) ([ec2aa53](https://github.com/microsoft/hve-core/commit/ec2aa5308c0adc3d21d66bc7ff1ebb57f003ecd8))
* **scripts:** allowlist accessibility skills subdomain and recognize templates subdir ([#1731](https://github.com/microsoft/hve-core/issues/1731)) ([81f379a](https://github.com/microsoft/hve-core/commit/81f379acf3d9fca681c84a5667742d4a54fdb264))
* **scripts:** asset-docs foundation, generator, and validator ([#2365](https://github.com/microsoft/hve-core/issues/2365)) ([25308f0](https://github.com/microsoft/hve-core/commit/25308f09fd4ae82defdf06324dcd9b6f9604e3c4))
* **scripts:** enforce asset-doc completeness and region sync in CI ([#2470](https://github.com/microsoft/hve-core/issues/2470)) ([5fcfb8b](https://github.com/microsoft/hve-core/commit/5fcfb8ba16ec75ac846aba0a165f7a05e2473a5e))
* **scripts:** validate unstaged files and dependency pins ([#2437](https://github.com/microsoft/hve-core/issues/2437)) ([deb66e4](https://github.com/microsoft/hve-core/commit/deb66e4cdb5e6946df9157fd4c4cfbced21a71f1))
* **security:** adopt hybrid Poutine + homegrown template-injection gate ([#2344](https://github.com/microsoft/hve-core/issues/2344)) ([b70237d](https://github.com/microsoft/hve-core/commit/b70237d08d5caf6918b9de9952a243a8588b92dc))
* **security:** extract supply-chain-security skill and thin SSSC Planner ([#1950](https://github.com/microsoft/hve-core/issues/1950)) ([2e9608c](https://github.com/microsoft/hve-core/commit/2e9608cc648b3baf336f7559c6c9506f36761afc))
* **security:** migrate Security Planner to skill ([#2045](https://github.com/microsoft/hve-core/issues/2045)) ([5202b71](https://github.com/microsoft/hve-core/commit/5202b714767b11cba8c65ddd75897f6bb902833e))
* **skills:** add --collapse-newlines option to tts-voiceover ([#2465](https://github.com/microsoft/hve-core/issues/2465)) ([3ff24d2](https://github.com/microsoft/hve-core/commit/3ff24d22ea7d4d63d624daa7ae352f7e305889d3))
* **skills:** add 6 PowerPoint skill enhancements ([#1481](https://github.com/microsoft/hve-core/issues/1481)) ([97c40e8](https://github.com/microsoft/hve-core/commit/97c40e8733f8ffee22c6d2581625ec2cb0f1c3af))
* **skills:** add accessibility coverage matrix and runtime-probe harness ([#2392](https://github.com/microsoft/hve-core/issues/2392)) ([918b0c6](https://github.com/microsoft/hve-core/commit/918b0c675053de622c2de4449b651f77c9bc4bd6))
* **skills:** add accessibility standards skills and shared backlog-templates skill ([#1732](https://github.com/microsoft/hve-core/issues/1732)) ([a206f47](https://github.com/microsoft/hve-core/commit/a206f47ec8229b628cd431dcb46250868e14f52c))
* **skills:** add data-governance controls reference to privacy-standards ([#2416](https://github.com/microsoft/hve-core/issues/2416)) ([cd6b394](https://github.com/microsoft/hve-core/commit/cd6b39414de722575d1b2ce8ed85706cab168e78))
* **skills:** add experimental mural skill with Python CLI, instructions, and agent integrations ([#1561](https://github.com/microsoft/hve-core/issues/1561)) ([c5fcf0b](https://github.com/microsoft/hve-core/commit/c5fcf0b3766ea51ef3e9e9317f1d596622255f70))
* **skills:** add github-security code-scanning skill ([#1418](https://github.com/microsoft/hve-core/issues/1418)) ([5bedf80](https://github.com/microsoft/hve-core/commit/5bedf808c31530e86dfe75d87900791ede3ce5ef))
* **skills:** add label margin and font overrides to arrow_flow in powerpoint skill ([#2466](https://github.com/microsoft/hve-core/issues/2466)) ([8ae6195](https://github.com/microsoft/hve-core/commit/8ae619551cf6bb02243711457e03994414386c74))
* **skills:** add seven project-planning BRD skills ([#1856](https://github.com/microsoft/hve-core/issues/1856)) ([2919d48](https://github.com/microsoft/hve-core/commit/2919d48e850753b08537d7c5aabc7b2e4675460c))
* **skills:** add telemetry-foundations shared skill with consumer overlays ([#1681](https://github.com/microsoft/hve-core/issues/1681)) ([ea0bec0](https://github.com/microsoft/hve-core/commit/ea0bec080b5cac311bfd05fd22b89c73c6452477))
* **skills:** add tts-voiceover skill for Azure Speech SDK voice-over generation ([#1415](https://github.com/microsoft/hve-core/issues/1415)) ([c330c7a](https://github.com/microsoft/hve-core/commit/c330c7aabebb16d36787e09c239c99de34d6cfcb))
* **skills:** add vally-tests skill ([#1830](https://github.com/microsoft/hve-core/issues/1830)) ([da9ffa2](https://github.com/microsoft/hve-core/commit/da9ffa26c0c3886d1eaf336dc9af9a16ffd832ba))
* **skills:** expand fuzz_has_formatting_variation to cover all formatting properties ([#1143](https://github.com/microsoft/hve-core/issues/1143)) ([#1296](https://github.com/microsoft/hve-core/issues/1296)) ([d51b4d3](https://github.com/microsoft/hve-core/commit/d51b4d3f04738b98bccce5b439a71a7f43194f41))
* **skills:** harden MCP/skill trust boundaries and add per-skill security models ([#2326](https://github.com/microsoft/hve-core/issues/2326)) ([8fc30bc](https://github.com/microsoft/hve-core/commit/8fc30bcef402066455b89b6507dfb9b1904a472f))
* **skills:** replace doc-ops agents with unified documentation agent and skill ([#2095](https://github.com/microsoft/hve-core/issues/2095)) ([a441419](https://github.com/microsoft/hve-core/commit/a4414194e3d14639f5864680993739348ed5fdc3))
* **workflows:** add beval behavioral evaluation workflow for dt-coach agent ([#1129](https://github.com/microsoft/hve-core/issues/1129)) ([f1a7043](https://github.com/microsoft/hve-core/commit/f1a70432bb51aabc3350ee902f9fddb133174750))
* **workflows:** add devcontainer lockfile integrity check ([#1874](https://github.com/microsoft/hve-core/issues/1874)) ([d2996b7](https://github.com/microsoft/hve-core/commit/d2996b764cbfa333d270981c84bae2bdf9e66944))
* **workflows:** add Pre-Release-As trailer override to pre-release w… ([#1565](https://github.com/microsoft/hve-core/issues/1565)) ([310c68c](https://github.com/microsoft/hve-core/commit/310c68c91ff0461b94d135348aff70804c5045a7))
* **workflows:** add weekly GitHub code scanning automation ([#1495](https://github.com/microsoft/hve-core/issues/1495)) ([d307f8a](https://github.com/microsoft/hve-core/commit/d307f8aecccda4fb359d3bdcd203dbafe2911167))
* **workflows:** convert pr-review to manual /review slash command ([#1544](https://github.com/microsoft/hve-core/issues/1544)) ([84e47f0](https://github.com/microsoft/hve-core/commit/84e47f0e5a123e351b45ccb92df8669d68e09d61))
* **workflows:** isolate VSIX and VEX provenance for SLSA Build Level 3 ([#2388](https://github.com/microsoft/hve-core/issues/2388)) ([f4499db](https://github.com/microsoft/hve-core/commit/f4499db5ba98d86fe6e33b56e4c0895927886344))
* **workflows:** SLSA L3 provenance verify gate + branch-protection doc ([#2231](https://github.com/microsoft/hve-core/issues/2231)) ([cae5d6d](https://github.com/microsoft/hve-core/commit/cae5d6d509deb9fb2ff8c7019a3ddd25d678d7ad))


### 🐛 Bug Fixes

* 1633: docs: update docs/architecture/workflows.md npm script table for eval commands ([#1655](https://github.com/microsoft/hve-core/issues/1655)) ([a586699](https://github.com/microsoft/hve-core/commit/a58669945575277ffe30f8dad687b9f027799679))
* 1634: docs: sync lint:all chain in build-system.md with package.json ([#1679](https://github.com/microsoft/hve-core/issues/1679)) ([ec35cec](https://github.com/microsoft/hve-core/commit/ec35cec37c03eaf331ae18008b439ec8717de0fd))
* **agents:** align task-reviewer H1 heading and add missing send: true to task-researcher handoff ([#2382](https://github.com/microsoft/hve-core/issues/2382)) ([c5de202](https://github.com/microsoft/hve-core/commit/c5de2020ca4a28a992913d73dca2aff7a2a310bb))
* **build:** bump basic-ftp override to 6.0.1 to clear high-severity advisory ([#1545](https://github.com/microsoft/hve-core/issues/1545)) ([4353df1](https://github.com/microsoft/hve-core/commit/4353df145f3b424e71c915fa01cf93a0a17af6bc))
* **build:** override ip-address to 10.2.0 for GHSA-v2v4-37r5-5v8g ([#1539](https://github.com/microsoft/hve-core/issues/1539)) ([ba520aa](https://github.com/microsoft/hve-core/commit/ba520aa481997cce77a9a7cf616e9aa9ed33c55c))
* **build:** pin tmp &gt;=0.2.6 to resolve GHSA-ph9p-34f9-6g65 ([#1686](https://github.com/microsoft/hve-core/issues/1686)) ([af67fec](https://github.com/microsoft/hve-core/commit/af67fec02b19b3ffca4d5e69f7e4dee598b70517))
* **build:** pin uuid and postcss via overrides to resolve Dependabot alerts ([#1491](https://github.com/microsoft/hve-core/issues/1491)) ([af1f9ca](https://github.com/microsoft/hve-core/commit/af1f9ca335e623d7a5fd8f474a7f9b3beb179764))
* **ci:** add composite action for PS module install with cache and retry ([#2134](https://github.com/microsoft/hve-core/issues/2134)) ([78e3e8d](https://github.com/microsoft/hve-core/commit/78e3e8d3e3aa45a3c691baf10cbb771500528fb3))
* **ci:** align actionlint curl download with uv step pattern ([#1870](https://github.com/microsoft/hve-core/issues/1870)) ([2ad24fd](https://github.com/microsoft/hve-core/commit/2ad24fdf9db10128b54f559ad57560dbaa4e0f93))
* **ci:** grant extension-provenance caller required write permissions ([#2408](https://github.com/microsoft/hve-core/issues/2408)) ([4048fcf](https://github.com/microsoft/hve-core/commit/4048fcf6deb49f51e2eb76ac32f1d0830188ceeb))
* **ci:** stabilize gitleaks fixture suppressions ([#1883](https://github.com/microsoft/hve-core/issues/1883)) ([7d82c22](https://github.com/microsoft/hve-core/commit/7d82c2218b29195cfc1f1af4861c836489f423f5))
* clarify markdownlint marker placement in PRD Builder ([#2098](https://github.com/microsoft/hve-core/issues/2098)) ([b5c695f](https://github.com/microsoft/hve-core/commit/b5c695fb30a115998b5e1e89066a951e1573b336))
* **deps:** bump qs from 6.15.0 to 6.15.2 to resolve GHSA-q8mj-m7cp-5q26 ([#1650](https://github.com/microsoft/hve-core/issues/1650)) ([6665e95](https://github.com/microsoft/hve-core/commit/6665e9515178840a5d6b316f15fc3a07b80e4e52))
* **deps:** remediate cryptography advisories and harden PowerPoint scripts ([#2037](https://github.com/microsoft/hve-core/issues/2037)) ([2286c67](https://github.com/microsoft/hve-core/commit/2286c6710fe37ee6db0d180b1cca5c7746710a55))
* **docs:** adopt Docusaurus Faster and pin 3.10.1 ([#1893](https://github.com/microsoft/hve-core/issues/1893)) ([011e69a](https://github.com/microsoft/hve-core/commit/011e69a3453b1b8914b16521da8d68ce5eedcb18))
* **docs:** harden homepage hero and search contrast for WCAG AA ([#2250](https://github.com/microsoft/hve-core/issues/2250)) ([6da5316](https://github.com/microsoft/hve-core/commit/6da531669d423c92844fe28372712a79729e42fe))
* **docs:** improve contrast for badges and search hint ([#1922](https://github.com/microsoft/hve-core/issues/1922)) ([b0a0bda](https://github.com/microsoft/hve-core/commit/b0a0bdacb040871d37d1b756f17f7147d38dfc57))
* **docs:** patch Docusaurus npm vulnerabilities and extend Dependabot scope ([#1889](https://github.com/microsoft/hve-core/issues/1889)) ([65fe619](https://github.com/microsoft/hve-core/commit/65fe6197e3bba60d0f4e84cd3bb1859059dc8625))
* **evals:** add missing eval coverage for vex-scan and vex-triage prompts ([#2294](https://github.com/microsoft/hve-core/issues/2294)) ([dce65b6](https://github.com/microsoft/hve-core/commit/dce65b66ef05b435332c2aca306323fd9aebb750))
* **hooks:** adds event name inference to fix missing captures ([#2478](https://github.com/microsoft/hve-core/issues/2478)) ([3660ce0](https://github.com/microsoft/hve-core/commit/3660ce058bc9ddd2ddf68f8df09d9f413d2a521c))
* **hooks:** remove unused local variables flagged by CodeQL ([#2352](https://github.com/microsoft/hve-core/issues/2352)) ([fcc4134](https://github.com/microsoft/hve-core/commit/fcc4134621a14a1b80375694bbf5c7dc111086b1))
* improve DT Coach Phase 1 initialization reliability and state schema ([#2055](https://github.com/microsoft/hve-core/issues/2055)) ([027606c](https://github.com/microsoft/hve-core/commit/027606c9d115876bc2209beba729b70d2fa04f24))
* **instructions:** enforce human review checkbox gate for backlog processing ([#1920](https://github.com/microsoft/hve-core/issues/1920)) ([1ca08d7](https://github.com/microsoft/hve-core/commit/1ca08d747d394e5c5d0eefaeed1ff81138bcd413))
* **instructions:** update design thinking image prompt generation guidelines (fixes [#1587](https://github.com/microsoft/hve-core/issues/1587)) ([#1629](https://github.com/microsoft/hve-core/issues/1629)) ([e8d4b8c](https://github.com/microsoft/hve-core/commit/e8d4b8c0c9886397448c5c2d1d11ef817e390fc5))
* **mural:** send API-compliant arrow widget payload ([#2136](https://github.com/microsoft/hve-core/issues/2136)) ([aaef669](https://github.com/microsoft/hve-core/commit/aaef66935357a49e5351268f0b3ee2857f16ee3a))
* PSScriptAnalyzer test mock fails version guard, running Install-PSModules on every case ([#2325](https://github.com/microsoft/hve-core/issues/2325)) ([7f037e9](https://github.com/microsoft/hve-core/commit/7f037e91dd33bdeaea850c39836ed346873f7484))
* **scripts:** Exclude plugins/ from ms.date freshness check to prevent duplicate stale reports ([#1586](https://github.com/microsoft/hve-core/issues/1586)) ([0b617ce](https://github.com/microsoft/hve-core/commit/0b617ce0c955011c6345b2f6b6d2e5df63cf4202))
* **scripts:** execute subagent-tagged agent-behavior stimuli in the eval matrix ([#2385](https://github.com/microsoft/hve-core/issues/2385)) ([b0b8bd6](https://github.com/microsoft/hve-core/commit/b0b8bd6cab59b4088099c9e172f824fbd5d2744a))
* **scripts:** npm run test:py fails when skills have uv-managed dev dependencies ([#1938](https://github.com/microsoft/hve-core/issues/1938)) ([32a47dd](https://github.com/microsoft/hve-core/commit/32a47dd66543ec4c46b6a51b2ca4614ccc012f66))
* **scripts:** remove duplicate Included Artifacts heading in collection.md generation ([#1855](https://github.com/microsoft/hve-core/issues/1855)) ([a343b5d](https://github.com/microsoft/hve-core/commit/a343b5d5293289f98f5f850bf52d477a428f989b))
* **scripts:** remove redundant moderation requirements.txt ([#2273](https://github.com/microsoft/hve-core/issues/2273)) ([b6bb6ba](https://github.com/microsoft/hve-core/commit/b6bb6ba96b2a929c7e76951bd74965ff2c95b8ca))
* **security:** harden VEX drafting gate and standardize per-skill SECURITY.md models ([#2360](https://github.com/microsoft/hve-core/issues/2360)) ([e6f414d](https://github.com/microsoft/hve-core/commit/e6f414dabf65d67d59763ce776fa2212bd70b028))
* **security:** resolve open code scanning alerts ([#2282](https://github.com/microsoft/hve-core/issues/2282)) ([61d1b5f](https://github.com/microsoft/hve-core/commit/61d1b5f01743c206d3ba61f4a1d46a957d0bfba3))
* **settings:** remove markdownlint exclusion for collections/*.collection.md ([#1372](https://github.com/microsoft/hve-core/issues/1372)) ([42cc137](https://github.com/microsoft/hve-core/commit/42cc13775e90f84332846ea47a46045a8ae983d4))
* **skills:** harden Jira/GitLab transports against redirect token leak ([#2245](https://github.com/microsoft/hve-core/issues/2245)) ([0b57278](https://github.com/microsoft/hve-core/commit/0b57278d8b03de2a3dd11a4f9a825ff522d3cddd))
* **skills:** harden powerpoint PyMuPDF integration against malformed PDFs ([#1018](https://github.com/microsoft/hve-core/issues/1018)) ([#1904](https://github.com/microsoft/hve-core/issues/1904)) ([c6d1ace](https://github.com/microsoft/hve-core/commit/c6d1aceb65bf42667c6c9ff6c06e51ce00f8c704))
* **skills:** harden tts-voiceover XML parser against XXE ([#1056](https://github.com/microsoft/hve-core/issues/1056)) ([#1695](https://github.com/microsoft/hve-core/issues/1695)) ([60db15f](https://github.com/microsoft/hve-core/commit/60db15f07e1d72b5c38d2fc976a778c275afb2c6))
* **skills:** remove "Brought to you by" attribution ([#2047](https://github.com/microsoft/hve-core/issues/2047)) ([#2238](https://github.com/microsoft/hve-core/issues/2238)) ([a4769a0](https://github.com/microsoft/hve-core/commit/a4769a029bccc1720fb8d5ac50950dfea5e4d917))
* **skills:** replace binary PPTX fixture with programmatic generator ([#2081](https://github.com/microsoft/hve-core/issues/2081)) ([ad23920](https://github.com/microsoft/hve-core/commit/ad239205deb792c674c13dd3dce6b0bfa7946649))
* **skills:** resolve pip-audit findings in tts-voiceover skill lock file ([#1627](https://github.com/microsoft/hve-core/issues/1627)) ([2f206b5](https://github.com/microsoft/hve-core/commit/2f206b597b8dc246e2df8ad6c629ab9df22c6d24))
* **skills:** tighten strict-tier cite-only licensing in ADR standards ([#1859](https://github.com/microsoft/hve-core/issues/1859)) ([ceb8c47](https://github.com/microsoft/hve-core/commit/ceb8c47b6258cb9bb2804651cbab076802cfc55b))
* **workflows:** grant id-token write to docusaurus-tests callers for Codecov OIDC ([#2085](https://github.com/microsoft/hve-core/issues/2085)) ([b69e34a](https://github.com/microsoft/hve-core/commit/b69e34ac38b39bd3b20bf80fa142c8ca3a3b29ed))
* **workflows:** grant reusable-workflow caller jobs required permissions ([#2424](https://github.com/microsoft/hve-core/issues/2424)) ([719b998](https://github.com/microsoft/hve-core/commit/719b998da62f8f0d6f213d62d7525d4d3f8413ac))
* **workflows:** harden VEX automation checkout and detection lookup ([#2312](https://github.com/microsoft/hve-core/issues/2312)) ([64c47ac](https://github.com/microsoft/hve-core/commit/64c47ac0bbed9dabbdf3029ac7e22248d400c5be))
* **workflows:** harden vex-draft pre-activation gates ([#2357](https://github.com/microsoft/hve-core/issues/2357)) ([142e528](https://github.com/microsoft/hve-core/commit/142e528eb0a6a59938d8e68f030fa4c8496a97a4))
* **workflows:** install PS modules with CurrentUser scope for `copilot-setup-steps` ([#2244](https://github.com/microsoft/hve-core/issues/2244)) ([222f5bc](https://github.com/microsoft/hve-core/commit/222f5bc899f59d8e3bcdb68193f082edf92be5ae))
* **workflows:** migrate gh-aw compiler to v0.79.4 and refresh lock files ([#1903](https://github.com/microsoft/hve-core/issues/1903)) ([c3ced2b](https://github.com/microsoft/hve-core/commit/c3ced2bb96ee7db95e4dd1fdff0d31292b54d667))
* **workflows:** refresh Dependabot PR Review and upgrade gh-aw to v0.76.1 ([#1690](https://github.com/microsoft/hve-core/issues/1690)) ([cb4d871](https://github.com/microsoft/hve-core/commit/cb4d8716c4384ebc096e661d2321c02263674da9))
* **workflows:** skip puppeteer browser download in deploy-docs build ([#2278](https://github.com/microsoft/hve-core/issues/2278)) ([a044d10](https://github.com/microsoft/hve-core/commit/a044d10e8db12b07ccbf7e2c121236a86d6b0756))


### 📚 Documentation

* add content policies, refresh environment versions, drop description attribution ([#2192](https://github.com/microsoft/hve-core/issues/2192)) ([691cdea](https://github.com/microsoft/hve-core/commit/691cdea49276ae71f7f44279316b0fab2dadbfe1))
* add reactivation workflow subsection to ai-artifacts.md ([#1882](https://github.com/microsoft/hve-core/issues/1882)) ([b869504](https://github.com/microsoft/hve-core/commit/b8695046da32537903f2327bfc394ea7bea272d8))
* add Responsible AI Transparency Note ([#1900](https://github.com/microsoft/hve-core/issues/1900)) ([75029d0](https://github.com/microsoft/hve-core/commit/75029d0cad9bfa7e64fb94ae2e23008fe2248d84))
* **ado-backlog:** correct ADO Backlog Manager workflow documentation ([#2205](https://github.com/microsoft/hve-core/issues/2205)) ([3d4dbad](https://github.com/microsoft/hve-core/commit/3d4dbadfd17c10e5476dfe29bb9556616de0a5e3))
* **adrs:** adopt Vally as agent and skill behavior evaluation framework ([#1828](https://github.com/microsoft/hve-core/issues/1828)) ([3e27fc3](https://github.com/microsoft/hve-core/commit/3e27fc3012f44412a72bda3c9a4f55fd27eeb5a3))
* **agents:** add accessibility planner and reviewer documentation ([#1736](https://github.com/microsoft/hve-core/issues/1736)) ([716922a](https://github.com/microsoft/hve-core/commit/716922a590721e59cbc90eeb7945dd98c5a5fe00))
* **agents:** align language-skills.md with semantic skill selection ([#1891](https://github.com/microsoft/hve-core/issues/1891)) ([fd908f0](https://github.com/microsoft/hve-core/commit/fd908f071016990ff17b491e7f686079fe196d32))
* **agents:** document #tool: syntax and align tools list with VS Code 1.109+ ([#2319](https://github.com/microsoft/hve-core/issues/2319)) ([88bf67f](https://github.com/microsoft/hve-core/commit/88bf67f07a2ce3dd981a44227eafd47a5d8b931a))
* **agents:** refresh stale docs/agents pages for accuracy ([#2211](https://github.com/microsoft/hve-core/issues/2211)) ([342c138](https://github.com/microsoft/hve-core/commit/342c138cf94f273fa210b1a79fc4f175c4473806))
* align RPI methodology descriptions to four phases across docs ([#2296](https://github.com/microsoft/hve-core/issues/2296)) ([36780ba](https://github.com/microsoft/hve-core/commit/36780bad5bf2e833a240f8ea6e55d201238ffb61))
* align Transparency Note with AI Messaging Guidance ([#2039](https://github.com/microsoft/hve-core/issues/2039)) ([04c9331](https://github.com/microsoft/hve-core/commit/04c93317471ac671a92c14af694f0639ad8e72af))
* **docs:** clarify getting-started method guides ([#1851](https://github.com/microsoft/hve-core/issues/1851)) ([b054051](https://github.com/microsoft/hve-core/commit/b054051146d15a8f6025828acd29f5d543059e82))
* **docs:** refresh workflow, tool-checksums, and environment documentation ([#2201](https://github.com/microsoft/hve-core/issues/2201)) ([6d227bd](https://github.com/microsoft/hve-core/commit/6d227bd3839fbacd2e86df7e4c6dc23dd5d3647f))
* document accessibility coverage-matrix workflow and refresh planner/reviewer ([#2428](https://github.com/microsoft/hve-core/issues/2428)) ([8befd01](https://github.com/microsoft/hve-core/commit/8befd017476e209083647e73768722682620b483))
* document maturity and path validation checks in collections README ([#2458](https://github.com/microsoft/hve-core/issues/2458)) ([8bfb210](https://github.com/microsoft/hve-core/commit/8bfb210a12d8d84dccb2ea56ac3aad4c78decd3b))
* expand providerAllowlist and document model field in customization guide ([#2014](https://github.com/microsoft/hve-core/issues/2014)) ([6cc41e1](https://github.com/microsoft/hve-core/commit/6cc41e1ed11a229b334815f5b754af983bd8d96d))
* Fix stale eval:lint references in documentation ([#1951](https://github.com/microsoft/hve-core/issues/1951)) ([1cd3c0d](https://github.com/microsoft/hve-core/commit/1cd3c0d23710bdb4e7732b60ce688084bceb85c9))
* **hve-guide:** refresh 22 stale guide pages and fix broken refs ([#2207](https://github.com/microsoft/hve-core/issues/2207)) ([88dc7f2](https://github.com/microsoft/hve-core/commit/88dc7f2922bbe1fb11b775b2d4a2c82b56ad40d3))
* improve new user onboarding with terminology, CLI plugins, and collections clarity ([#1520](https://github.com/microsoft/hve-core/issues/1520)) ([66b524a](https://github.com/microsoft/hve-core/commit/66b524a5d881b11a22b8f87702b18be4ebda7e6a))
* Improve readme.md and contributing.md ([#1635](https://github.com/microsoft/hve-core/issues/1635)) ([b836ac0](https://github.com/microsoft/hve-core/commit/b836ac0c510856c7b6a6ed0b363db01cdbf2dff2))
* **instructions:** adopt "this" singleton naming for terraform resources and data sources ([#2164](https://github.com/microsoft/hve-core/issues/2164)) ([311e570](https://github.com/microsoft/hve-core/commit/311e570938226034a608e735029bfeeb8ef11a71))
* **readme:** clarify HVE Core adoption posture ([#2494](https://github.com/microsoft/hve-core/issues/2494)) ([a2c771b](https://github.com/microsoft/hve-core/commit/a2c771b2ba07cb7644a199210feb6545e46c96c2))
* realign stale references with current source of truth ([#2220](https://github.com/microsoft/hve-core/issues/2220)) ([9ac46ed](https://github.com/microsoft/hve-core/commit/9ac46ed434c0e2e091a4d4b6b8439f9f5c0feeb2))
* refresh design-thinking, customization, getting-started, and scripts documentation for accuracy ([#2208](https://github.com/microsoft/hve-core/issues/2208)) ([d720f85](https://github.com/microsoft/hve-core/commit/d720f85671786663cf8333246f775f1ca65064f0))
* refresh stale agent catalog, getting-started counts, and security/evals docs ([#2203](https://github.com/microsoft/hve-core/issues/2203)) ([39365cc](https://github.com/microsoft/hve-core/commit/39365cc58ba4a5223fa498935abf0d3887baa68d))
* refresh stale documentation and update ms.date across 12 files ([#1625](https://github.com/microsoft/hve-core/issues/1625)) ([46c0c03](https://github.com/microsoft/hve-core/commit/46c0c037910511a6b755c8884a397eedf182862f))
* remediate Bundle A toolchain-freshness documentation drift ([#2317](https://github.com/microsoft/hve-core/issues/2317)) ([19b03f7](https://github.com/microsoft/hve-core/commit/19b03f7b5a3b6542db4ecde29f8ff99f6ed4b3ca))
* remove generated footers ([#1919](https://github.com/microsoft/hve-core/issues/1919)) ([1bf0c2b](https://github.com/microsoft/hve-core/commit/1bf0c2bf858692f9122807f59b20b4f7d9d5b677))
* **scripts:** fix stale linting README descriptions for Invoke-PythonTests.ps1 and Invoke-PythonLint.ps1 ([#2017](https://github.com/microsoft/hve-core/issues/2017)) ([fac1b19](https://github.com/microsoft/hve-core/commit/fac1b19a45cb70ea24d01ebb032cb5150fb17974))
* **security:** add Jira, GitLab, and TTS credential threat tables ([#2384](https://github.com/microsoft/hve-core/issues/2384)) ([890a168](https://github.com/microsoft/hve-core/commit/890a168287beadd50b62189c1a4d7ba4dc160125))
* sync release pipeline docs with current provenance workflows ([#2425](https://github.com/microsoft/hve-core/issues/2425)) ([21148ef](https://github.com/microsoft/hve-core/commit/21148ef1b62010e17a3d57f62f554cad340bda99))
* update docs to reflect updated changes ([#2167](https://github.com/microsoft/hve-core/issues/2167)) ([85db9d5](https://github.com/microsoft/hve-core/commit/85db9d522f92f544726d058f4d72e29a0a2ffa8e))
* update ms.date frontmatter for 13 stale documentation files ([#1588](https://github.com/microsoft/hve-core/issues/1588)) ([940773c](https://github.com/microsoft/hve-core/commit/940773c7065ca3c06217d8ebda68b40571cd73f3))
* update README for untracked and working-tree files ([#2459](https://github.com/microsoft/hve-core/issues/2459)) ([ddc369d](https://github.com/microsoft/hve-core/commit/ddc369dc532a1601bc75438539cc255628e079f3))
* update scripts/README.md to document scripts/docs/ directory ([#2464](https://github.com/microsoft/hve-core/issues/2464)) ([05cd2e1](https://github.com/microsoft/hve-core/commit/05cd2e14884b1a25f7b8dc571ee6ade2a1368300))
* update sssc-planning agent-overview for consolidated instructions ([#2212](https://github.com/microsoft/hve-core/issues/2212)) ([d06b518](https://github.com/microsoft/hve-core/commit/d06b518b082f888275910a42ec587b159bda8768))
* update stale documentation for DT and bump stale docs ([#2434](https://github.com/microsoft/hve-core/issues/2434)) ([677fd2e](https://github.com/microsoft/hve-core/commit/677fd2e5f4230a4db9d97872506fb595e66ba598))


### ♻️ Refactoring

* **agents:** align security and rai planner wording ([#1854](https://github.com/microsoft/hve-core/issues/1854)) ([6f00d3e](https://github.com/microsoft/hve-core/commit/6f00d3e49976f318a10c6ea8cf2338062eedcf69))
* **docs:** consolidate brds and prds into docs/planning ([#2291](https://github.com/microsoft/hve-core/issues/2291)) ([533ef33](https://github.com/microsoft/hve-core/commit/533ef33462c4aeea896a84484a2a7a0ed7ca153f))
* **skills:** consolidate accessibility planner phases into playbook skill ([#2021](https://github.com/microsoft/hve-core/issues/2021)) ([33e0429](https://github.com/microsoft/hve-core/commit/33e04296dfe1175d0eefa97a8a6fbd5ea430db9c))
* **skills:** consolidate RAI instructions into rai-standards and rai-planner-playbook skills ([#2062](https://github.com/microsoft/hve-core/issues/2062)) ([bd6f996](https://github.com/microsoft/hve-core/commit/bd6f996eb84226c0f948ae67d6837eeb2a6a90f8))
* **skills:** migrate design-thinking tier-2 instructions to skills ([#1857](https://github.com/microsoft/hve-core/issues/1857)) ([da1ee1b](https://github.com/microsoft/hve-core/commit/da1ee1b1ac1f8b61354a00c295ddc6d4f64bd2c5))
* **skills:** replace arch-diagram-builder agent with reusable architecture-diagrams skill ([#2068](https://github.com/microsoft/hve-core/issues/2068)) ([979e454](https://github.com/microsoft/hve-core/commit/979e4544204027a32a6dd95db4c92c081bde5f5a))


### 🔧 Maintenance

* **agents:** strip attribution suffix from descriptions ([#1723](https://github.com/microsoft/hve-core/issues/1723)) ([69f6ffa](https://github.com/microsoft/hve-core/commit/69f6ffa4398b1aef543a7a69a8a558d03b9812f3)), closes [#1714](https://github.com/microsoft/hve-core/issues/1714)
* **build:** add evals config and dependency foundation ([#1829](https://github.com/microsoft/hve-core/issues/1829)) ([ef978c9](https://github.com/microsoft/hve-core/commit/ef978c9692f64214d85e82b4715515e84f8772cb))
* **build:** dependabot uv moderation coverage + dependency remediation ([#2237](https://github.com/microsoft/hve-core/issues/2237)) ([edb2688](https://github.com/microsoft/hve-core/commit/edb268811e9dfde7de8fda67f820344e672548f1))
* **deps-dev:** bump @vscode/vsce from 3.9.1 to 3.9.2 in the npm-dependencies group ([#1871](https://github.com/microsoft/hve-core/issues/1871)) ([dd9c5a7](https://github.com/microsoft/hve-core/commit/dd9c5a708a4fd00deb7bf25456c443c1a2dcffec))
* **deps-dev:** bump axios from 1.17.0 to 1.18.1 in /docs/docusaurus ([#2485](https://github.com/microsoft/hve-core/issues/2485)) ([469db63](https://github.com/microsoft/hve-core/commit/469db637622bdf43be5e1b787a25333bece79855))
* **deps-dev:** bump fast-uri from 3.1.0 to 3.1.2 ([#1549](https://github.com/microsoft/hve-core/issues/1549)) ([7a2ee69](https://github.com/microsoft/hve-core/commit/7a2ee695664b90b87d6aeb623beb42ea411e077b))
* **deps-dev:** bump markdownlint-cli2 from 0.22.0 to 0.22.1 in the npm-dependencies group ([#1452](https://github.com/microsoft/hve-core/issues/1452)) ([5440396](https://github.com/microsoft/hve-core/commit/5440396fcf328db0b9d44e58225a065db23d7e91))
* **deps-dev:** bump the npm-dependencies group across 1 directory with 3 updates ([#1810](https://github.com/microsoft/hve-core/issues/1810)) ([2bdcb8d](https://github.com/microsoft/hve-core/commit/2bdcb8d791503483656ad875101908c853b6d14e))
* **deps-dev:** bump the npm-dependencies group across 2 directories with 2 updates ([#1952](https://github.com/microsoft/hve-core/issues/1952)) ([4d23c18](https://github.com/microsoft/hve-core/commit/4d23c18b0abf1a5f075a92e8656fdaf84165234e))
* **deps-dev:** bump tmp from 0.2.5 to 0.2.7 ([#1687](https://github.com/microsoft/hve-core/issues/1687)) ([5e83fac](https://github.com/microsoft/hve-core/commit/5e83facb505ac3fc771d9cab0f9418667a364c78))
* **deps-dev:** bump ws from 7.5.10 to 7.5.11 in /docs/docusaurus ([#2002](https://github.com/microsoft/hve-core/issues/2002)) ([f3fa829](https://github.com/microsoft/hve-core/commit/f3fa82928ed024d38df30b3489b7446e063213a7))
* **deps:** bump actions/checkout from 6.0.2 to 7.0.0 in the github-actions group ([#2104](https://github.com/microsoft/hve-core/issues/2104)) ([ba0840d](https://github.com/microsoft/hve-core/commit/ba0840d1984c2653d8a44448bbbf1d07e22aa634))
* **deps:** bump actions/checkout from 6.0.3 to 7.0.0 in the github-actions group across 1 directory ([#2255](https://github.com/microsoft/hve-core/issues/2255)) ([053c5c5](https://github.com/microsoft/hve-core/commit/053c5c5b4e6b2a390694a1045f6a3698fc37d51c))
* **deps:** bump brace-expansion from 5.0.5 to 5.0.6 in /docs/docusaurus ([#1614](https://github.com/microsoft/hve-core/issues/1614)) ([e5dcd9a](https://github.com/microsoft/hve-core/commit/e5dcd9a980a074a4ced994abedff7c8fa99afe16))
* **deps:** bump fast-uri from 3.1.0 to 3.1.2 in /docs/docusaurus ([#1548](https://github.com/microsoft/hve-core/issues/1548)) ([80fbddd](https://github.com/microsoft/hve-core/commit/80fbddd621317d7011a724fa04a31c54596e1940))
* **deps:** bump launch-editor from 2.13.1 to 2.14.1 in /docs/docusaurus ([#2004](https://github.com/microsoft/hve-core/issues/2004)) ([86e17ab](https://github.com/microsoft/hve-core/commit/86e17ab5197af8af931ede30c45173c6f4fb3bbf))
* **deps:** bump qs and express in /docs/docusaurus ([#1632](https://github.com/microsoft/hve-core/issues/1632)) ([a2159fc](https://github.com/microsoft/hve-core/commit/a2159fca997b0d140293737a82d0b7199491c4db))
* **deps:** bump setuptools from 81.0.0 to 83.0.0 in /scripts/evals/moderation in the security-updates group across 1 directory ([#2490](https://github.com/microsoft/hve-core/issues/2490)) ([fe48cab](https://github.com/microsoft/hve-core/commit/fe48cab304656865f139e17025e00f9f41df0f3b))
* **deps:** bump the github-actions group across 1 directory with 5 updates ([#1872](https://github.com/microsoft/hve-core/issues/1872)) ([31eb145](https://github.com/microsoft/hve-core/commit/31eb145b21322af904ab0f3e1baa6088523bcac6))
* **deps:** bump the github-actions group across 1 directory with 8 updates ([#2483](https://github.com/microsoft/hve-core/issues/2483)) ([4097601](https://github.com/microsoft/hve-core/commit/4097601e63cf0a8ce28abceabd8337c3c11f0ac1))
* **deps:** bump the github-actions group with 2 updates ([#1657](https://github.com/microsoft/hve-core/issues/1657)) ([2bf7e51](https://github.com/microsoft/hve-core/commit/2bf7e514de1adb0404221b4ef832fede96582eb5))
* **deps:** bump the github-actions group with 2 updates ([#2206](https://github.com/microsoft/hve-core/issues/2206)) ([c4b724b](https://github.com/microsoft/hve-core/commit/c4b724b7dd03c255f8fcb338b2fbac6f3580114b))
* **deps:** bump the github-actions group with 3 updates ([#1453](https://github.com/microsoft/hve-core/issues/1453)) ([a3ee84e](https://github.com/microsoft/hve-core/commit/a3ee84e308e09649769e12ba6094f30eb89c9e29))
* **deps:** bump the github-actions group with 3 updates ([#1601](https://github.com/microsoft/hve-core/issues/1601)) ([173d558](https://github.com/microsoft/hve-core/commit/173d558d015d9849174acf0e38bf43eb009e11ff))
* **deps:** bump the github-actions group with 6 updates ([#2197](https://github.com/microsoft/hve-core/issues/2197)) ([59e5e81](https://github.com/microsoft/hve-core/commit/59e5e813c1de900db4680278cc2f4944c967af02))
* **deps:** bump the npm-dependencies group across 1 directory with 11 updates ([#1894](https://github.com/microsoft/hve-core/issues/1894)) ([a2eee65](https://github.com/microsoft/hve-core/commit/a2eee6582c822f601be3924968f89133988bcd24))
* **deps:** bump the npm-dependencies group across 3 directories with 15 updates ([#2491](https://github.com/microsoft/hve-core/issues/2491)) ([53ddf1a](https://github.com/microsoft/hve-core/commit/53ddf1a791b011b1e1eb1e73cd4d1a595a64c83b))
* **deps:** bump the version-updates group across 1 directory with 2 updates ([#2481](https://github.com/microsoft/hve-core/issues/2481)) ([2626c53](https://github.com/microsoft/hve-core/commit/2626c53d0c617d10a3db2a9e72798b2cb5fcc45e))
* **deps:** bump the version-updates group across 1 directory with 5 updates ([#2463](https://github.com/microsoft/hve-core/issues/2463)) ([5c15a03](https://github.com/microsoft/hve-core/commit/5c15a03c78da2408527693e0fc3b3e387bf99cb2))
* **deps:** bump torch from 2.12.0 to 2.12.1 in /scripts/evals/moderation in the security-updates group across 1 directory ([#2274](https://github.com/microsoft/hve-core/issues/2274)) ([42bec67](https://github.com/microsoft/hve-core/commit/42bec671ecf201ef3aec0232325fd3bb65a1ecaf))
* **deps:** bump torch from 2.9.1 to 2.12.0 in /scripts/evals/moderation ([#2011](https://github.com/microsoft/hve-core/issues/2011)) ([a847cfa](https://github.com/microsoft/hve-core/commit/a847cfa3b82d7c09d707d5e3d978780ad1d599d3))
* **deps:** bump urllib3 from 2.6.3 to 2.7.0 in /.github/skills/experimental/tts-voiceover ([#1583](https://github.com/microsoft/hve-core/issues/1583)) ([8d3b095](https://github.com/microsoft/hve-core/commit/8d3b09549865c181d45c75e2b259459e98f3d106))
* **deps:** bump webpack-dev-server from 5.2.3 to 5.2.4 in /docs/docusaurus ([#1613](https://github.com/microsoft/hve-core/issues/1613)) ([f689272](https://github.com/microsoft/hve-core/commit/f6892725893fdda10b805ad9b6968dc4f8f8e10b))
* **deps:** bump webpack-dev-server from 5.2.4 to 5.2.5 in /docs/docusaurus ([#2043](https://github.com/microsoft/hve-core/issues/2043)) ([85fbba9](https://github.com/microsoft/hve-core/commit/85fbba9ef17c1165fbe3722161c25a4e7c3708ce))
* **deps:** bump websocket-driver from 0.7.4 to 0.7.5 in /docs/docusaurus ([#2473](https://github.com/microsoft/hve-core/issues/2473)) ([859863e](https://github.com/microsoft/hve-core/commit/859863e8b248de363a28b06f8f099e7bd64cc0ef))
* **evals:** upgrade valley to 0.9 ([#2495](https://github.com/microsoft/hve-core/issues/2495)) ([a66a3ce](https://github.com/microsoft/hve-core/commit/a66a3ceb1ebaa7d06b201186a05bd3f75fa7a207))
* **instructions:** strip attribution suffix from descriptions ([#1721](https://github.com/microsoft/hve-core/issues/1721)) ([aa4b4c1](https://github.com/microsoft/hve-core/commit/aa4b4c118ef6a78d89d6772f28062c3e11538a40)), closes [#1712](https://github.com/microsoft/hve-core/issues/1712)
* **prompts:** strip attribution suffix from descriptions ([#1722](https://github.com/microsoft/hve-core/issues/1722)) ([23be43f](https://github.com/microsoft/hve-core/commit/23be43f9eb4e5c4524397014accacc4b303fec29)), closes [#1713](https://github.com/microsoft/hve-core/issues/1713)
* **scripts:** refine extension prep and editor settings ([#1852](https://github.com/microsoft/hve-core/issues/1852)) ([f8b2672](https://github.com/microsoft/hve-core/commit/f8b26729c1be68b343938ddd165c6866fba66ef6))
* **scripts:** standardize copyright headers to canonical 2026 format ([#2169](https://github.com/microsoft/hve-core/issues/2169)) ([05a8e1a](https://github.com/microsoft/hve-core/commit/05a8e1a08838d20eaacaa77bf494da749f0d2dea))
* **skills:** strip attribution suffix from descriptions ([#1724](https://github.com/microsoft/hve-core/issues/1724)) ([50b5447](https://github.com/microsoft/hve-core/commit/50b5447921d7cd28183bf5d98219258e6ac9d1b1)), closes [#1715](https://github.com/microsoft/hve-core/issues/1715)
* **workflows:** add pre-activation gating to VEX drafting and recompile on gh-aw v0.81.6 ([#2340](https://github.com/microsoft/hve-core/issues/2340)) ([ddcd99e](https://github.com/microsoft/hve-core/commit/ddcd99e4acf13bea024f2d8d434b6dcb9962ee4e))

## [3.2.2](https://github.com/microsoft/hve-core/compare/hve-core-v3.2.1...hve-core-v3.2.2) (2026-03-23)


### 🐛 Bug Fixes

* **workflows:** decouple SBOM artifact name from internal filename ([#1178](https://github.com/microsoft/hve-core/issues/1178)) ([c3f1ef4](https://github.com/microsoft/hve-core/commit/c3f1ef45ca126a469b38e4403eb703abc4373b4f))

## [3.2.1](https://github.com/microsoft/hve-core/compare/hve-core-v3.2.0...hve-core-v3.2.1) (2026-03-23)


### 🐛 Bug Fixes

* **workflows:** expand dependency-review license allow-list and add docusaurus build step ([#1168](https://github.com/microsoft/hve-core/issues/1168)) ([5458cab](https://github.com/microsoft/hve-core/commit/5458cab68f514c2919dafeda018ef2de2c82e763))
* **workflows:** prevent zero-diff force-push, fix SBOM attestation, and consolidate security collection ([#1159](https://github.com/microsoft/hve-core/issues/1159)) ([0fbd111](https://github.com/microsoft/hve-core/commit/0fbd1110e345d0abdd01c7be61fc08c4948cefc6))

## [3.2.0](https://github.com/microsoft/hve-core/compare/hve-core-v3.1.46...hve-core-v3.2.0) (2026-03-20)


### ✨ Features

* add -OutputPath parameter to Validate-MarkdownFrontmatter.ps1 ([#1134](https://github.com/microsoft/hve-core/issues/1134)) ([fdf1bcf](https://github.com/microsoft/hve-core/commit/fdf1bcf55bf4d77a5a82442cd52b5d48cda8a7a3)), closes [#1006](https://github.com/microsoft/hve-core/issues/1006)
* add action version consistency scan workflow ([#1127](https://github.com/microsoft/hve-core/issues/1127)) ([4229df1](https://github.com/microsoft/hve-core/commit/4229df17eafa171dedba415a8cb493f88768ceec))
* **agent:** MVE Experiment Designer ([#976](https://github.com/microsoft/hve-core/issues/976)) ([70f86ca](https://github.com/microsoft/hve-core/commit/70f86cab541cc3ab531e270fc7683c96abe7788e))
* **agents:** add ADO Backlog Manager orchestrator agent ([#800](https://github.com/microsoft/hve-core/issues/800)) ([fae3987](https://github.com/microsoft/hve-core/commit/fae3987dc301ea0dcf25feb6426be9d8b627a4d4))
* **agents:** add meeting analyst agent for transcript analysis using work-iq ([#502](https://github.com/microsoft/hve-core/issues/502)) ([5345b5b](https://github.com/microsoft/hve-core/commit/5345b5b0e880eb1b57e8bdb331a67192739d8301))
* **agents:** add quick-reference line to RPI Phase 5 suggestions ([#897](https://github.com/microsoft/hve-core/issues/897)) ([9a90f39](https://github.com/microsoft/hve-core/commit/9a90f396494098103417e2b7acb95441393e3849))
* **agents:** add RAI Planner, enhance SSSC Planner, and redesign Security Planner ([#979](https://github.com/microsoft/hve-core/issues/979)) ([06f826c](https://github.com/microsoft/hve-core/commit/06f826cac8b872215a376eb7fc90541ae7ef157b))
* **agents:** add symmetric cross-system handoff to GitHub Backlog Manager ([#952](https://github.com/microsoft/hve-core/issues/952)) ([ba34a35](https://github.com/microsoft/hve-core/commit/ba34a35c3b0d716989d4e9691ff8f2b68aaa83a7))
* **agents:** Functional Code Review Agent: pre-PR functional correctness reviewer ([#733](https://github.com/microsoft/hve-core/issues/733)) ([9cf63b7](https://github.com/microsoft/hve-core/commit/9cf63b787392b2ac94ca9add40c3164d5e1610df))
* **build:** add Python extensions and uv 0.10.8 to devcontainer ([#920](https://github.com/microsoft/hve-core/issues/920)) ([9ca0579](https://github.com/microsoft/hve-core/commit/9ca05790f03cf788747c0b2a41c0e2908429990e))
* **build:** add uv ecosystem to Dependabot configuration ([#913](https://github.com/microsoft/hve-core/issues/913)) ([2a4bd39](https://github.com/microsoft/hve-core/commit/2a4bd39224c40f6f85582bb993e9bc1a98a8347a))
* **build:** enable npm pinning enforcement in dependency scan ([#838](https://github.com/microsoft/hve-core/issues/838)) ([4e9e31f](https://github.com/microsoft/hve-core/commit/4e9e31fb767ac858581321aebe7ef825e9abdd95))
* **build:** migrate attestation actions to v4.1.0 and add SBOM verification docs ([#841](https://github.com/microsoft/hve-core/issues/841)) ([ca1e65b](https://github.com/microsoft/hve-core/commit/ca1e65b36f4f300492f4faf2907c9be31343c282))
* **collections:** add four new validator checks (orphan, duplicate, companion, coverage) ([#869](https://github.com/microsoft/hve-core/issues/869)) ([1a96b73](https://github.com/microsoft/hve-core/commit/1a96b7384cd85a53b6036e7275d391fcb75cd11d))
* **devcontainer,security:** add enterprise artifact hub configuration ([#1032](https://github.com/microsoft/hve-core/issues/1032)) ([1d56d25](https://github.com/microsoft/hve-core/commit/1d56d25494d03b3ff5b9bf68c8ec3e7e38d351d5))
* **docs:** add Rust coding standards and guidelines ([#809](https://github.com/microsoft/hve-core/issues/809)) ([d4c4899](https://github.com/microsoft/hve-core/commit/d4c489917464fd9f120ae8165de2a15a3bf01671))
* **extension:** add Microsoft logo icon to VS Code Marketplace listings ([#906](https://github.com/microsoft/hve-core/issues/906)) ([82aca41](https://github.com/microsoft/hve-core/commit/82aca413ac5ed72d497f8cdc8cb12daad9135c76))
* **github:** add declarative label management ([#953](https://github.com/microsoft/hve-core/issues/953)) ([a1a6845](https://github.com/microsoft/hve-core/commit/a1a6845007f7061a5c02ddc018c78c8513b9f527))
* **instructions:** add ADO backlog shared infrastructure ([#786](https://github.com/microsoft/hve-core/issues/786)) ([1914078](https://github.com/microsoft/hve-core/commit/191407868f766a2c6f96c7881e5dffc1dd65232c))
* **instructions:** add ADO backlog sprint planning and capacity tracking ([#788](https://github.com/microsoft/hve-core/issues/788)) ([d6fb77d](https://github.com/microsoft/hve-core/commit/d6fb77d2cd62506c41a8833a917d88925fa5a1da))
* **instructions:** add ADO triage workflow and prompt ([#787](https://github.com/microsoft/hve-core/issues/787)) ([cde0190](https://github.com/microsoft/hve-core/commit/cde0190258d8fdec015c40d6f3e5a27c3c988315))
* **instructions:** add shared story quality conventions and sprint planning ([#803](https://github.com/microsoft/hve-core/issues/803)) ([a2f18e3](https://github.com/microsoft/hve-core/commit/a2f18e37630f0779ddb59c11d530c13f03bdbd45))
* **prompts:** add ADO discovery and work item prompts with agent routing ([#790](https://github.com/microsoft/hve-core/issues/790)) ([7e74523](https://github.com/microsoft/hve-core/commit/7e745237cdf02c3d5a0cf41ab875ebbace8b7c0b))
* **prompts:** add security review prompts ([#1118](https://github.com/microsoft/hve-core/issues/1118)) ([ad30967](https://github.com/microsoft/hve-core/commit/ad30967427ba4f656ee652eddd5b1328f7ba407c))
* **scripts:** add dynamic Python skill discovery for lint/test ([#957](https://github.com/microsoft/hve-core/issues/957)) ([0a90f57](https://github.com/microsoft/hve-core/commit/0a90f5732f199eea08b39902fb1d5f186aee1486))
* **scripts:** add Get-StandardTimestamp utility to CIHelpers module ([#1126](https://github.com/microsoft/hve-core/issues/1126)) ([b273a4b](https://github.com/microsoft/hve-core/commit/b273a4ba1a2a5dd1a435e2879fe456206af5006e))
* **scripts:** add Python copyright header validation ([#905](https://github.com/microsoft/hve-core/issues/905)) ([67df902](https://github.com/microsoft/hve-core/commit/67df902f90c7652251565eb4b67375c4e080e7a8))
* **scripts:** add Python skill support to Validate-SkillStructure ([#903](https://github.com/microsoft/hve-core/issues/903)) ([68479d9](https://github.com/microsoft/hve-core/commit/68479d91cba17f1bf76df90889e34fb0e0b3214d))
* **scripts:** add workflow npm command scanning to dependency pinning ([#837](https://github.com/microsoft/hve-core/issues/837)) ([6b5ae06](https://github.com/microsoft/hve-core/commit/6b5ae0678c3a450006e30add31f0a795c1459ea3))
* **security:** add basic security reviewer agent with owasp skills ([#1008](https://github.com/microsoft/hve-core/issues/1008)) ([cb1fd05](https://github.com/microsoft/hve-core/commit/cb1fd0503cdfef2cc53e0d72d31bd19a4d21b9bc))
* **security:** add sigstore attestation bundles and fix component-detection action ([#1148](https://github.com/microsoft/hve-core/issues/1148)) ([f79c272](https://github.com/microsoft/hve-core/commit/f79c272d7c0083b82420c1e6afdff8f042246aae))
* **skills:** add Atheris fuzz harness with CI workflow integration ([#1102](https://github.com/microsoft/hve-core/issues/1102)) ([d337e1d](https://github.com/microsoft/hve-core/commit/d337e1d2ed2e3da686af63ed4c72f323ad7abab9))
* **skills:** add PowerPoint automation skill with YAML-driven deck generation ([#868](https://github.com/microsoft/hve-core/issues/868)) ([00465cd](https://github.com/microsoft/hve-core/commit/00465cd990fe351d36d8f2ff8c8f6ecd77cbbb3b))
* **skills:** convert hve-core-installer agent to self-contained skill ([#846](https://github.com/microsoft/hve-core/issues/846)) ([1d821fb](https://github.com/microsoft/hve-core/commit/1d821fbddf6a71bee08ae750f7dbc0e5f9f18a95))
* **skills:** enhance pr-reference skill with flexible filtering and base branch detection ([#1095](https://github.com/microsoft/hve-core/issues/1095)) ([26a32ea](https://github.com/microsoft/hve-core/commit/26a32ea1a09d5f74489f723a3a1d8280fbc6afd9))
* **workflows:** add devcontainer infrastructure change log workflow ([#899](https://github.com/microsoft/hve-core/issues/899)) ([8aca446](https://github.com/microsoft/hve-core/commit/8aca44624e6d8c8a54051ca7d7fbdd1b27b9073f))
* **workflows:** add milestone auto-close on stable and pre-release publishes ([#834](https://github.com/microsoft/hve-core/issues/834)) ([79362b1](https://github.com/microsoft/hve-core/commit/79362b127ae731607344a66ceb96956c3dcf779f))
* **workflows:** add ms.date documentation freshness checking ([#969](https://github.com/microsoft/hve-core/issues/969)) ([3ed441c](https://github.com/microsoft/hve-core/commit/3ed441c3d4a92f1fa944a2121273ba46fdab8a8d))
* **workflows:** add Python linting CI workflow with Ruff ([#951](https://github.com/microsoft/hve-core/issues/951)) ([f89f0eb](https://github.com/microsoft/hve-core/commit/f89f0eb63e0606c1291b6e400dcd8e79ee9d3e96))
* **workflows:** add Python testing CI workflow with pytest and Codecov ([#934](https://github.com/microsoft/hve-core/issues/934)) ([5e8306f](https://github.com/microsoft/hve-core/commit/5e8306fb4d6912b55b0106a60c9b632af77500a1))
* **workflows:** add uv and Python package sync to copilot-setup-steps ([#921](https://github.com/microsoft/hve-core/issues/921)) ([45d517d](https://github.com/microsoft/hve-core/commit/45d517d3e618389df9204f00be3f7180a3cd339a))


### 🐛 Bug Fixes

* **build:** override Linguist vendored flag for Python skill files ([#1155](https://github.com/microsoft/hve-core/issues/1155)) ([0eee5b6](https://github.com/microsoft/hve-core/commit/0eee5b613c21460bc5dd0d17df4dd9be1c006b03))
* **build:** override serialize-javascript to &gt;=7.0.3 for RCE fix ([#876](https://github.com/microsoft/hve-core/issues/876)) ([e49039a](https://github.com/microsoft/hve-core/commit/e49039ae37bde741b14fbb1ffe4a338f625c8b7f))
* **build:** resolve Pinned-Dependencies alerts for vsce npm commands in extension workflows ([#782](https://github.com/microsoft/hve-core/issues/782)) ([89dad9d](https://github.com/microsoft/hve-core/commit/89dad9dfc714f7ed5bdfb747e777d88771fcd71e))
* **build:** update undici and yauzl overrides for security audit ([#1030](https://github.com/microsoft/hve-core/issues/1030)) ([2c2f92f](https://github.com/microsoft/hve-core/commit/2c2f92f6b96b1c5e332a34a8a0a2c20e55491754))
* **docs:** add CLI Plugins to install.md navigation surfaces ([#902](https://github.com/microsoft/hve-core/issues/902)) ([79d6595](https://github.com/microsoft/hve-core/commit/79d6595037cfa598c8325551992cccbc9e3e66b4))
* **docs:** add sidebar ordering for Design Thinking documentation ([#832](https://github.com/microsoft/hve-core/issues/832)) ([551fddc](https://github.com/microsoft/hve-core/commit/551fddca21cf34b50421b8f4274aaeef8e42d5f8)), closes [#830](https://github.com/microsoft/hve-core/issues/830)
* **docs:** graduate design-thinking to preview and correct stale collection references ([#831](https://github.com/microsoft/hve-core/issues/831)) ([5110e35](https://github.com/microsoft/hve-core/commit/5110e358561634806dabaf7b8f9c6943cef1f7c6))
* **docs:** include project-planning in UX Designer install guidance ([#908](https://github.com/microsoft/hve-core/issues/908)) ([e7aa9bc](https://github.com/microsoft/hve-core/commit/e7aa9bc1a4d925fe81bbd7fa407ccc9e3b475190))
* **docs:** remediate writing-style convention violations ([#865](https://github.com/microsoft/hve-core/issues/865)) ([68b04bc](https://github.com/microsoft/hve-core/commit/68b04bc3b47266718f1570cf7f2cb7908467f8d4))
* **docs:** remove draft content announcement banner ([#825](https://github.com/microsoft/hve-core/issues/825)) ([b45de80](https://github.com/microsoft/hve-core/commit/b45de8055fefe9ee67ada5e51e88bfc07898ce5c))
* **docs:** remove unbounded path-to-regexp override breaking SSG ([#1153](https://github.com/microsoft/hve-core/issues/1153)) ([d810018](https://github.com/microsoft/hve-core/commit/d8100189509c6a092dc5f02b6e7b948e56e19b14))
* **docs:** use actual clone paths instead of folder display names in multi-root workspace settings ([#984](https://github.com/microsoft/hve-core/issues/984)) ([5dbab82](https://github.com/microsoft/hve-core/commit/5dbab823af4aaa7d124dacc6c43b6dcee7b791a2))
* **instructions:** replace black with ruff in uv-projects ([#898](https://github.com/microsoft/hve-core/issues/898)) ([b0c06d9](https://github.com/microsoft/hve-core/commit/b0c06d9f56b7609ea51e99e8544f92eb9e8b4284))
* **scripts:** cover .github/ skill files in copyright header validation ([#1055](https://github.com/microsoft/hve-core/issues/1055)) ([#1098](https://github.com/microsoft/hve-core/issues/1098)) ([27fbd33](https://github.com/microsoft/hve-core/commit/27fbd33df1a8da340acb3c6cf4e433bc51269c69))
* **scripts:** eliminate phantom git changes from plugin generation ([#1035](https://github.com/microsoft/hve-core/issues/1035)) ([e49a1b5](https://github.com/microsoft/hve-core/commit/e49a1b55d19044ea0b2ebc5e79d117498f5f55e7))
* **scripts:** enable JSON log output for lint:version-consistency ([#1033](https://github.com/microsoft/hve-core/issues/1033)) ([52b0885](https://github.com/microsoft/hve-core/commit/52b08852ed15fe0d48d82a0b4fc106f69d66b2f0))
* **security:** calculate compliance score from total scanned dependencies ([#930](https://github.com/microsoft/hve-core/issues/930)) ([c112c3d](https://github.com/microsoft/hve-core/commit/c112c3db9fb56ae2cb7bfcf966c7222cbfb4eeab))
* **skills:** add AST validation and namespace restriction for content-extra.py ([#1027](https://github.com/microsoft/hve-core/issues/1027)) ([c50c7a3](https://github.com/microsoft/hve-core/commit/c50c7a369c96cdcbd1be2ff5c83a6d0e3465e74a))
* **skills:** add depth limits to recursive PowerPoint processing functions ([#1028](https://github.com/microsoft/hve-core/issues/1028)) ([bf08994](https://github.com/microsoft/hve-core/commit/bf08994dbecf3ddd928a8e56e72a7d94a8cb1ae6))
* **skills:** harden XML parsing and blob writes in powerpoint extract ([#1053](https://github.com/microsoft/hve-core/issues/1053)) ([89d24b1](https://github.com/microsoft/hve-core/commit/89d24b1930fb9dd631538d54baa7a86a0bad8698))
* **skills:** resolve ruff lint and format violations in powerpoint skill ([#1048](https://github.com/microsoft/hve-core/issues/1048)) ([17bbe7a](https://github.com/microsoft/hve-core/commit/17bbe7a389cc167f94d32ac3b677ec81c7569525))
* **workflows:** add uv.lock dependencies submission have fork-skip condition ([#1109](https://github.com/microsoft/hve-core/issues/1109)) ([dec56ac](https://github.com/microsoft/hve-core/commit/dec56acdf13d1a88b09b490b1f890785ab99087c))
* **workflows:** automate weekly SHA staleness check with issue creation ([#975](https://github.com/microsoft/hve-core/issues/975)) ([1ea4caa](https://github.com/microsoft/hve-core/commit/1ea4caa304669986d1173c0b26e42ffb1be8dcb4))
* **workflows:** close Codecov integration gaps for Pester and pytest flags ([#1106](https://github.com/microsoft/hve-core/issues/1106)) ([cca29b7](https://github.com/microsoft/hve-core/commit/cca29b79b3d3c12009fc46167e482a7fd17ae58a))
* **workflows:** propagate uv sync errors in copilot-setup-steps ([#961](https://github.com/microsoft/hve-core/issues/961)) ([df88d7c](https://github.com/microsoft/hve-core/commit/df88d7c3c9930a591d639e903117e01b5744e6df))
* **workflows:** resolve release-please skip cascade and Python project discovery ([#1043](https://github.com/microsoft/hve-core/issues/1043)) ([79993e2](https://github.com/microsoft/hve-core/commit/79993e2cb47e891e0518817f2acdf86a32c96478))
* **workflows:** scan only commit subjects for breaking change detection ([#1157](https://github.com/microsoft/hve-core/issues/1157)) ([a38a657](https://github.com/microsoft/hve-core/commit/a38a6574f9cf1b4c3fcf8e3cc4be2579ef650cec))


### 📚 Documentation

* clarify HVE Core Extension vs Installer messaging across documentation ([#965](https://github.com/microsoft/hve-core/issues/965)) ([0fceb8f](https://github.com/microsoft/hve-core/commit/0fceb8f831c67b50ea3f50dc2eb4865a355052f3))
* **docs:** add ADO integration user documentation ([#935](https://github.com/microsoft/hve-core/issues/935)) ([ec89302](https://github.com/microsoft/hve-core/commit/ec893029498d9922ee2b8f4697dbba9ee4750faa))
* **docs:** add Project Planning agent documentation ([#936](https://github.com/microsoft/hve-core/issues/936)) ([3a3a0fd](https://github.com/microsoft/hve-core/commit/3a3a0fdf923d96a9e8a9ac734c73f24433b525e8))
* **onboarding:** overhaul marketplace onboarding and documentation site ([#982](https://github.com/microsoft/hve-core/issues/982)) ([4309e10](https://github.com/microsoft/hve-core/commit/4309e10a9ef768dca817220f1e597a4f03929069))


### ♻️ Refactoring

* **build:** merge code-review collection into coding-standards ([#863](https://github.com/microsoft/hve-core/issues/863)) ([8027e7b](https://github.com/microsoft/hve-core/commit/8027e7b1574871528b3bfa538fa92cc708f4ee3f))
* **workflows:** rename release pipeline workflows and add marketplace automation triggers ([#829](https://github.com/microsoft/hve-core/issues/829)) ([b6397f4](https://github.com/microsoft/hve-core/commit/b6397f4388c0a71843c7b82e4e41a87f97806618))


### 🔧 Maintenance

* **build:** add clean:logs npm script ([#1122](https://github.com/microsoft/hve-core/issues/1122)) ([f85fe02](https://github.com/microsoft/hve-core/commit/f85fe02fd0a2ff2db3ab9427e0941bc9bba88c6f)), closes [#988](https://github.com/microsoft/hve-core/issues/988)
* **build:** add JSON reporter for cspell ([#1123](https://github.com/microsoft/hve-core/issues/1123)) ([6d59f67](https://github.com/microsoft/hve-core/commit/6d59f6749acb148c2b0105e42e00cd50cc957165))
* **ci:** add multi-arch support to copilot-setup-steps binary downloads ([#955](https://github.com/microsoft/hve-core/issues/955)) ([8d0c706](https://github.com/microsoft/hve-core/commit/8d0c7061895dc31b55280547c1f2f1615ace90fd))
* **deps-dev:** bump cspell from 9.6.4 to 9.7.0 in the npm-dependencies group ([#839](https://github.com/microsoft/hve-core/issues/839)) ([3fa16ff](https://github.com/microsoft/hve-core/commit/3fa16ffd65c1f04a1be713f522b3245bc4312d14))
* **deps:** bump actions/dependency-review-action from 4.8.3 to 4.9.0 in the github-actions group across 1 directory ([#942](https://github.com/microsoft/hve-core/issues/942)) ([1a9b858](https://github.com/microsoft/hve-core/commit/1a9b8583a45d1d2e6534043791c1e47050b6ef60))
* **deps:** bump cairosvg from 2.8.2 to 2.9.0 in /.github/skills/experimental/powerpoint ([#1025](https://github.com/microsoft/hve-core/issues/1025)) ([f4deda7](https://github.com/microsoft/hve-core/commit/f4deda7ae863ce1a26dff6b648f083dc9915a91c))
* **deps:** bump dompurify from 3.3.1 to 3.3.2 in /docs/docusaurus ([#924](https://github.com/microsoft/hve-core/issues/924)) ([d2060d6](https://github.com/microsoft/hve-core/commit/d2060d644d83e213bfd2fa5e7373f8103727592b))
* **deps:** bump svgo from 3.3.2 to 3.3.3 in /docs/docusaurus ([#880](https://github.com/microsoft/hve-core/issues/880)) ([6dc2406](https://github.com/microsoft/hve-core/commit/6dc2406bdf6baf972e8610dfd722663f28610d3b))
* **deps:** bump the github-actions group across 1 directory with 4 updates ([#1100](https://github.com/microsoft/hve-core/issues/1100)) ([2290dc0](https://github.com/microsoft/hve-core/commit/2290dc07ef2feb78e1ef53cec80d9ee86803248d))
* **deps:** bump the github-actions group with 6 updates ([#840](https://github.com/microsoft/hve-core/issues/840)) ([f57bc01](https://github.com/microsoft/hve-core/commit/f57bc01fd2a0939b05598cdc0143f0f42f4f6b67))
* **docs:** correct New-MsDateReport table rendering and refresh stale docs ([#1114](https://github.com/microsoft/hve-core/issues/1114)) ([c2b806f](https://github.com/microsoft/hve-core/commit/c2b806fc4b6cf2a667e9ba1ede50ccef259b360d))
* **settings:** remove orphaned Checkov config and stale gitignore entries ([#870](https://github.com/microsoft/hve-core/issues/870)) ([98fcd74](https://github.com/microsoft/hve-core/commit/98fcd7405550b32b14496ad4edfcb51eb5ef3977))

## [3.0.2](https://github.com/microsoft/hve-core/compare/hve-core-v3.0.1...hve-core-v3.0.2) (2026-02-21)


### 🐛 Bug Fixes

* **agents:** add commit message presentation to RPI agent review completion ([#721](https://github.com/microsoft/hve-core/issues/721)) ([a063996](https://github.com/microsoft/hve-core/commit/a06399696275e92b6d76b04421f70f8df43e8f8c))
* **agents:** standardize name frontmatter to human-readable format ([#716](https://github.com/microsoft/hve-core/issues/716)) ([f3e05d8](https://github.com/microsoft/hve-core/commit/f3e05d8bfd2fdffd564a003bf162f24d3a3ca44c))
* **extension:** preserve artifact directory structure in collection packaging ([#725](https://github.com/microsoft/hve-core/issues/725)) ([4fa94e0](https://github.com/microsoft/hve-core/commit/4fa94e041749a231e5148b6c3054197c389d30bf))
* **instructions:** pull request template body case-insensitive ([#719](https://github.com/microsoft/hve-core/issues/719)) ([4cc2a5c](https://github.com/microsoft/hve-core/commit/4cc2a5c98f987cd29dc4c9d52463246cf5796101))
* **instructions:** reorder branch freshness gate before diff generation ([#723](https://github.com/microsoft/hve-core/issues/723)) ([23b457c](https://github.com/microsoft/hve-core/commit/23b457c0e7643629b8438497895e7cf9c2609566))

## [3.0.1](https://github.com/microsoft/hve-core/compare/hve-core-v3.0.0...hve-core-v3.0.1) (2026-02-20)


### 🐛 Bug Fixes

* **scripts:** add marketplace manifest validation and standardize source format ([#711](https://github.com/microsoft/hve-core/issues/711)) ([c5ac616](https://github.com/microsoft/hve-core/commit/c5ac616f3b255e17caa187f7a0b585540b9f8999))

## [3.0.0](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.10...hve-core-v3.0.0) (2026-02-20)


### ⚠ BREAKING CHANGES

* **skills:** migrate PR reference generation to self-contained skill ([#669](https://github.com/microsoft/hve-core/issues/669))
* restructure RPI collection to HVE Core naming convention ([#668](https://github.com/microsoft/hve-core/issues/668))

### ✨ Features

* **agents:** add agile-coach agent ([#562](https://github.com/microsoft/hve-core/issues/562)) ([de8d86c](https://github.com/microsoft/hve-core/commit/de8d86c8609df811499c206f7fc644555ee4e903))
* **agents:** add DT coach agent with tiered instruction loading ([#656](https://github.com/microsoft/hve-core/issues/656)) ([206d3a7](https://github.com/microsoft/hve-core/commit/206d3a70abbfd0e54d8486426e0108d4887ce283))
* **agents:** add product manager advisor and UX/UI designer agents ([#627](https://github.com/microsoft/hve-core/issues/627)) ([539eb8a](https://github.com/microsoft/hve-core/commit/539eb8ab8aacf79dcb833d9df72c64d12000af8a))
* **agents:** add system architecture reviewer for design trade-offs and ADR creation ([#626](https://github.com/microsoft/hve-core/issues/626)) ([de5cfd6](https://github.com/microsoft/hve-core/commit/de5cfd6214cdb0a0196f476bdcf8b665dabd6a1b))
* **build:** pin devcontainer image and align tool parity ([#704](https://github.com/microsoft/hve-core/issues/704)) ([6258b1c](https://github.com/microsoft/hve-core/commit/6258b1c45b570aab098f142e7997b5d819c17905))
* **design-thinking:** add manufacturing industry context template ([#682](https://github.com/microsoft/hve-core/issues/682)) ([ce864bf](https://github.com/microsoft/hve-core/commit/ce864bf7794b1e59d728b9529cfe2a8ece371f7c))
* **instructions:** add DT coaching state protocol for session persistence ([#654](https://github.com/microsoft/hve-core/issues/654)) ([5a5be4e](https://github.com/microsoft/hve-core/commit/5a5be4e1a1bc4d09d343de6e5ddcd1509c342d7a))
* **instructions:** add dt-coaching-identity ambient instruction ([#642](https://github.com/microsoft/hve-core/issues/642)) ([6209a0d](https://github.com/microsoft/hve-core/commit/6209a0dae2c177a559118f6dce4591492a51615e))
* **instructions:** add dt-method-01-deep for advanced scope conversation techniques ([#673](https://github.com/microsoft/hve-core/issues/673)) ([cc92ef9](https://github.com/microsoft/hve-core/commit/cc92ef9e1bf4934edd37c6d2896fd4f5fe624b7e))
* **instructions:** add dt-method-03-deep for advanced input synthesis techniques ([#676](https://github.com/microsoft/hve-core/issues/676)) ([0079a4f](https://github.com/microsoft/hve-core/commit/0079a4f6ff0d2de74fb883a003e20a20d741e38f))
* **instructions:** add dt-method-09-deep instructions for Method 9 advanced coaching ([#703](https://github.com/microsoft/hve-core/issues/703)) ([150b2a6](https://github.com/microsoft/hve-core/commit/150b2a6787a70867cbeee5e95ed759008dad6e31))
* **instructions:** add dt-method-sequencing ambient instruction ([#650](https://github.com/microsoft/hve-core/issues/650)) ([e465b2f](https://github.com/microsoft/hve-core/commit/e465b2f7880466942b0e730cd022ec9c58c1c9b5))
* **instructions:** add dt-quality-constraints and design-thinking collection ([#645](https://github.com/microsoft/hve-core/issues/645)) ([17002bd](https://github.com/microsoft/hve-core/commit/17002bd2e5fcefd8adc52161c411fab48106b724))
* **instructions:** add DT-to-RPI handoff contract specification ([#679](https://github.com/microsoft/hve-core/issues/679)) ([87f9962](https://github.com/microsoft/hve-core/commit/87f996239965144b9293139e0fe92419fab6b25a))
* **instructions:** add energy industry context template ([#687](https://github.com/microsoft/hve-core/issues/687)) ([41088d8](https://github.com/microsoft/hve-core/commit/41088d8cace7217ad292b138eb82161f753d50c6))
* **instructions:** add healthcare industry context template ([#686](https://github.com/microsoft/hve-core/issues/686)) ([b2d5281](https://github.com/microsoft/hve-core/commit/b2d52811097c964d248c0f50f33968b192a367b5))
* **instructions:** add Method 1 Scope Conversations coaching knowledge ([#651](https://github.com/microsoft/hve-core/issues/651)) ([93e2d48](https://github.com/microsoft/hve-core/commit/93e2d485a77c1adc7cea7f1e377b710f24f497ce))
* **instructions:** add Method 2 Design Research coaching knowledge ([#652](https://github.com/microsoft/hve-core/issues/652)) ([30f7f3b](https://github.com/microsoft/hve-core/commit/30f7f3bd65ea1d96f5fe7697583653756668056e))
* **instructions:** add Method 3 Input Synthesis coaching knowledge ([#653](https://github.com/microsoft/hve-core/issues/653)) ([1efdb7d](https://github.com/microsoft/hve-core/commit/1efdb7dacff762c88558d9b8e160a365d84e75c8))
* **instructions:** add Method 7 High-Fidelity Prototypes coaching instruction ([#666](https://github.com/microsoft/hve-core/issues/666)) ([9233eab](https://github.com/microsoft/hve-core/commit/9233eab9f1b4630dd38f02184750477c98d1ebc8))
* **instructions:** add pull request instructions for PR generation workflow ([#706](https://github.com/microsoft/hve-core/issues/706)) ([73d23eb](https://github.com/microsoft/hve-core/commit/73d23eb371c20eaf64e16d35e6dec3fb1cc5d38b))
* **instructions:** create DT curriculum content (9 modules) ([#690](https://github.com/microsoft/hve-core/issues/690)) ([9f7378f](https://github.com/microsoft/hve-core/commit/9f7378f34d8a7c3f5279de31a2c0327ecba984ad)), closes [#617](https://github.com/microsoft/hve-core/issues/617)
* **instructions:** create dt-method-02-deep.instructions.md ([#700](https://github.com/microsoft/hve-core/issues/700)) ([4d4d0ca](https://github.com/microsoft/hve-core/commit/4d4d0caacad6147d4f0669826fa69c2f97e79ebf))
* **instructions:** create dt-method-06-lofi-prototypes.instructions.md ([#684](https://github.com/microsoft/hve-core/issues/684)) ([4d5f757](https://github.com/microsoft/hve-core/commit/4d5f7571cb72864e5142c6549a5047c37f6a29b6))
* **instructions:** create dt-method-07-deep.instructions.md ([#678](https://github.com/microsoft/hve-core/issues/678)) ([d3ec70d](https://github.com/microsoft/hve-core/commit/d3ec70d6eae62fb09d103e6ab3255f75e01d41c6))
* **instructions:** Create dt-method-08-deep.instructions.md ([#683](https://github.com/microsoft/hve-core/issues/683)) ([d9e1115](https://github.com/microsoft/hve-core/commit/d9e11152b194a7a59aaa4ca5192dc38046f3070a))
* **instructions:** create dt-method-08-testing.instructions.md ([#681](https://github.com/microsoft/hve-core/issues/681)) ([3008ad8](https://github.com/microsoft/hve-core/commit/3008ad8054056c2760c7f334d93f77485aff3717))
* **instructions:** create dt-method-09-iteration.instructions.md ([#685](https://github.com/microsoft/hve-core/issues/685)) ([9d7f4f5](https://github.com/microsoft/hve-core/commit/9d7f4f5e50f513fdeaa77319fb2343359d104028))
* **instructions:** create dt-rpi-research-context.instructions.md ([#689](https://github.com/microsoft/hve-core/issues/689)) ([34c7b89](https://github.com/microsoft/hve-core/commit/34c7b89db2788a8ccc0cba00ff4083a2b0eb9b35))
* **instructions:** create manufacturing reference learning scenario ([#692](https://github.com/microsoft/hve-core/issues/692)) ([1bd3994](https://github.com/microsoft/hve-core/commit/1bd39946f284e60b5015c938085ff42ab26d4cec))
* **instructions:** Design Thinking Method 4 brainstorming instruction file ([#664](https://github.com/microsoft/hve-core/issues/664)) ([06f90b0](https://github.com/microsoft/hve-core/commit/06f90b0681203468a9c1a2e235768bbd73244df5))
* **prompts:** add DT start-project prompt for coaching initialization ([#657](https://github.com/microsoft/hve-core/issues/657)) ([ce583d5](https://github.com/microsoft/hve-core/commit/ce583d509c25e0425062095544dcf26ec09752ce))
* **prompts:** add dt-resume-coaching prompt for session recovery ([#665](https://github.com/microsoft/hve-core/issues/665)) ([11b93cb](https://github.com/microsoft/hve-core/commit/11b93cb662dd89c4cd7b65fefcc8bc6071d1faf1))
* **prompts:** create dt-handoff-problem-space.prompt.md ([#688](https://github.com/microsoft/hve-core/issues/688)) ([277963d](https://github.com/microsoft/hve-core/commit/277963de44aa0b6db146efba1fb5cd6ab49a8a0c))
* **scripts:** add collection-level maturity field with validation, gating, and notices ([#697](https://github.com/microsoft/hve-core/issues/697)) ([7b1c8e8](https://github.com/microsoft/hve-core/commit/7b1c8e826620db36c582447fc1431e912f1ed22a))
* **scripts:** add per-violation CI annotations and colorized console output ([#637](https://github.com/microsoft/hve-core/issues/637)) ([bd7d512](https://github.com/microsoft/hve-core/commit/bd7d512209499b201a0c672899ee2a81c1cfc94d))
* **skills:** edit SKILL frontmatter schema, add CI validation, and documentation ([#625](https://github.com/microsoft/hve-core/issues/625)) ([0138a78](https://github.com/microsoft/hve-core/commit/0138a78abb05059fb36cec9c029fdd58f54d2d5b))
* **skills:** mandate unit testing and document language support ([#636](https://github.com/microsoft/hve-core/issues/636)) ([9263617](https://github.com/microsoft/hve-core/commit/9263617806792ba6bfaa06c778c7195b05f40d5f))
* **skills:** migrate PR reference generation to self-contained skill ([#669](https://github.com/microsoft/hve-core/issues/669)) ([cf8805f](https://github.com/microsoft/hve-core/commit/cf8805f96742670ef6436a081be582864c7e4e86))


### 🐛 Bug Fixes

* **collections:** migrate artifacts into collection-based subdirectories ([#658](https://github.com/microsoft/hve-core/issues/658)) ([dfa5261](https://github.com/microsoft/hve-core/commit/dfa52619f128ff744bfff4cb17bbc6de3624b9df))
* **instructions:** optimize Phase 1 DT token budgets and close [#564](https://github.com/microsoft/hve-core/issues/564)/[#565](https://github.com/microsoft/hve-core/issues/565) gaps ([#675](https://github.com/microsoft/hve-core/issues/675)) ([4f42f00](https://github.com/microsoft/hve-core/commit/4f42f00de1c2ba47b7c913acbd76e1b4e9b3b354))
* **scripts:** add CI annotations and step summary to copyright header check ([#638](https://github.com/microsoft/hve-core/issues/638)) ([5fa6328](https://github.com/microsoft/hve-core/commit/5fa63281cac96faae6f7442d726651d45934d466))
* **scripts:** add grouped link-lang console diagnostics and failure summary ([#661](https://github.com/microsoft/hve-core/issues/661)) ([4d6871f](https://github.com/microsoft/hve-core/commit/4d6871fa082600e781e0c7d9b8df6e2a1539f700))
* **scripts:** add per-violation Write-Host and Write-CIAnnotation output to Test-DependencyPinning ([#640](https://github.com/microsoft/hve-core/issues/640)) ([9d3b71d](https://github.com/microsoft/hve-core/commit/9d3b71dc43e9762943c5092d855086f55dcb8473))
* **scripts:** align agent frontmatter schema with VS Code spec ([#469](https://github.com/microsoft/hve-core/issues/469)) ([254d445](https://github.com/microsoft/hve-core/commit/254d4454d17e8794ba5ee533457c078dd7f2334f))
* **scripts:** optimize PSScriptAnalyzer linting performance in WSL2 ([#667](https://github.com/microsoft/hve-core/issues/667)) ([f120b93](https://github.com/microsoft/hve-core/commit/f120b93b198a69de5c9d889a2fce554cc9cbe13d))
* **scripts:** stabilize YAML display key ordering in collection manifest ([#701](https://github.com/microsoft/hve-core/issues/701)) ([73c0d2c](https://github.com/microsoft/hve-core/commit/73c0d2ca189f5b73387de6a78e432956230cfd76))
* **scripts:** use text stubs for plugin links when symlinks unavailable ([#695](https://github.com/microsoft/hve-core/issues/695)) ([d7650a3](https://github.com/microsoft/hve-core/commit/d7650a3a4b4acc2949d42f9a755285fe261271f8))
* **skills:** fix powershell test coverage in pr-reference skill ([#699](https://github.com/microsoft/hve-core/issues/699)) ([408e6b7](https://github.com/microsoft/hve-core/commit/408e6b76925e5787f9f19e79cc21d637de8071b3))


### 📚 Documentation

* **dt:** add Method 5 Concepts and Method 6 Lo-Fi Prototypes instructions ([#693](https://github.com/microsoft/hve-core/issues/693)) ([cfdcf11](https://github.com/microsoft/hve-core/commit/cfdcf11cbc4fbe03af374436a53f51e9e627b872))
* **hve-guide:** add role-based guides and project lifecycle documentation ([#663](https://github.com/microsoft/hve-core/issues/663)) ([17a85da](https://github.com/microsoft/hve-core/commit/17a85daf2f170d57880c18936fe38b190d2f5b2e))


### ♻️ Refactoring

* restructure RPI collection to HVE Core naming convention ([#668](https://github.com/microsoft/hve-core/issues/668)) ([120dde0](https://github.com/microsoft/hve-core/commit/120dde0dc7a824b995a18fd3f07d8e15947ddf79))
* **scripts:** consolidate duplicate logging into shared SecurityHelpers module ([#655](https://github.com/microsoft/hve-core/issues/655)) ([627a877](https://github.com/microsoft/hve-core/commit/627a87791c9fc94fbfbd596589ce6a1faaaa013d))
* **scripts:** use shared SecurityHelpers and CIHelpers modules in security scripts ([#705](https://github.com/microsoft/hve-core/issues/705)) ([3a0baa7](https://github.com/microsoft/hve-core/commit/3a0baa73679086c8f833cbd4c807586a63342a08))


### 🔧 Maintenance

* **deps-dev:** bump markdownlint-cli2 from 0.20.0 to 0.21.0 in the npm-dependencies group ([#609](https://github.com/microsoft/hve-core/issues/609)) ([1486dd7](https://github.com/microsoft/hve-core/commit/1486dd72b1f4175a42ae376bc4ec8f1026058b9e))

## [2.3.10](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.9...hve-core-v2.3.10) (2026-02-17)


### 🐛 Bug Fixes

* **agents:** add subagent support with dedicated subagent files and simplified prompts ([#639](https://github.com/microsoft/hve-core/issues/639)) ([c080b0a](https://github.com/microsoft/hve-core/commit/c080b0a0c7e29e0b7431c84b7f7ad1b4405bd25e))
* Markdown table in Codespace is not rendered correctly ([#619](https://github.com/microsoft/hve-core/issues/619)) ([5bcea1d](https://github.com/microsoft/hve-core/commit/5bcea1dd01bface78ebab10b7b7b97f17cc75ad2))


### 📚 Documentation

* **ai-artifacts:** align contribution guide with plugin and collection workflow ([#622](https://github.com/microsoft/hve-core/issues/622)) ([21820be](https://github.com/microsoft/hve-core/commit/21820beecb00589fc1f055b631ec56989c1a6aeb))

## [2.3.9](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.8...hve-core-v2.3.9) (2026-02-14)


### 🐛 Bug Fixes

* **plugins:** merge git collection into rpi and distribute to all plugins ([#549](https://github.com/microsoft/hve-core/issues/549)) ([9509a87](https://github.com/microsoft/hve-core/commit/9509a87bc32bb91205ec4000553f706f01039a57))

## [2.3.8](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.7...hve-core-v2.3.8) (2026-02-14)


### 🐛 Bug Fixes

* **workflows:** use draft-first release flow to avoid immutability errors ([#554](https://github.com/microsoft/hve-core/issues/554)) ([c8eee58](https://github.com/microsoft/hve-core/commit/c8eee58ce370c1a6bcf8d25fd55f7d2430eaa8de))

## [2.3.7](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.6...hve-core-v2.3.7) (2026-02-13)


### 🐛 Bug Fixes

* **workflows:** delete and recreate draft release to publish ([#552](https://github.com/microsoft/hve-core/issues/552)) ([e3d6fca](https://github.com/microsoft/hve-core/commit/e3d6fca6e1f683f2913b28449ebbacec4f040ce3))

## [2.3.6](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.5...hve-core-v2.3.6) (2026-02-13)


### 🐛 Bug Fixes

* **workflows:** delete and recreate immutable release as draft ([#550](https://github.com/microsoft/hve-core/issues/550)) ([75217da](https://github.com/microsoft/hve-core/commit/75217da01caa3aa57d313d149a065f207e28209c))

## [2.3.5](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.4...hve-core-v2.3.5) (2026-02-13)


### 🐛 Bug Fixes

* **workflows:** replace draft release config with post-creation draft conversion ([#545](https://github.com/microsoft/hve-core/issues/545)) ([2311d04](https://github.com/microsoft/hve-core/commit/2311d04297ab1a607d03163e54dd278146254fdf))

## [2.3.4](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.3...hve-core-v2.3.4) (2026-02-13)


### 🐛 Bug Fixes

* **workflows:** package pre-release VSIX artifacts correctly ([#544](https://github.com/microsoft/hve-core/issues/544)) ([f5f6887](https://github.com/microsoft/hve-core/commit/f5f6887a546f49a6bbb3877e61cab671ce0c92e6))

## [2.3.3](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.2...hve-core-v2.3.3) (2026-02-13)


### 🐛 Bug Fixes

* **workflows:** add manual tag creation for draft releases until release-please-action updates ([#538](https://github.com/microsoft/hve-core/issues/538)) ([4a6ef2c](https://github.com/microsoft/hve-core/commit/4a6ef2c3ed691b26d4fd35f2086758d861c33cdb))

## [2.3.2](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.1...hve-core-v2.3.2) (2026-02-13)


### 🐛 Bug Fixes

* **settings:** ensure draft flag is set for release configuration ([#536](https://github.com/microsoft/hve-core/issues/536)) ([9e98c68](https://github.com/microsoft/hve-core/commit/9e98c688a15e769b15b2a28f8ea283dfe3cbe795))

## [2.3.1](https://github.com/microsoft/hve-core/compare/hve-core-v2.3.0...hve-core-v2.3.1) (2026-02-13)


### 🐛 Bug Fixes

* **build:** remove draft flag that prevents release tag creation ([#533](https://github.com/microsoft/hve-core/issues/533)) ([c8de0aa](https://github.com/microsoft/hve-core/commit/c8de0aa65a313dd10001cdfdf1308115d5bd7cfc))
* **workflows:** correct JSON output formatting in plugin discovery step ([#531](https://github.com/microsoft/hve-core/issues/531)) ([910fb8b](https://github.com/microsoft/hve-core/commit/910fb8b55cff89dd14eec07b99c3ffeff76f071c))

## [2.3.0](https://github.com/microsoft/hve-core/compare/hve-core-v2.2.0...hve-core-v2.3.0) (2026-02-13)


### ✨ Features

* **agents:** add GitHub backlog management pipeline ([#448](https://github.com/microsoft/hve-core/issues/448)) ([2b4d123](https://github.com/microsoft/hve-core/commit/2b4d1232f1fef5f2c858ccec23582bfed93db47f))
* **docs:** define inactivity closure policies for issues and PRs ([#452](https://github.com/microsoft/hve-core/issues/452)) ([5e710fd](https://github.com/microsoft/hve-core/commit/5e710fdb389632283bc50eb17c31b34d4d7535f1))
* **extension:** implement collection-based plugin distribution system ([#439](https://github.com/microsoft/hve-core/issues/439)) ([3156d98](https://github.com/microsoft/hve-core/commit/3156d989fcde1e181d04ebf56ab4ad29b0084d04))
* **instructions:** replace EVEN/ODD hardcoding with runtime milestone discovery protocol ([#486](https://github.com/microsoft/hve-core/issues/486)) ([ae95eb2](https://github.com/microsoft/hve-core/commit/ae95eb27ec37d53ad57ca81028a89e241ba891f9))
* **plugin:** support Copilot CLI plugin generation from collection manifests ([#496](https://github.com/microsoft/hve-core/issues/496)) ([e6cee85](https://github.com/microsoft/hve-core/commit/e6cee852f9118caa4ff8e778d8bf40e1d61bb69e))
* **scripts:** enhance on-create.sh to install actionlint and PowerShell modules ([#500](https://github.com/microsoft/hve-core/issues/500)) ([67585f5](https://github.com/microsoft/hve-core/commit/67585f5a7c29605c5d38424436c8b34e5258efcc))


### 🐛 Bug Fixes

* **docs:** replace broken relative link with inline code reference ([#465](https://github.com/microsoft/hve-core/issues/465)) ([8133b36](https://github.com/microsoft/hve-core/commit/8133b3634f37497ba8958c22127aa6e97de422d4))
* **instructions:** prevent local-only paths from leaking into GitHub issues ([#489](https://github.com/microsoft/hve-core/issues/489)) ([497d2fe](https://github.com/microsoft/hve-core/commit/497d2feb4333b25d272225f78ce489ab82fffc02))
* **workflows:** prevent release-please infinite loop on main branch ([#470](https://github.com/microsoft/hve-core/issues/470)) ([134bdd6](https://github.com/microsoft/hve-core/commit/134bdd6046ba8e954916b8ed4c7b6a03b593fa94))
* **workflows:** remove release-please skip guard that prevents tag creation ([#511](https://github.com/microsoft/hve-core/issues/511)) ([5e53271](https://github.com/microsoft/hve-core/commit/5e532716eb8b14bf6a1e5e381a746f4ce35cdf7d))


### 📚 Documentation

* **agents:** add GitHub Backlog Manager documentation and agent catalog ([#503](https://github.com/microsoft/hve-core/issues/503)) ([5e818ce](https://github.com/microsoft/hve-core/commit/5e818cefcfe1daf83fa2983d2fadf843e8406872))
* align CONTRIBUTING.md with docs/contributing/ guides ([#445](https://github.com/microsoft/hve-core/issues/445)) ([73ef6aa](https://github.com/microsoft/hve-core/commit/73ef6aa63b2e39a58d605edff87caba1fbc1cc46))


### ♻️ Refactoring

* **scripts:** refactor dev-tools and lib scripts to use CIHelpers module ([#482](https://github.com/microsoft/hve-core/issues/482)) ([fdf9145](https://github.com/microsoft/hve-core/commit/fdf9145175f80fe1e8d1674d358b0c255d0de8db))
* **scripts:** standardize PowerShell entry point guard pattern ([#477](https://github.com/microsoft/hve-core/issues/477)) ([6b84a8e](https://github.com/microsoft/hve-core/commit/6b84a8e49193d266411df9e4b8e8b1be2369eed2))


### 🔧 Maintenance

* **config:** standardize action mappings in artifact-retention.yml ([#487](https://github.com/microsoft/hve-core/issues/487)) ([7927db2](https://github.com/microsoft/hve-core/commit/7927db28105f384d1445e5f42eeb5ad6bd129542))
* **deps-dev:** bump cspell from 9.6.2 to 9.6.4 in the npm-dependencies group ([#461](https://github.com/microsoft/hve-core/issues/461)) ([c788095](https://github.com/microsoft/hve-core/commit/c7880959cb62f5cea343506b9bbe8dc5b39f78a6))
* **deps:** bump actions/setup-python from 5.1.1 to 6.2.0 in the github-actions group ([#462](https://github.com/microsoft/hve-core/issues/462)) ([69ef3c9](https://github.com/microsoft/hve-core/commit/69ef3c9217f1b4e0f8bc46c7f553e9ed6f62ed92))
* **security:** add SBOM artifact retention policy ([#479](https://github.com/microsoft/hve-core/issues/479)) ([8031557](https://github.com/microsoft/hve-core/commit/803155739be3fe56e4cc2a9d6ea921d1e0220321)), closes [#453](https://github.com/microsoft/hve-core/issues/453)

## [2.2.0](https://github.com/microsoft/hve-core/compare/hve-core-v2.1.0...hve-core-v2.2.0) (2026-02-06)


### ✨ Features

* add incident response prompt template ([#386](https://github.com/microsoft/hve-core/issues/386)) ([0adb35c](https://github.com/microsoft/hve-core/commit/0adb35ccc7e81b6d88ba3ff718c4f6a551230a05))
* add Skills and VS Code Extension categories to issue/PR templates ([#410](https://github.com/microsoft/hve-core/issues/410)) ([108e160](https://github.com/microsoft/hve-core/commit/108e160c4c34229e40c757b6820ddb669cb2e58d))
* **hve-core-guidance-instructions:** update guidance artifacts and MCP config ([#402](https://github.com/microsoft/hve-core/issues/402)) ([25b34de](https://github.com/microsoft/hve-core/commit/25b34de39c8d7efac15bcd945f7366b9b2c6cfe7))
* **security:** add action version consistency validation ([#423](https://github.com/microsoft/hve-core/issues/423)) ([f3bb787](https://github.com/microsoft/hve-core/commit/f3bb787bbf502177da5159d622890576f8399f5a))
* **workflows:** add copyright header validation CI workflow ([#429](https://github.com/microsoft/hve-core/issues/429)) ([c53de22](https://github.com/microsoft/hve-core/commit/c53de22371068ecf93097f06d59d95290c201df2))


### 🐛 Bug Fixes

* **docs:** add missing Copilot footers, consolidate validation exclusions ([#419](https://github.com/microsoft/hve-core/issues/419)) ([e40f960](https://github.com/microsoft/hve-core/commit/e40f960bf1c00dbc94f9a96d772f5a1aafbbdee4))
* **scripts:** include CIHelpers module + packaging script testability ([#420](https://github.com/microsoft/hve-core/issues/420)) ([da26edf](https://github.com/microsoft/hve-core/commit/da26edf36874f01728a2972d0fd94deb38efbf59))


### ♻️ Refactoring

* migrate inline CI code to CIHelpers module ([#393](https://github.com/microsoft/hve-core/issues/393)) ([adf6a5f](https://github.com/microsoft/hve-core/commit/adf6a5f6f080a9606dbff1a0bfa99522ca28ad39))


### 🔧 Maintenance

* **templates:** align issue templates with conventional commit format ([#427](https://github.com/microsoft/hve-core/issues/427)) ([2d28702](https://github.com/microsoft/hve-core/commit/2d287021ebb6adf02659ea882f251d103018e986))

## [2.1.0](https://github.com/microsoft/hve-core/compare/hve-core-v2.0.1...hve-core-v2.1.0) (2026-02-04)


### ✨ Features

* add PowerShell script to validate copyright headers ([#370](https://github.com/microsoft/hve-core/issues/370)) ([92fce72](https://github.com/microsoft/hve-core/commit/92fce72199394c769235330ee939b8ee85cb7a24))
* **docs:** Replace deprecated chat.modeFilesLocations with chat.agentFilesLocations ([#413](https://github.com/microsoft/hve-core/issues/413)) ([67fb2ab](https://github.com/microsoft/hve-core/commit/67fb2ab0ffa9bb673a32eca5269b0eafe0044b48))
* **scripts:** add CIHelpers module for CI platform abstraction ([#348](https://github.com/microsoft/hve-core/issues/348)) ([23e7a7e](https://github.com/microsoft/hve-core/commit/23e7a7e776da85abf2a8992df1121f940efa3119))
* **scripts:** add SecurityHelpers and CIHelpers modules ([#354](https://github.com/microsoft/hve-core/issues/354)) ([b93d990](https://github.com/microsoft/hve-core/commit/b93d9906a786c72ce45ec6b4b81e4f4e902664e8))
* **workflow:** add copilot-setup-steps.yml for Coding Agent environment ([#398](https://github.com/microsoft/hve-core/issues/398)) ([085a38b](https://github.com/microsoft/hve-core/commit/085a38b09a9df2908150ebcebba34db4873639a3))


### 🐛 Bug Fixes

* **build:** increase release-please search depths to prevent 250-commit window issue ([#342](https://github.com/microsoft/hve-core/issues/342)) ([4bb857d](https://github.com/microsoft/hve-core/commit/4bb857d1c94d0bdae252c9cdc3a5df8db87295d2))
* **build:** patch @isaacs/brace-expansion critical vulnerability ([#404](https://github.com/microsoft/hve-core/issues/404)) ([292ef51](https://github.com/microsoft/hve-core/commit/292ef513c4f529eb260b4b14b3a317ab75c38099))
* **ci:** disable errexit during spell check exit code capture ([#356](https://github.com/microsoft/hve-core/issues/356)) ([ed6ed46](https://github.com/microsoft/hve-core/commit/ed6ed4625807c431ca068ad845bb99ca00f7a37c))
* **ci:** exclude extension/README.md from frontmatter validation ([#362](https://github.com/microsoft/hve-core/issues/362)) ([e0d7378](https://github.com/microsoft/hve-core/commit/e0d7378ca353db56de4bd1322f6553a1dcb88a4b))
* exclude test fixtures from markdown link checker ([#345](https://github.com/microsoft/hve-core/issues/345)) ([58147f9](https://github.com/microsoft/hve-core/commit/58147f9cad987da1cae98dc5d4a403bd141ccec7))
* **extension:** resolve path resolution issues in Windows/WSL environments ([#407](https://github.com/microsoft/hve-core/issues/407)) ([8529725](https://github.com/microsoft/hve-core/commit/8529725c5b5e95219241ebf37246295a7d8a3efc))
* **linting:** use Write-Error instead of Write-Host for error output ([#377](https://github.com/microsoft/hve-core/issues/377)) ([2ca766b](https://github.com/microsoft/hve-core/commit/2ca766b00fbc077b8a05df3cd69b82fb33b45edf))
* **scripts:** apply CI output escaping to infrastructure scripts ([#369](https://github.com/microsoft/hve-core/issues/369)) ([251021e](https://github.com/microsoft/hve-core/commit/251021ec2b16fc350c0c33ddff5c1e09cfd57943))
* **scripts:** apply CI output escaping to linting scripts ([#367](https://github.com/microsoft/hve-core/issues/367)) ([fdd75ed](https://github.com/microsoft/hve-core/commit/fdd75ed73b967db331730bb52eb7bdd3488cf649))
* **scripts:** apply CI output escaping to security scripts ([#368](https://github.com/microsoft/hve-core/issues/368)) ([1237c9a](https://github.com/microsoft/hve-core/commit/1237c9a90beaeb6dcbdfb8af6543c414367d9b81))
* **scripts:** ensure reliable array count operations in linting and security scripts ([#395](https://github.com/microsoft/hve-core/issues/395)) ([de43e73](https://github.com/microsoft/hve-core/commit/de43e73edc00742c03ff59997becc68986c5a5a8))
* **scripts:** standardize PowerShell requirements header block ([#385](https://github.com/microsoft/hve-core/issues/385)) ([6e26282](https://github.com/microsoft/hve-core/commit/6e262826199bf0ea0895b5940439aec8dbb5a8f0))


### 📚 Documentation

* add doc-ops agent to CUSTOM-AGENTS reference ([#358](https://github.com/microsoft/hve-core/issues/358)) ([15f7185](https://github.com/microsoft/hve-core/commit/15f7185221f472391cc2216ea5860190eea57b08))
* add memory agent to CUSTOM-AGENTS.md ([#359](https://github.com/microsoft/hve-core/issues/359)) ([d92c4e1](https://github.com/microsoft/hve-core/commit/d92c4e188ad510636a9476d86dd772e6b271fc87))
* add missing agents to extension README ([#357](https://github.com/microsoft/hve-core/issues/357)) ([d58541c](https://github.com/microsoft/hve-core/commit/d58541c3c5d55a9c44e76d939e19221e1c7db3b0))
* add task-reviewer agent to CUSTOM-AGENTS.md ([#363](https://github.com/microsoft/hve-core/issues/363)) ([0efb722](https://github.com/microsoft/hve-core/commit/0efb72211a3d7c8b2fe49193044187bb84f1229e))
* **contributing:** add copyright header guidelines ([#382](https://github.com/microsoft/hve-core/issues/382)) ([881a567](https://github.com/microsoft/hve-core/commit/881a5671c97dee769450b27f17f7b760e5a28e32))
* **scripts:** update README.md with missing directory sections ([#355](https://github.com/microsoft/hve-core/issues/355)) ([ac2966f](https://github.com/microsoft/hve-core/commit/ac2966f1cc300861a05ffbecf3722dd0bff3965e))


### ♻️ Refactoring

* **scripts:** align linting and tests with CIHelpers ([#401](https://github.com/microsoft/hve-core/issues/401)) ([3587e6a](https://github.com/microsoft/hve-core/commit/3587e6aba4440e2e5135a9907a05c88ac966470c))
* **scripts:** extract Invoke-PackageExtension for testability ([#343](https://github.com/microsoft/hve-core/issues/343)) ([858a1be](https://github.com/microsoft/hve-core/commit/858a1be85343088cad170409d9e1afcac3f8c9b2))
* **scripts:** extract orchestration function for Prepare-Extension testability ([#344](https://github.com/microsoft/hve-core/issues/344)) ([9fd4bd1](https://github.com/microsoft/hve-core/commit/9fd4bd1e95c737af01103c9b9dc99523bacf0c4d))
* **scripts:** replace raw GITHUB_OUTPUT with Set-CIOutput in Package-Extension ([#391](https://github.com/microsoft/hve-core/issues/391)) ([74a30bb](https://github.com/microsoft/hve-core/commit/74a30bb2dc136b84bd5294d17f0b1fc886db01d0))
* **security:** move DependencyViolation and ComplianceReport to shared module ([#378](https://github.com/microsoft/hve-core/issues/378)) ([1dd31ad](https://github.com/microsoft/hve-core/commit/1dd31adc6d9c17b8f3352b02ccee9aed4aa17d2e))


### 🔧 Maintenance

* add copyright headers to PowerShell scripts ([#381](https://github.com/microsoft/hve-core/issues/381)) ([d19c9b3](https://github.com/microsoft/hve-core/commit/d19c9b3ad931a3884f33a56b881b0c459589eae2))
* add copyright headers to shell scripts ([#380](https://github.com/microsoft/hve-core/issues/380)) ([284b456](https://github.com/microsoft/hve-core/commit/284b456d5299787023b2e8d5d0a74a6d823b9585))
* **deps-dev:** bump cspell from 9.6.1 to 9.6.2 in the npm-dependencies group ([#387](https://github.com/microsoft/hve-core/issues/387)) ([23c2b9f](https://github.com/microsoft/hve-core/commit/23c2b9f06bd03f0b675f37fa0485675f9f9e3162))
* **workflows:** simplify Copilot setup steps workflow triggers ([#414](https://github.com/microsoft/hve-core/issues/414)) ([492a7b1](https://github.com/microsoft/hve-core/commit/492a7b103274b2f0426aa6de1a2f5983fceb94dc))

## [2.0.1](https://github.com/microsoft/hve-core/compare/hve-core-v2.0.0...hve-core-v2.0.1) (2026-01-28)


### 🐛 Bug Fixes

* **build:** use draft releases for VSIX upload ([#338](https://github.com/microsoft/hve-core/issues/338)) ([f1d3ac6](https://github.com/microsoft/hve-core/commit/f1d3ac657e386c9d62b01cbab9322a5e331ab864))
* **docs:** quote YAML frontmatter values in BRD template ([#339](https://github.com/microsoft/hve-core/issues/339)) ([ca988f2](https://github.com/microsoft/hve-core/commit/ca988f2221eff8312b6188e73cca807742d08742))

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
