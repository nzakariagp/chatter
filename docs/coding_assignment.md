# Elixir Take-Home Exercise: Simple Chat Application

## Objective

Build a small **real-time chat application** in Elixir using Phoenix, LiveView, and Ecto that demonstrates your understanding of OTP concepts, persistence, and reactive UI updates.

The exercise should be completable within **~2 hours**, but you're welcome to take as much time as you would like to complete it.

## Requirements

### 1. Technology stack
   a. Elixir, Phoenix (with LiveView), Ecto, and Postgres

### 2. Functionality
   a. On load, the app shows:
      i. A **list of all users**
      ii. Each user's **online/offline** status

   b. A visitor can enter a **name** to join the chat (no authentication required)
      i. If the user doesn't exist, create it
      ii. Once joined, they enter a **shared chat room** with all other users online

   c. Inside the chat:
      i. Show all **past chat messages**
      ii. Show all **users** and their online/offline status
      iii. Allow sending new messages that appear for all users and are persisted in Postgres

### 3. Persistence
   a. Data should be stored in a Postgres database
   b. Online/offline presence should be managed dynamically

### 4. Focus
   a. Emphasis is on **functionality, correctness, and design clarity**, not aesthetics
   b. A minimal UI is fine as long as it demonstrates proper flow and updates

## Assumptions

Make any assumptions necessary to complete the exercise, but document them in a readme file.

## Show Your Work

We want you to show how you arrived at the final product and your thought process, as much as possible.

### AI

Use of AI is encouraged, but not required. When using AI, submission of your AI instructions markdown file is also encouraged.

The code will be evaluated on its own merits.

### Git History

Please include your git repo in the submission, including the commit history.

## Submission

Submit a link to a **Git repository** containing your work. You can also include your submission as an attachment to an email.

**Please send your submission at least 24 hours before your technical interview.**

Your submission should include:

- **Commit history** showing incremental progress
- A **README.md** with:
  - **Setup instructions** (dependencies, Postgres setup, running the app)
  - Any **assumptions** you made
  - A short **description** of your architecture and design approach