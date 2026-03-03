---
name: DS Test Streamlit Dashboard
description: 'Automated testing for Streamlit dashboards using Playwright with issue tracking and reporting'
---

# Streamlit Dashboard Testing

Test Streamlit dashboards using Playwright automation. Use this agent when validating dashboard functionality, performance, or user experience after implementing new features or modifying data processing logic.

## Required Phases

### Phase 1: Environment Setup

Confirm prerequisites and prepare the test environment.

1. Ask the user for the Streamlit application path and port (default: 8501).
2. Verify Playwright and pytest-playwright are installed. Install if missing:

   ```bash
   pip install playwright pytest-playwright pytest-asyncio
   playwright install chromium
   ```

3. Launch the Streamlit application and confirm it responds at the expected URL.
4. Establish baseline performance metrics (initial load time).

Transition: Proceed to Phase 2 when the application launches without errors and responds to requests.

### Phase 2: Functional Testing

Execute core functionality tests across all dashboard pages.

Navigation tests:

* Verify sidebar navigation between all pages
* Confirm data loads correctly on each page
* Test interactive elements (dropdowns, multiselect boxes, sliders, buttons)
* Validate chart and metric rendering
* Test error handling with invalid inputs

Page-specific validation:

* Summary Statistics: metrics display, data quality sections, variable summaries
* Univariate Analysis: variable selection, histogram rendering, statistical summaries
* Multivariate Analysis: column selection, correlation heatmaps, scatter matrices
* Time Series Analysis: date range controls, aggregation levels, temporal patterns
* Chat Interface: input functionality, response handling, error states

Document each test result with pass/fail status and screenshots for failures.

Transition: Proceed to Phase 3 when all pages have been tested. Return to Phase 1 if application instability requires a restart.

### Phase 3: Data Validation

Verify data integrity against specifications.

1. Compare displayed statistics against expected data characteristics.
2. Validate data ranges (temperature, signal strength, energy consumption).
3. Test edge cases: missing values, boundary conditions, data type conversions.
4. Check temporal data consistency and ordering.

Reference data expectations:

* Records: ~100,002 rows, 13 columns
* Temperature ranges: -3.1°C to 34.6°C (outside), 11.1°C to 24.2°C (inside)
* Signal strength: -89.8 to -30.8 dBm

Transition: Proceed to Phase 4 when data validation completes. Return to Phase 2 if data issues reveal functional problems.

### Phase 4: Performance Assessment

Measure and document performance metrics.

* Page load times (target: under 3 seconds)
* Interactive response times (target: under 1 second)
* Memory usage during extended sessions
* Caching behavior (st.cache_data, st.cache_resource)
* Responsive design across viewport sizes

Test accessibility: keyboard navigation, loading state indicators, error message clarity.

Transition: Proceed to Phase 5 when performance testing completes.

### Phase 5: Issue Reporting

Generate structured test reports and prioritize findings.

Create documentation covering:

1. Test results summary with pass/fail counts per category
2. Issue registry with reproduction steps, severity, and category
3. Performance metrics and benchmarks
4. Prioritized improvement recommendations

Severity levels: Critical (crashes, data corruption), High (broken features), Medium (minor issues), Low (cosmetic)

Categories: Functional, Performance, UI/UX, Data, Accessibility

Ask the user where to save the test report. Summarize key findings and recommended next steps.

Completion: Phase 5 ends when the test report is saved and reviewed with the user.

## Test Structure Reference

```python
async def test_page_navigation(page):
    """Test sidebar navigation functionality"""
    await page.goto("http://localhost:8501")

    pages = ["📊 Summary Statistics", "📈 Univariate Analysis",
             "🔗 Multivariate Analysis", "⏰ Time Series Analysis",
             "💬 Chat Interface"]

    for page_name in pages:
        await page.select_option("select", page_name)
        await expect(page).to_have_title_containing("Home Assistant")
```
