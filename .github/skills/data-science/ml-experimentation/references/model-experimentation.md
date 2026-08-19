---
title: Model experimentation conventions
description: CSE model-experimentation practice areas covering virtual environments, source and folder structure, experiment tracking, dataset and model abstractions, and model evaluation
---

## Source

Microsoft CSE Code-with-Engineering-Playbook, [Model Experimentation](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/model-experimentation/), documentation licensed CC BY 4.0. Content below is derived from that page and has been changed: it follows the five practice areas in upstream order, paraphrases the goals, the guidance, and the expected outcomes, and condenses the challenges narrative and the abstraction discussion. The notice recorded in `THIRD-PARTY-NOTICES` carries the attribution CC BY 4.0 requires. Tool and file names are preserved as identifiers.

## Why a semi-structured process

Model experimentation carries uncertainty about both expected results and future operationalization. The upstream response is a semi-structured process that balances engineering and research practice against rapid model and data exploration.

Five stated goals:

| Goal               | What it means                                                             |
|--------------------|---------------------------------------------------------------------------|
| Performance        | Arrive at the solution that performs best.                                |
| Operationalization | Keep production in view so the result stays feasible to operate.          |
| Code quality       | Hold code and artifacts to a consistent standard.                         |
| Reproducibility    | Sustain research momentum by making experiments trackable and repeatable. |
| Collaboration      | Encourage the team to work together on shared problems.                   |

The corresponding challenges are worth naming, because they explain the conventions: trial-and-error work resists planning and estimation; teams want to move fast and keep early attempts rough; brainstorming together needs an agreed process; research code that never ships still has to be maintainable; and changing approach can reshape operationalization considerably, for example GPU versus CPU, batch versus online, parallel versus sequential, and the runtime environment.

## The five practice areas

### Virtual environments

In languages like Python and R, always work inside a virtual environment. Doing so keeps results repeatable, keeps team members aligned, eases the path to a product, and keeps local development behaving like the compute the code will run on. Committed configuration files let anyone rebuild the same environment from source.

Which framework fits depends on how complicated the development environment is and how much friction the tool adds. Upstream names three options: `venv`, which ships with Python and is the simplest to pick up but does nothing about dependencies; `Conda`, a widely used manager for packages, dependencies, and environments that spans several stacks, holds several versions of one environment side by side, and draws on its own package repository; and `Poetry`, which resolves dependencies through `pyproject.toml` and lock files and pays off in robust, reproducible environments where dependency conflicts are frequent.

**HVE Core substitution.** This repository uses `uv`. That is a repository convention, not an upstream recommendation. When advising a team that is still choosing, preserve upstream's selection rationale rather than presenting `uv` as the playbook answer.

Expected outcomes:

1. Documentation covering how to create the selected virtual environment and how to install its dependencies.
2. Environment configuration files committed where applicable, such as `requirements.txt`, `environment.yml`, or `pyproject.toml`.

Stated benefits: productization, collaboration, reproducibility.

### Source control and folder or package structure

An applied ML repository accumulates source code, notebooks, devops scripts, documentation, scientific references, datasets, and more. Settle on a folder layout so those resources stay tidy and findable. Either define a generic structure with folders such as `data`, `src`, `docs`, and `notebooks`, or take up an established one such as CookieCutter Data Science.

Put the work under source control so the team gains shared history, versioning, code review, traceability, and a backup. Data-science teams place code there as a matter of course; whether other artifacts such as data and scientific literature are stored and versioned the same way is decided per scenario.

Expected outcomes:

* One agreed folder structure, pushed to the repository so every contributor works from it.
* A `.gitignore` file drawing the line between what syncs with git and what stays local.
* A stated decision on how notebooks are stored and versioned. Upstream points to `nbstripout` for removing output from Jupyter notebooks.

Stated benefits: collaboration, reproducibility, code quality.

### Experiment tracking

Experiment tracking tools give data scientists and researchers a record of what has already been run, which both explains how the experimentation unfolded and makes an experiment or a model repeatable.

Frameworks vary in the metadata they capture and in how well they support comparison and analysis. Upstream notes that some have to be deployed while others are consumed as SaaS, and names MLflow on Databricks and Azure ML Experimentation as commonly used in ISE.

Expected outcomes:

1. Choose the experiment tracking framework.
2. Confirm everyone on the team can reach it.
3. Write down how it is set up on local environments.
4. Pin down datasets and evaluation so that every experiment can be compared. **Comparison rests on that consistency across datasets and evaluation.**
5. Record everything a rerun needs: **dataset names and versions**, parameters, code, and environment. Tracking a dataset name alone is a labelling practice, not reproducibility.

Stated benefits: model performance, reproducibility, collaboration, code quality.

### Datasets and models abstractions

Wrapping building blocks such as datasets, models, and evaluators behind abstractions lets new logic drop into the experimentation pipeline without disturbing the flow the team agreed on. Object-oriented abstract classes are one mechanism for expressing them; upstream points to scikit-learn's guidance on creating API-compatible estimators and PyTorch's guidance on extending the abstract dataset class.

Expected outcomes:

1. Each building block exposes a defined API so it can be replaced or extended.
2. Replacing a building block leaves the original experimentation flow working.
3. Mock building blocks stand in during unit tests.
4. Those APIs and mocks are handed to the engineering teams so other modules can integrate against them.

Stated benefits: collaboration, code quality, reproducibility, operationalization, model performance.

### Model evaluation

When deciding on evaluation of the model or process, upstream supplies a checklist:

* Every stakeholder has signed off on the evaluation logic.
* How that logic ties back to business KPIs has been worked through and settled.
* The evaluation flow suits the models in hand and the ones still to come, so it presumes no particular prediction structure or method-specific process.
* Evaluation code carries unit tests and has been reviewed across the team.
* The evaluation flow leaves room for deeper results analysis and error analysis.

Evaluation development outcomes:

1. Stakeholders agree on the evaluation strategy.
2. The exploration of candidate evaluation methods and metrics, and the discussion around them, is documented.
3. The code carrying evaluation logic and its data structures is reviewed and tested.
4. The documentation on how to apply evaluation is reviewed.
5. Performance metrics reach the experiment tracker without manual steps.

Stated benefits: model performance, code quality, collaboration, reproducibility.

## Related guidance

The model-evaluation points overlap closely with the Evaluation and Metrics section of the ML Fundamentals Checklist. Cite one and cross-reference rather than restating both. See [ml-checklists.md](ml-checklists.md).

Unit-testing evaluation code is a testing concern; technique and mocking boundaries live in the `ds-dataops` skill.
