# C# Instructions

Refer to [C# Coding Standards](./csharp-standards.md) for detailed coding conventions, styles, and documentation guidelines.

## Table of Contents

- [Project Structure & Management](#project-structure--management)
  - [Standard Solution Folder Layout](#standard-solution-folder-layout)
  - [C# Project Internal Folder Structure](#c-project-internal-folder-structure)
  - [Managing C# Projects](#managing-c-projects)
- [Keeping Up-to-Date](#keeping-up-to-date)
  - [Latest C# Versions](#latest-c-versions)

## Project Structure & Management

### Standard Solution Folder Layout

- `.sln`: Root of the working directory.
- `Dockerfile`: Root of the working directory.
- `src/`: Contains Project directories.
- `src/Project/Project.csproj`: In Project directory, same name.
- `src/Project/**/Program.cs`: Under Project directory, optionally in subfolders.
- `src/Project.Tests/Project.Tests.csproj`: Tests in `*.Tests` directory, same name as Project.

#### Folder Layout Example

```plaintext
Solution.sln
Dockerfile
src/
  Project/
    Project.csproj
    Program.cs
  Project.Tests/
    Project.Tests.csproj
    ProgramTests.cs
```

### C# Project Internal Folder Structure

Prefer simple project folder structures. ALWAYS follow existing project conventions. For new projects:

- `Properties` folder: For launch settings, assembly info, etc., when needed.
- Root of project: All files if fewer than 16.
- Project directory names: Plural, proper English (e.g., `Services`, `Controllers`).
- If folders are needed, prefer DDD-style names: `Configurations`, `Application`, `Infrastructure`, `Repositories`, `ExternalServices`, `Models`, `Domain`, `Entities`, `Aggregates`, `Services`, `Commands`, `Queries`, `Controllers`, `DomainEvents`.
- Group more than three derived classes for a base class into a descriptive project directory (including base class and interfaces).

### Managing C# Projects

ALWAYS use the `dotnet` CLI for:

- **Adding a New Project**:
  - `dotnet new list` to discover templates.
  - ALWAYS use a template (e.g., `dotnet new xunit`).
  - `dotnet solution add ./path/to/Project.csproj` to add to Solution.
- **Adding Project References**: `dotnet add ./path/to/Project.csproj reference ./path/to/ReferenceProject.csproj`.
- **Adding NuGet Packages**:
  - Check existing: `dotnet list Solution.sln package --format json`. Use same name/version if found.
  - Find latest: Use NuGet.org or IDE.
  - Add package: `dotnet add ./path/to/Project.csproj package Package-Name --version <VERSION>`.
- **Build Configurations**: `Release` and `Debug`.
- **Verification**:
  - Build: `dotnet build Solution.sln`. Check for errors/warnings.
  - Test: `dotnet test` (with configurations). Verify failures/errors.

## Keeping Up-to-Date

### Latest C# Versions

ALWAYS prefer latest C# and .NET versions, unless specified otherwise. Refer to official Microsoft documentation for the latest features:

- [What's new in C# 11](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-11)
- [What's new in C# 12](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-12)
- [What's new in C# 13 (if available, check latest)](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-13)
- [What's new in C# 14 (if available, check latest)](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-14)
