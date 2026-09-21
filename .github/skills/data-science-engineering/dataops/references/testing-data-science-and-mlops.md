---
title: Testing data science and MLOps code
description: The five testable operation categories, their concrete pytest technique, and where mocking stops in each
---

## Source

Microsoft CSE Code-with-Engineering-Playbook, [Testing Data Science and MLOps Code](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/testing-data-science-and-mlops-code/), documentation licensed CC BY 4.0. Content below is derived from that page and has been changed. Category names and pytest API names are preserved as identifiers; the category descriptions, the mocking boundaries, and the unit-test scope guard are paraphrased. `THIRD-PARTY-NOTICES` carries the attribution CC BY 4.0 requires. Upstream code examples are described rather than copied.

## Approach

Nothing about MLOps or data-science code changes the principles that govern testing anywhere else. Some situations only look harder to cover, so open with a test design session that works through inputs, outputs, exceptions, and how each data transformation is expected to behave. Deciding on the tests up front pushes the code toward a modular shape where a function does one thing and anything shared is pulled out.

Upstream enumerates five common operations:

* Saving and loading data
* Transforming data
* Model load or predict
* Data validation
* Model testing

## Category, technique, and mocking boundary

| Category                                | What is under test                                                              | Technique                                                                                 | Where mocking stops                                                                                                                                                                                                                                                                                             |
|-----------------------------------------|---------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Saving and loading data                 | The function's own branching and parameter passing, not the third-party library | Patch the module-scoped references and assert call arguments and call counts              | **Mock the I/O boundary.** Replace `isfile` and `read_csv` where the module under test refers to them. Only the names that module calls are replaced; the rest run for real.                                                                                                                                    |
| Saving and loading data, shared samples | Reuse of one sample across several tests                                        | `pytest.fixture` returning the sample, passed as a test parameter                         | Nothing else is stubbed. Keep the sample inline and no bigger than the assertions need.                                                                                                                                                                                                                         |
| Transforming data                       | Fixed input to fixed output, one verification per test                          | Separate tests per property; `pytest.mark.parametrize` for input matrices                 | **Nothing is mocked.** The transformation runs for real, which is precisely why it has to sit apart from data access. When a function does both, advise splitting it before any transformation test is written. Checking a reshape through a mocked `read_csv` tests neither category and undoes the invariant. |
| Model load or predict                   | Code paths around model load and prediction                                     | Mock load and predict; `pytest.mark.longrunning` to segregate smoke and integration tests | **Treat the model as a boundary** and stub it as file access is stubbed. A real load sits behind the mark, off the fast loop.                                                                                                                                                                                   |
| Data validation                         | Pipeline robustness against bad input                                           | Test cases for no data supplied, unexpected format, null values, and outliers             | No boundary stated. Inputs are built, not stubbed.                                                                                                                                                                                                                                                              |
| Model testing                           | Model robustness and subgroup behavior                                          | Adversarial and boundary tests; verify accuracy for under-represented classes             | Sits outside unit testing entirely, while the model is trained, debugged, and validated.                                                                                                                                                                                                                        |

## Saving and loading data

The third-party functions do not need your tests; `read_csv` and `isfile` are the responsibility of the pandas and os maintainers. Cover only what the wrapper itself decides: that it reads the file when it is present and uses the right index column, that it skips the read when the file is missing, and that it hands back what callers expect.

Leaning on real sample files is how a test passes on a laptop and fails on a build agent. Stubbing `isfile` and `read_csv` cuts that dependency, so the repository carries no fixture files and the test behaves the same wherever it runs.

## Transforming data

For cleaning and reshaping work, pin a known input to a known output and let each test check one thing. Shape of the result belongs in one test and padding behavior in another. `pytest.mark.parametrize` then feeds the pairs of input and expected output through the same test automatically.

## Model load or predict

In a unit test, stub the model load and the predictions exactly as file access is stubbed. Pulling in a real model for a smoke or integration test is legitimate but slow, so those tests have to be separable from the fast loop. Upstream separates them with the `pytest.mark.longrunning` mark and runs the fast loop as `pytest -v -m "not longrunning"`.

## Scope guard: ML unit tests check code quality

**Unit tests around an ML model are not there to judge its accuracy or its performance.** They inspect the quality of the code. Two questions do the diagnosing:

* Does the model take inputs of the expected shape and return outputs of the expected shape?
* Do the model weights actually change once `fit` has run?

For that reason these tests knowingly bend strict unit-testing practice: **some external calls are left unstubbed.** Upstream calls the result closer to a narrow integration test and accepts the trade. The payoff it claims is catching a badly configured model before it burns hours in training only to perform poorly. Drop the unstubbed-call clause and the guidance reads as an oversight rather than a considered choice.

Upstream gives three implementation examples for deep-learning models:

* Construct the model, then check the input layer against the shape of example source data and the output layer against the shape the output should take.
* Capture the weights of every layer, run one training epoch over a dummy dataset, and assert only that those values moved.
* Train for one epoch on a dummy dataset and validate against dummy data, asserting only that the prediction comes back in the right format. Accuracy is not the point and will not be there.

## Data validation

Fold data-validation cases into the unit tests: no data supplied, data not in the expected format, data containing null values, and outliers. Together they show the data-processing pipeline holds up.

## Model testing

Past unit testing, a model can be exercised, debugged, and validated while it trains. Upstream names two options: adversarial and boundary tests that harden the model, and accuracy checks on under-represented classes.

## Relationship to the DataOps invariants

These five categories are how a team satisfies an invariant the DataOps guidance already asserts: transformation code must be separable from data-access code so unit tests can target transformation logic. See [data-tiers-and-pipeline-invariants.md](data-tiers-and-pipeline-invariants.md).
