import os
from pathlib import Path


def build_in_current_directory():
    # '.' means "right here in the folder where this script is running"
    root_dir = Path(".")

    # Define the folders relative to where you already are
    folders = [
        root_dir / "data",
        root_dir / "sql",
        root_dir / "powerbi",
        root_dir / "reports",
    ]

    # Define the files
    files = [
        root_dir / "data" / "raw_data.csv",
        root_dir / "data" / "cleaned_data.csv",
        root_dir / "README.md",
    ]

    print(f"Building structure inside existing folder: {root_dir.resolve()}\n")

    # Create directories
    for folder in folders:
        folder.mkdir(parents=True, exist_ok=True)
        print(f"📁 Created folder: {folder}")

    # Create files
    for file in files:
        file.touch(exist_ok=True)
        print(f"📄 Created file:   {file}")

    print("\n✅ Structure updated successfully!")


if __name__ == "__main__":
    build_in_current_directory()