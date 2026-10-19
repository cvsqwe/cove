import sys
from pathlib import Path

from .app import CoveCode


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    CoveCode(Path(args[0]) if args else None).run()


if __name__ == "__main__":
    main()
