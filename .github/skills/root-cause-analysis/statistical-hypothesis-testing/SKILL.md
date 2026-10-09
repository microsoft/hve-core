---
name: statistical-hypothesis-testing
description: 'Compare binary rates or average values across affected and unaffected cohorts during root cause analysis.'
compatibility: "Requires an Agent Skills host and a statistical runtime supporting Barnard's exact test and Welch's independent-samples t-test."
---

# Statistical Hypothesis Testing

## Goal

Test whether binary evidence rates or average observation values differ between affected and
unaffected cohorts during a root cause investigation.

## Inputs

* One independent row per observational unit, such as a server, resource, tenant, process run,
  transaction, batch, location, participant, or incident instance
* Binary cohort status: affected or unaffected, defined by a pre-established incident-impact
  criterion that is independent of the candidate observation being tested
* One consistently defined observation: binary presence or absence, or a finite numeric value
* Source, query, UTC window, scope, exclusions, and sampling limitations

Identify person- or customer-level units with a pseudonymous key. Keep the key-to-identity mapping
outside the statistical input and investigation record. Record only group counts and summary
statistics in E-nnn when row-level values are not required for reproducibility.

Define cohort membership and the observation rule before inspecting candidate observation values.
Do not continue if instances are duplicated, dependent, selected after inspecting the candidate
observation, classified inconsistently between cohorts, or assigned to a cohort using the
candidate observation. Record the test as `Blocked` until corrected. Choose the test from the
observation type before inspecting the result.

## Execution Contract

Statistics exist only as artifacts returned by an approved code-execution or statistics tool that
the host actually provides. Before execution, record the runtime and library versions, exact code
or tool invocation, input-table locator, SHA-256 content hash of the exact per-unit input table,
and intended raw-output locator in T-nnn. After execution, retain the raw tool output at that
locator.

If no approved statistical runtime is available, record T-nnn as `Blocked` with
`statistical runtime unavailable`. Return no statistic, confidence interval, degrees of freedom,
or p-value. Never compute, approximate, estimate, recall, or reconstruct those values through model
reasoning, mental arithmetic, lookup tables, or prose. Never install or upgrade a package during
an investigation to create or change the statistical runtime.

A statistic without the complete execution record above does not exist for this workflow. Mark the
test `Blocked`, exclude it from pair selection and summaries, and do not restate any number that
the recorded tool output does not contain.

## Binary Rate Test

Let $n_0$ be unaffected instances, $c_0$ be unaffected instances with evidence, $n_1$ be affected
instances, and $c_1$ be affected instances with evidence.

Model the groups as two independent binomial samples:

$$
X_1 \sim \operatorname{Binomial}(n_1,p_1)
\qquad\text{and}\qquad
X_0 \sim \operatorname{Binomial}(n_0,p_0)
$$

Test $H_0: p_1 = p_0$ against $H_A: p_1 \ne p_0$ with Barnard's exact test, an unconditional
two-sample binomial test for the $2 \times 2$ table:

|                   | Evidence present | Evidence absent |
|-------------------|-----------------:|----------------:|
| Affected cohort   |            $c_1$ |       $n_1-c_1$ |
| Unaffected cohort |            $c_0$ |       $n_0-c_0$ |

Before execution, record the Barnard candidate-table lattice size
$(n_1+1)(n_0+1)$ in T-nnn. Use a default lattice budget of 1,000,000 candidate tables unless the
host declares a lower resource limit before inspecting the observation values. When the lattice
does not exceed the recorded budget, use the approved statistical runtime, such as
`scipy.stats.barnard_exact([[c1, n1 - c1], [c0, n0 - c0]], alternative="two-sided")`, and report
the returned score statistic and p-value.

When the lattice exceeds the recorded budget, calculate the pooled null estimate
$\hat p=(c_1+c_0)/(n_1+n_0)$. Use the asymptotic pooled two-sample score test only when
$n_1>30$, $n_0>30$, and all four null-expected cell counts
$n_1\hat p$, $n_1(1-\hat p)$, $n_0\hat p$, and $n_0(1-\hat p)$ are at least 10. Use the approved
runtime to calculate:

$$
z =
\frac{c_1/n_1-c_0/n_0}
{\sqrt{\hat p(1-\hat p)(1/n_1+1/n_0)}}
$$

and the two-sided p-value $2\Phi(-|z|)$. Label the result
`Asymptotic pooled two-sample score test`; do not describe it as exact.

