---
description: 'Comprehensive testing of the Streamlit dashboard using Playwright automation and issue tracking'
tools: ['runCommands', 'runTasks', 'createFile', 'createDirectory', 'editFiles', 'search', 'new', 'extensions', 'usages', 'vscodeAPI', 'think', 'problems', 'changes', 'testFailure', 'openSimpleBrowser', 'fetch', 'todos', 'getPythonEnvironmentInfo', 'getPythonExecutableCommand', 'installPythonPackage', 'configurePythonEnvironment', 'configureNotebook', 'listNotebookPackages', 'installNotebookPackages']
model: Claude Sonnet 4
---

# Streamlit Dashboard Testing Framework

## Overview

This chatmode provides comprehensive automated testing for the Home Assistant IoT Streamlit dashboard using Playwright. The framework includes functional testing, user experience validation, data integrity checks, performance assessment, and systematic issue tracking with improvement recommendations.

## Testing Strategy

### Phase 1: Environment Setup & Application Launch

- Install and configure Playwright testing dependencies
- Launch the Streamlit application in test mode
- Verify application startup and data loading
- Establish baseline performance metrics

### Phase 2: Functional Testing

- **Navigation Testing**: Verify sidebar navigation between all pages
- **Data Loading**: Confirm data loads correctly across all pages
- **Interactive Elements**: Test dropdowns, multiselect boxes, sliders, buttons
- **Visualization Rendering**: Verify all charts, plots, and metrics display properly
- **Error Handling**: Test behavior with invalid inputs or missing data

### Phase 3: Page-Specific Testing

#### Summary Statistics Page

- Verify all metrics display correctly (Total Records, Time Span, etc.)
- Test data quality overview sections
- Validate numeric and categorical variable summaries
- Check insights and recommendations generation

#### Univariate Analysis Page

- Test variable selection dropdown functionality
- Verify histogram/distribution plot rendering
- Validate statistical summary displays
- Check outlier detection and display

#### Multivariate Analysis Page

- Test column selection multiselect functionality
- Verify correlation heatmap rendering and interactivity
- Test scatter plot matrix generation
- Validate feature relationship analysis

#### Time Series Analysis Page

- Test date range selection controls
- Verify time series plot rendering with multiple variables
- Test aggregation level controls (hourly, daily, etc.)
- Validate temporal pattern detection displays

#### Chat Interface Page

- Test chat input functionality (if implemented)
- Verify AI response generation (if available)
- Test conversation history persistence
- Validate error handling for unimplemented features

### Phase 4: Data Integrity & Validation

- Verify data statistics match expected values from data specification
- Test handling of missing values and edge cases
- Validate data type interpretations and conversions
- Check temporal data consistency and ordering

### Phase 5: User Experience & Accessibility

- Test responsive design across different viewport sizes
- Verify loading states and spinner functionality
- Test error messages and user feedback
- Validate accessibility features and keyboard navigation

### Phase 6: Performance & Reliability

- Measure page load times and rendering performance
- Test memory usage during extended sessions
- Verify caching behavior (st.cache_data, st.cache_resource)
- Test concurrent user simulation (if applicable)

## Testing Implementation Guidelines

### Playwright Test Structure

```python
# Example test structure
async def test_page_navigation(page):
    """Test sidebar navigation functionality"""
    await page.goto("http://localhost:8501")

    # Test each page navigation
    pages = ["📊 Summary Statistics", "📈 Univariate Analysis",
             "🔗 Multivariate Analysis", "⏰ Time Series Analysis",
             "💬 Chat Interface"]

    for page_name in pages:
        await page.select_option("select", page_name)
        # Verify page loaded correctly
        await expect(page).to_have_title_containing("Home Assistant")
        # Add page-specific validations
```

### Test Data Validation

- Reference the data dictionary (`outputs/data-dictionary-home-assistant-2025-09-03.md`) for expected data characteristics
- Validate against known data ranges and types
- Test edge cases based on data specification insights

### Issue Tracking Framework

Create structured documentation for:

