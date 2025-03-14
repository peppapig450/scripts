#!/usr/bin/env python3
import subprocess
import sys
from datetime import datetime
import argparse
from collections import defaultdict
from typing import TypedDict

# Define TypedDicts for structured dictionaries
class CommitDict(TypedDict):
    hash: str
    author: str
    message: str
    files_changed: int
    insertions: int
    deletions: int

class AuthorStatsDict(TypedDict):
    commits: int
    insertions: int
    deletions: int
    files_changed: int
    
    
def run_git_command(args: list[str]) -> str:
    """Run a git command and return the output.

    Args:
        args: List of command arguments for subprocess.

    Returns:
        The stripped output of the command as a string, or empty string on error.
    """
    try:
        result = subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)
        return result.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running git command: {e.output}")
        return ""
    
def get_commits_on_date(target_date: datetime) -> list[CommitDict]:
    """Get commits from the given date with detailed stats.

    Args:
        target_date: The date for which to retrieve commits.

    Returns:
        A list of commit dictionaries with stats.
    """
    date_str: str = target_date.strftime("%Y-%m-%d")
    
    # Construct git command as a list to avoid shell=True
    git_cmd: list[str] = [
        "git", "log",
        f"--since={date_str} 00:00",
        f"--until={date_str} 23:59",
        "--pretty=format:COMMIT_START %h|%an|%s",
        "--stat"
    ]
    
    output: str = run_git_command(git_cmd)
    if not output:
        return []
    
    # Parse the output into a list of commits with stats
    commits: list[CommitDict] = []
    current_commit: CommitDict | None = None
    
    for line in output.splitlines():
        if line.startswith("COMMIT_START"):
            if current_commit:
                commits.append(current_commit)
            parts: list[str] = line.split("|", 2)
            current_commit: CommitDict = {
                "hash": parts[0].replace("COMMIT_START", ""),
                "author": parts[1],
                "message": parts[2],
                "files_changed": int(0),
                "insertions": int(0),
                "deletions": int(0),
            }
        elif current_commit and all(keyword in line for keyword in ("changed", "file")):
            # Parse the summary line (e.g., "2 files changed, 10 insertions(+), 5 deletions(-)")
            parts: list[str] = line.split(",")
            for part in parts:
                part = part.strip()
                if "file" in part:
                    current_commit["files_changed"]= int(part.split()[0])
                elif "insertion" in part:
                    current_commit["insertions"] = int(part.split()[0])
                elif "deletion"in part:
                    current_commit["deletions"] = int(part.split()[0])
                    
    if current_commit:
        commits.append(current_commit)
    
    return commits

def get_author_stats(commits: list[CommitDict]) -> dict[str, AuthorStatsDict]:
    """Calculate stats per author.

    Args:
        commits: List of commit dictionaries.

    Returns:
        A dictionary mapping authors to their stats.
    """
    author_stats: defaultdict[str, AuthorStatsDict] = defaultdict(lambda: AuthorStatsDict(commits=0, insertions=0, deletions=0, files_changed=0))
    for commit in commits:
        author: str = commit["author"]
        author_stats[author]["commits"] += 1
        author_stats[author]["insertions"] += commit["insertions"]
        author_stats[author]["deletions"] += commit["deletions"]
        author_stats[author]["files_changed"] += commit["files_changed"]
    return author_stats

def print_pretty_summary(commits: list[CommitDict], date: datetime) -> None:
    """Print a detailed formatted summary of the commits.

    Args:
        commits: List of commit dictionaries.
        date: The date of the commits.
    """
    date_str: str = date.strftime("%B %d, %Y")
    print(f"\n{'='*60}")
    print(f"Git Activity Summary for {date_str}".center(60))
    print(f"{'='*60}\n")
    
    if not commits:
        print("No commits found for this date.")
        return
    
    total_files_changed: int = sum(c["files_changed"] for c in commits)
    total_insertions: int = sum(c["insertions"] for c in commits)
    total_deletions: int = sum(c["deletions"] for c in commits)
    
    # General stats
    print(f"Total Commits: {len(commits)}")
    print(f"Total Files Changed: {total_files_changed}")
    print(f"Total Lines Added: {total_insertions}")
    print(f"Total Lines Removed: {total_deletions}\n")
    
    # Author stats
    author_stats: dict[str, AuthorStatsDict] = get_author_stats(commits)
    print("Author Contributions:")
    print("-" * 60)
    for author, stats in author_stats.items():
        print(f"Author: {author}")
        print(f"  Commits: {stats['commits']}")
        print(f"  Files Changed: {stats['files_changed']}")
        print(f"  Lines Added: {stats['insertions']}")
        print(f"  Lines Removed: {stats['deletions']}")
        print("-" * 60)
    
    # Detailed commit list
    print("\nDetailed Commits:")
    print("-" * 60)
    for commit in commits:
        print(f"Hash: {commit['hash']}")
        print(f"Author: {commit['author']}")
        print(f"Message: {commit['message']}")
        print(f"Stats: {commit['files_changed']} files changed, "
              f"{commit['insertions']} insertions(+), {commit['deletions']} deletions(-)")
        print("-" * 60)
        
def main() -> None:
    """Parse arguments and run the git summary script."""
    parser = argparse.ArgumentParser(description="Summarize Git activity for a specific day.")
    parser.add_argument(
        "--date",
        type=str,
        default=datetime.now().strftime("%Y-%m-%d"),
        help="Date in YYYY-MM-DD format (default: today)"
    )
    
    args = parser.parse_args()
    
    try:
        target_date: datetime = datetime.strptime(args.date, "%Y-%m-%d")
    except ValueError:
        print("Invalid date format. Please use YYYY-MM-DD.")
        sys.exit(1)
    
    commits: list[CommitDict] = get_commits_on_date(target_date)
    print_pretty_summary(commits, target_date)

if __name__ == "__main__":
    main()