When the lattice exceeds the budget and the normal criteria fail, an approved runtime may use
tail-bounded unconditional summation only when it evaluates the full nuisance-parameter interval
and returns a certified absolute error bound covering omitted probability mass and numerical
optimization. Record the algorithm, tolerance, returned p-value interval, and error bound. Treat
the significance decision as `Blocked` when that interval crosses the declared significance
threshold. If the runtime cannot provide this controlled computation, record the test as
`Blocked`; do not improvise a truncated sum.

Do not substitute Fisher's exact test, a one-sample binomial test, or a normal approximation
outside the fallback rule above.

If either group is empty, record the test as `Blocked`. Report small group sizes, sparse cells,
and rates of 0 or 1 prominently because they limit precision even when the exact test executes.

## Average Value Test

For a finite numeric observation whose average has operational meaning, let the affected cohort
have values $x_1,\ldots,x_{n_1}$ and the unaffected cohort have values $y_1,\ldots,y_{n_0}$.
Define the hypotheses before execution:

$$
H_0: \mu_1 = \mu_0
\qquad\text{and}\qquad
H_A: \mu_1 \ne \mu_0
$$

Use Welch's two-sided independent-samples t-test, which does not assume equal variances:

```python
result = scipy.stats.ttest_ind(
    affected,
    unaffected,
    equal_var=False,
    alternative="two-sided",
)
interval = result.confidence_interval(confidence_level=0.95)
```

Report both group means, standard deviations, sample sizes, the mean difference
$\bar{x}-\bar{y}$, its 95% Welch confidence interval from `interval.low` to `interval.high`, the
test statistic from `result.statistic`, degrees of freedom from `result.df`, and p-value from
`result.pvalue`. The confidence interval is for the affected-cohort mean minus the
unaffected-cohort mean.

If the approved runtime's result object does not provide `confidence_interval`, record the test as
`Blocked`. Do not reconstruct or approximate the interval through model reasoning or substitute a
different confidence-interval method.

Do not use this test for paired, repeated, censored, infinite, or non-independent observations.
Record it as `Blocked` until the dependence or data-quality problem is resolved. Inspect group
distributions for severe skew and influential outliers. If either group is too small to estimate
variance, or those features make a mean-based model unreliable, report the limitation and do not
claim the test distinguishes the hypothesis.

Before querying any source, verify the subject, schema, time semantics, observation window,
independent-unit key, source lineage, units, sampling, filtering, and collection coverage.
Aggregate to one observation per independent unit before testing.

In Azure SRE mode, sources can include Azure Monitor, Log Analytics, Application Insights, and
Azure Data Explorer. Use the Azure resource, table, event-time field, UTC window, instance key,
sampling, and ingestion checks as authoritative source requirements for those observations.

## Interpretation

For binary evidence, report $c_1/n_1$, $c_0/n_0$, their difference, the selected binary-test
method, its statistic and p-value or certified p-value interval, and both sample sizes. For numeric
evidence, report the average-value results specified above. A p-value is the probability, under
$H_0$, of an outcome at least as incompatible with the null model as the observation. It is not
the probability that the RCA hypothesis is true, an effect-size measure, or causal proof.

Do not convert the result directly into `Supported` or `Disproved`. Return it to
`root-cause-analysis` as one discriminating test alongside mechanism evidence, contradictions,
controls, and coverage limitations. If multiple evidence signals are tested, disclose the number
and avoid selecting only the smallest p-value.

## RCA Record

Return:

* `Test T-nnn`: hypothesis ID; affected and unaffected cohort definitions and incident-impact
  criterion; observation rule and units; executed query, command, comparison, or collection
  procedure and parameters; applicable absolute window; selected test and parameters; execution
  status; runtime and library versions; exact executed code or tool invocation; input-table
  locator and SHA-256 content hash; raw tool output locator; Barnard lattice size and budget when
  applicable; normal-fallback expected cell counts or controlled-summation algorithm, tolerance,
  and error bound when applicable; limitations
* `Evidence E-nnn`: source and locator; binary counts and rates, or numeric sample sizes, means,
  standard deviations, mean difference, and confidence interval; test statistic and p-value or
  certified p-value interval; collection time; aggregate-only handling for person- or
  customer-level units; coverage, lineage, transformation, and redaction notes
* Conclusion: inconsistent or not demonstrably inconsistent with the unaffected-cohort baseline,
  without claiming causality
