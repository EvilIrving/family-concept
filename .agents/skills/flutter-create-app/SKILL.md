---
name: flutter-create-app
description: Create a new Flutter app with opinionated structure, design document, and phased implementation plan.
disable-model-invocation: true
---

We're going to build a new Flutter app.

## Problem specification

First, prompt the user for a description of what the purpose and details of the app will be.

Once the user has specified the description and purpose of the app, outline the information that you will be collecting before creating the design and implementation plan, and present the list to the user, along with your first question.

## Collecting Information

Next, collect remaining information from the user, one question at a time.

The information you need to collect includes, but might not be limited to:

- If there are ambiguous elements to the design, ask the user questions to clarify. When the goal is clear, or the user says to, then move on.
- If the user didn't already give one, select a short descriptive name for the package.
- Whether to do the work on the current git branch, or a new feature branch.
  - Suggest a branch name, making sure it is a valid git branch name.
- Which directory to use as the package directory. Suggest a location.

If the user wants the work done on a new branch, create the branch now.
Then create the package directory, if it doesn't already exist.

**VERY IMPORTANT**: Change directories to the package directory now so that future operations are relative to that directory.

## Design document

Develop a **DETAILED** Markdown-formatted design document that follows all of the guidance you have about Dart and Flutter design patterns, rules, best practices, and core principles. Save the design document in specs/DESIGN.md in the package directory. Feel free to use your available tools to research any aspects of the design that need clarification.

The design doc should (at least) include sections for:

- An overview
- A detailed analysis of the goal or problem
- Alternatives considered
- A detailed design for the new package
- Any diagrams needed to explain the design, in Mermaid format.
  - Be sure to put quotes around labels that include special characters (e.g. parenthesis).
- A summary of the design
- References to research URLs used to arrive at the design.

Be sure to **actually fetch and read** the research URLs **before** writing the design document. Do actual web research on the topics that are important to the design.

You must ask the user to review this design document and they must approve it before you continue on to create the implementation plan. They must review and approve it first because if they ask for any changes, it may affect the implementation plan.

## Implementation plan

After getting explicit approval from the user for the DESIGN.md document, Develop a **DETAILED** Markdown-formatted phased implementation plan of checkboxed tasks that need to be performed in order to finish developing the package. Save the implementation plan in specs/IMPLEMENTATION.md in the package directory.

The implementation plan should include a section for a "Journal" which will be updated after each phase and contain a log of the actions taken, things learned, surprises, and deviations from the plan. It should be in chronological order.

The plan should include instructions similar to: "After completing a task, if you added any TODOs to the code or didn't fully implement anything, make sure to add new tasks so that you can come back and complete them later." to prevent leaving tasks unfinished.

In the first phase of the implementation plan, include:

- [ ] Create a Flutter project in the package directory using `flutter create --empty .` (if current directory) or `flutter create --empty <package_name>`.
  - Unless the user specifies otherwise, the package should support all of the default platforms.
  - The name of the package directory must be a valid Dart package name. If it isn't, then inform the user and suggest an alternative (valid) directory name.
- [ ] Remove any boilerplate in the new package that will be replaced, including the test dir, if any.
- [ ] Update the description of the package in the `pubspec.yaml` and set the version number to 0.1.0.
- [ ] Update the README.md to include a short placeholder description of the package.
- [ ] Create the CHANGELOG.md to have the initial version of 0.1.0.
- [ ] Commit this empty version of the package to either a new branch or the current branch based on the user's preference.
- [ ] After committing the change, start running the app with `flutter run` on the user's preferred device.

The implementation plan should specify after each phase that you should:

- [ ] Create/modify unit tests for testing the code added or modified in this phase, if relevant.
- [ ] Run `dart fix --apply` to clean up the code.
- [ ] Run `flutter analyze` one more time and fix any issues.
- [ ] Run `flutter test` to make sure all tests pass.
- [ ] Run `dart format .` to make sure that the formatting is correct.
- [ ] Re-read the IMPLEMENTATION.md file to see what, if anything, has changed in the implementation plan, and if it has changed, take care of anything the changes imply.
- [ ] Update the IMPLEMENTATION.md file with the current state, including any learnings, surprises, or deviations in the Journal section. Check off any checkboxes of items that have been completed.
- [ ] Use `git diff` to verify the changes that have been made, and create a suitable commit message for any changes, following any guidelines you have about commit messages. Be sure to properly escape dollar signs and backticks, and present the change message to the user for approval.
- [ ] Wait for approval. Don't commit the changes or move on to the next phase of implementation until the user approves the commit.
- [ ] After committing the change, if the app is running, press `r` in the terminal to hot reload.
  - Hot reload only works reliably on Flutter at versions at or above 3.37.0. If hot reload fails, and they are using a version below that, inform the user and suggest either switching to the Flutter main channel or manually reloading the app.

In the last phase of the plan, include steps to:

- [ ] Create a comprehensive README.md file for the package.
- [ ] Create a CLAUDE.md file in the project directory that describes the app, its purpose, and implementation details of the application and the layout of the files.
- [ ] Ask the user to inspect the app and the code and say if they are satisfied with it, or if any modifications are needed.

You must ask the user to review this implementation plan and they must approve it before starting implementation. They must review and approve it before you begin because if they ask for any changes, the changes may affect the implementation.

## Implementation

After getting explicit approval from the user for the IMPLEMENTATION.md document, begin implementing the plan.
