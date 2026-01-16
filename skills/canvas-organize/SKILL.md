---
name: setup-custom-course-structure
description: A workflow to download Canvas content, reorganize it into a specific "Resources" taxonomy, create lecture notes, and update the main course file.
---

# Setup Custom Course Structure (The "NEKN" Workflow)

**Goal**: Download Canvas content, reorganize it into a specific "Resources" taxonomy, create lecture notes, and update the main course file.

**Parameters**:
- `COURSE_ID` (Canvas Course ID, e.g., "35659")
- `COURSE_CODE` (e.g., "NEKN41")
- `SEMESTER_PATH` (e.g., "Faks/Mag/3. semester")
- `COURSE_NAME` (e.g., "Advanced Macroeconomic Analysis")

**Process**:

1.  **Analyze & Validate**
    *   Read `System/3sem-folder-structure.md` (if exists) to confirm conventions.
    *   Check for existence of target paths:
        *   `{SEMESTER_PATH}/{COURSE_NAME}/{COURSE_CODE} - Resources`
        *   `{SEMESTER_PATH}/{COURSE_NAME}/Notes`
    *   Inspect a previous course (e.g., "NEKN23") in `{SEMESTER_PATH}` to learn note frontmatter and linking patterns.

2.  **Discover Content**
    *   Run `discover_course_files(course_id=COURSE_ID)`.
    *   Categorize files into: Lectures, Docs, Exams, Readings, Seminars.

3.  **Download & Staging**
    *   Use `download_course(course_id=COURSE_ID)` to get all files into the default staging area (`Canvas/{COURSE_NAME}`).

4.  **Organize & Rename (The "Move")**
    *   Create target subfolders in `{COURSE_CODE} - Resources`:
        *   `{COURSE_CODE} - Lectures`
        *   `{COURSE_CODE} - General`
        *   `{COURSE_CODE} - Exams`
        *   `{COURSE_CODE} - Readings`
        *   `{COURSE_CODE} - Seminars`
    *   Move files from staging to these folders, renaming them with the `{COURSE_CODE} - ` prefix.
    *   *Rule*: `B1 Consumption.pdf` -> `NEKN41 - B1.pdf`.

5.  **Generate Notes**
    *   For each PDF in `{COURSE_CODE} - Lectures`:
        *   Check if a corresponding `.md` note exists in `{SEMESTER_PATH}/{COURSE_NAME}/Notes`.
        *   If not, create it using the learned template (from step 1).
        *   Include frontmatter and a link to the PDF: `[[{COURSE_CODE} - X.pdf|📖]]`.

6.  **Update Course Map**
    *   Read the main course file: `{SEMESTER_PATH}/{COURSE_NAME}/{COURSE_NAME}.md`.
    *   Update Module tables to link to the new Lecture Notes.
    *   Embed reading lists if applicable.

7.  **Verify**
    *   List files in target directories to ensure everything moved.
    *   Check 1-2 created notes for broken links.
