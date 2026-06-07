import logging
import sys


def setup_logging(debug: bool = False) -> None:
    level = logging.DEBUG if debug else logging.INFO
    fmt = "%(asctime)s | %(levelname)-8s | %(name)s - %(message)s"
    logging.basicConfig(stream=sys.stdout, level=level, format=fmt)
    # Quieten noisy libraries
    logging.getLogger("passlib").setLevel(logging.WARNING)


logger = logging.getLogger("smart_afya")