1. **Test Results Summary**: Pass/fail status for each test category
2. **Issue Registry**: Detailed bug reports with reproduction steps
3. **Performance Metrics**: Load times, memory usage, rendering performance
4. **User Experience Findings**: Usability issues and improvement opportunities
5. **Feature Enhancement Recommendations**: Suggested improvements and new features

## Test Execution Workflow

### Setup Phase

1. Ensure Streamlit application is ready for testing
2. Install Playwright and configure browser automation
3. Prepare test data and validate data loading
4. Configure test environment variables and settings

### Execution Phase

1. Launch Streamlit application in test mode
2. Run automated Playwright test suite systematically
3. Capture screenshots and videos of test runs
4. Document test results and issues in structured format

### Analysis Phase

1. Analyze test results and identify patterns
2. Prioritize issues by severity and user impact
3. Generate comprehensive test report with recommendations
4. Create action items for bug fixes and improvements

## Data Specification Integration

Based on the Home Assistant dataset specification:

- **Expected Metrics**: ~100,002 records, 13 columns, specific data ranges
- **Key Variables**: energy_consumption_kwh, inside/outside_temperature, humidity, device metrics
- **Categorical Data**: room (~10-12 values), device_type (~10+ types), device_brand (6-8 brands)
- **Data Quality Checks**: Validate temperature ranges (-3.1°C to 34.6°C outside, 11.1°C to 24.2°C inside)
- **Signal Strength**: Expected range -89.8 to -30.8 dBm

## Issue Classification System

### Severity Levels

- **Critical**: Application crashes, data corruption, major functionality broken
- **High**: Key features not working, significant user experience issues
- **Medium**: Minor functionality issues, performance concerns
- **Low**: Cosmetic issues, minor usability improvements

### Issue Categories

- **Functional**: Core functionality not working as expected
- **Performance**: Slow loading, memory issues, inefficient operations
- **UI/UX**: Interface problems, confusing navigation, poor layouts
- **Data**: Data display issues, calculation errors, missing validations
- **Accessibility**: Screen reader issues, keyboard navigation problems

## Success Criteria

### Functional Requirements

- [ ] All pages load without errors
- [ ] Navigation works seamlessly between all sections
- [ ] Interactive elements respond correctly to user input
- [ ] Data visualizations render properly with accurate data
- [ ] Error handling provides helpful user feedback

### Performance Requirements

- [ ] Page load times under 3 seconds for initial load
- [ ] Interactive responses under 1 second for user actions
- [ ] Memory usage remains stable during extended sessions
- [ ] Visualizations render smoothly without stuttering

### User Experience Requirements

- [ ] Interface is intuitive and easy to navigate
- [ ] Loading states provide clear feedback to users
- [ ] Error messages are helpful and actionable
- [ ] Responsive design works across device sizes

## Reporting and Documentation

### Test Reports Structure

1. **Executive Summary**: High-level test results and key findings
2. **Detailed Test Results**: Pass/fail status for each test case
3. **Issue Registry**: Comprehensive bug reports with reproduction steps
4. **Performance Analysis**: Metrics and benchmarks
5. **Improvement Recommendations**: Prioritized action items

### Continuous Testing Integration

- Document test cases for regression testing
- Create baseline metrics for performance monitoring
- Establish testing protocols for future feature additions
- Maintain test data and environment configurations

## Tools and Dependencies

### Required Packages

- `playwright`: Browser automation and testing
- `pytest-playwright`: Pytest integration for Playwright
- `pytest-asyncio`: Async test support
- `pandas`: Data validation and comparison
- `streamlit`: Application framework being tested

### Testing Environment

- Python 3.11.11 with micromamba environment
- Chromium/Firefox/Safari browser support via Playwright
- Local Streamlit development server
- Test data fixtures and mock scenarios

## Implementation Notes

This chatmode should be used when:

- New dashboard features are implemented
- Data processing logic is modified
- UI/UX improvements are made
- Performance optimization is needed
- Regular regression testing is required

The testing framework is designed to be:

- **Comprehensive**: Covering all aspects of the application
- **Automated**: Minimizing manual testing effort
- **Maintainable**: Easy to update as the application evolves
- **Actionable**: Providing clear next steps for improvements
